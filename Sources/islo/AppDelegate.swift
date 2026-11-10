import AppKit
import MetalKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow!
    private var view: MTKView!
    private var renderer: Renderer!
    private var watcher: IconWatcher!
    private var statusItem: NSStatusItem!
    private var statusLine: NSMenuItem!
    private var pauseItem: NSMenuItem!
    private let model = IslandModel()
    private var userPaused = false
    private var mouseMonitor: Any?
    private var folderSource: DispatchSourceFileSystemObject?
    private var themeItems: [NSMenuItem] = []
    private var startTheme: Theme = {
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "--theme"), i + 1 < args.count, let theme = Theme(name: args[i + 1]) { return theme }
        return Theme.saved
    }()

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard let screen = NSScreen.screens.first, let device = MTLCreateSystemDefaultDevice() else {
            FileHandle.standardError.write("islo: no screen or no Metal device\n".data(using: .utf8)!)
            NSApp.terminate(nil)
            return
        }

        // Review harness: paint the fixed layouts to files and quit.
        let arguments = CommandLine.arguments
        if let i = arguments.firstIndex(of: "--hour"), i + 1 < arguments.count, let hour = Double(arguments[i + 1]) {
            // Look at a fixed hour of the day instead of the clock.
            Daylight.fixedHour = hour
        }
        if let i = arguments.firstIndex(of: "--atlas"), i + 1 < arguments.count {
            // Review harness: write the sprite sheet to a file and quit.
            exit(Atlas.draw().map { Harness.write($0, to: URL(fileURLWithPath: arguments[i + 1])) } == true ? 0 : 1)
        }
        if let i = arguments.firstIndex(of: "--contact-sheet"), i + 1 < arguments.count {
            guard let renderer = Renderer(device: device, model: model, theme: startTheme) else { exit(1) }
            let directory = URL(fileURLWithPath: arguments[i + 1], isDirectory: true)
            let themes = arguments.contains("--theme") ? [startTheme] : Theme.allCases
            let ok = themes.allSatisfy { Harness.run(directory: directory, theme: $0, renderer: renderer, model: model) }
            exit(ok ? 0 : 1)
        }

        // A borderless, click-through window just above the system wallpaper
        // and below Finder's desktop icons.
        window = NSWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)) + 1)
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        window.ignoresMouseEvents = true
        window.isOpaque = true
        window.hasShadow = false
        window.isReleasedWhenClosed = false

        view = MTKView(frame: NSRect(origin: .zero, size: screen.frame.size), device: device)
        view.preferredFramesPerSecond = 24
        view.colorPixelFormat = .bgra8Unorm
        guard let renderer = Renderer(device: device, model: model, theme: startTheme) else {
            FileHandle.standardError.write("islo: could not set up the renderer\n".data(using: .utf8)!)
            NSApp.terminate(nil)
            return
        }
        self.renderer = renderer
        view.delegate = renderer
        window.contentView = view
        window.orderFront(nil)

        setUpMenu()

        watcher = IconWatcher { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let points):
                self.model.setTargets(points)
                self.statusLine.title = "\(points.count) icons on the desktop"
                if let i = CommandLine.arguments.firstIndex(of: "--snapshot"), i + 1 < CommandLine.arguments.count {
                    let image = self.renderer.renderImage(pointSize: self.view.bounds.size, scale: 2)
                    let ok = image.map { Harness.write($0, to: URL(fileURLWithPath: CommandLine.arguments[i + 1])) } ?? false
                    exit(ok ? 0 : 1)
                }
            case .failure(let error):
                self.statusLine.title = error.message
            }
        }
        watcher.start()

        // Icons move when a drag ends or the Desktop folder changes: ask then.
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseUp, .rightMouseUp]) { [weak self] _ in
            self?.watcher.poke()
        }
        let desktop = open(FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask)[0].path, O_EVTONLY)
        if desktop >= 0 {
            let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: desktop, eventMask: [.write, .rename, .delete], queue: .main)
            source.setEventHandler { [weak self] in self?.watcher.poke() }
            source.setCancelHandler { close(desktop) }
            source.resume()
            folderSource = source
        }

        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(visibilityChanged),
                           name: NSWindow.didChangeOcclusionStateNotification, object: window)
        center.addObserver(self, selector: #selector(screensChanged),
                           name: NSApplication.didChangeScreenParametersNotification, object: nil)
    }

    private func setUpMenu() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let image = NSImage(systemSymbolName: "water.waves", accessibilityDescription: "islo") {
            statusItem.button?.image = image
        } else {
            statusItem.button?.title = "islo"
        }
        let menu = NSMenu()
        statusLine = NSMenuItem(title: "Reading the desktop…", action: nil, keyEquivalent: "")
        statusLine.isEnabled = false
        menu.addItem(statusLine)
        menu.addItem(.separator())
        for theme in Theme.allCases {
            let item = NSMenuItem(title: theme.title, action: #selector(chooseTheme(_:)), keyEquivalent: "")
            item.target = self
            item.tag = Int(theme.rawValue)
            item.state = theme == startTheme ? .on : .off
            themeItems.append(item)
            menu.addItem(item)
        }
        menu.addItem(.separator())
        pauseItem = NSMenuItem(title: "Pause", action: #selector(togglePause), keyEquivalent: "")
        pauseItem.target = self
        menu.addItem(pauseItem)
        menu.addItem(NSMenuItem(title: "Quit islo", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    private func applyActivity() {
        let visible = window.occlusionState.contains(.visible)
        let active = visible && !userPaused
        view.isPaused = !active
        watcher.isActive = active
    }

    @objc private func chooseTheme(_ sender: NSMenuItem) {
        guard let theme = Theme(rawValue: Int32(sender.tag)) else { return }
        renderer.theme = theme
        theme.save()
        for item in themeItems { item.state = item === sender ? .on : .off }
    }

    @objc private func togglePause() {
        userPaused.toggle()
        pauseItem.title = userPaused ? "Resume" : "Pause"
        applyActivity()
    }

    @objc private func visibilityChanged() {
        applyActivity()
    }

    @objc private func screensChanged() {
        guard let screen = NSScreen.screens.first else { return }
        window.setFrame(screen.frame, display: true)
    }
}
