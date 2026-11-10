import AppKit

struct WatchError: Error {
    let message: String
}

/// Asks Finder for the positions of the desktop icons. Only coordinates are
/// requested, never file names. Positions are in points from the top-left
/// corner of the main screen and mark the centre of each icon image.
///
/// Asking costs Finder real work, so it is done when something may have
/// changed (`poke()`: a mouse button came up, or the Desktop folder changed)
/// and otherwise only now and then.
final class IconWatcher {
    typealias Handler = (Result<[CGPoint], WatchError>) -> Void

    private let handler: Handler
    private let lock = NSLock()
    private var active = true
    private var thread: Thread?
    private let wake = DispatchSemaphore(value: 0)

    /// When false the watcher asks rarely, since nobody can see the result.
    var isActive: Bool {
        get { lock.lock(); defer { lock.unlock() }; return active }
        set { lock.lock(); active = newValue; lock.unlock() }
    }

    init(handler: @escaping Handler) {
        self.handler = handler
    }

    /// Something may have moved: ask Finder now, and once more shortly after,
    /// since Finder settles an icon onto its grid a moment after the drop.
    func poke() {
        wake.signal()
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.7) { [weak self] in self?.wake.signal() }
    }

    func start() {
        let thread = Thread { [weak self] in self?.run() }
        thread.name = "islo.icon-watcher"
        thread.qualityOfService = .utility
        self.thread = thread
        thread.start()
    }

    private func run() {
        let source = """
        with timeout of 5 seconds
            tell application "Finder" to get desktop position of every item of desktop
        end timeout
        """
        let script = NSAppleScript(source: source)
        var last: [CGPoint]? = nil
        var lastError: String? = nil

        while true {
            autoreleasepool {
                var errorInfo: NSDictionary?
                let output = script?.executeAndReturnError(&errorInfo)
                if let output, errorInfo == nil {
                    let points = Self.parse(output)
                    if points != last || lastError != nil {
                        last = points
                        lastError = nil
                        DispatchQueue.main.async { self.handler(.success(points)) }
                    }
                } else {
                    let code = (errorInfo?[NSAppleScript.errorNumber] as? Int) ?? 0
                    let text: String
                    if code == -1743 {
                        text = "Allow islo to control Finder in System Settings › Privacy › Automation"
                    } else {
                        let detail = (errorInfo?[NSAppleScript.errorMessage] as? String) ?? "unknown error"
                        text = "Finder did not answer (\(code)): \(detail)"
                    }
                    if text != lastError {
                        lastError = text
                        FileHandle.standardError.write("islo: \(text)\n".data(using: .utf8)!)
                        DispatchQueue.main.async { self.handler(.failure(WatchError(message: text))) }
                    }
                }
            }
            _ = wake.wait(timeout: .now() + (isActive ? 20 : 120))
            Thread.sleep(forTimeInterval: 0.15)     // let a burst of pokes become one question
            while wake.wait(timeout: .now()) == .success {}
        }
    }

    /// Finder answers with a list of {x, y} pairs, or a single pair when the
    /// desktop holds one item.
    private static func parse(_ descriptor: NSAppleEventDescriptor) -> [CGPoint] {
        func isList(_ d: NSAppleEventDescriptor) -> Bool { d.descriptorType == typeAEList }
        guard isList(descriptor) else { return [] }
        let n = descriptor.numberOfItems
        if n == 0 { return [] }

        func point(_ d: NSAppleEventDescriptor) -> CGPoint? {
            guard isList(d), d.numberOfItems == 2,
                  let x = d.atIndex(1), let y = d.atIndex(2), !isList(x), !isList(y) else { return nil }
            return CGPoint(x: x.doubleValue, y: y.doubleValue)
        }

        if let single = point(descriptor) { return [single] }
        var points: [CGPoint] = []
        for i in 1...n {
            if let item = descriptor.atIndex(i), let p = point(item) { points.append(p) }
        }
        return points
    }
}
