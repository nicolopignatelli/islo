import AppKit

/// The review harness: renders a theme over a fixed set of icon layouts, with
/// mock icons and labels drawn on top, so a theme is judged the way it will
/// be seen. Run with `islo --contact-sheet <directory> [--theme <name>]`.
enum Harness {
    static let screen = CGSize(width: 1680, height: 1050)

    private static func grid(columns: Int, rows: Int) -> [CGPoint] {
        var points: [CGPoint] = []
        for c in 0..<columns {
            for r in 0..<rows {
                points.append(CGPoint(x: 1615 - 124 * c, y: 70 + 112 * r))
            }
        }
        return points
    }

    static let layouts: [(name: String, icons: [CGPoint])] = [
        ("empty", []),
        ("single", [CGPoint(x: 700, y: 430)]),
        ("column", grid(columns: 1, rows: 7)),
        ("typical", [
            (1615, 177), (1615, 289), (1615, 400), (1614, 742), (1366, 518), (1614, 630), (1490, 295), (1490, 519),
            (1366, 406), (1614, 854), (1490, 407), (1490, 70), (1614, 518), (1490, 182), (1366, 70), (1366, 182),
        ].map { CGPoint(x: $0.0, y: $0.1) }),
        ("scattered", [
            (180, 140), (310, 220), (620, 760), (700, 640), (840, 720), (1100, 240), (1220, 330), (1510, 800),
            (260, 820), (980, 520),
        ].map { CGPoint(x: $0.0, y: $0.1) }),
        ("dense", grid(columns: 5, rows: 8)),
    ]

    private static let names = ["Projects", "Invoice.pdf", "Notes", "Screenshot", "Archive", "Photos", "report.docx", "Music"]

    /// The painting with stand-in icons and labels on top.
    static func render(layout: [CGPoint], renderer: Renderer, model: IslandModel, scale: CGFloat = 2) -> CGImage? {
        model.reset(layout)
        guard let painting = renderer.renderImage(pointSize: screen, scale: scale) else { return nil }
        let width = painting.width, height = painting.height
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.draw(painting, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Draw in points, with the origin at the top-left as Finder reports it.
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: scale, y: -scale)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
        for (i, icon) in layout.enumerated() {
            let shadow = NSShadow()
            shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
            shadow.shadowBlurRadius = 4
            shadow.shadowOffset = NSSize(width: 0, height: -2)
            NSGraphicsContext.saveGraphicsState()
            shadow.set()
            if i % 3 == 1 {
                NSColor(white: 0.97, alpha: 1).setFill()
                NSBezierPath(roundedRect: NSRect(x: icon.x - 23, y: icon.y - 30, width: 46, height: 60), xRadius: 4, yRadius: 4).fill()
            } else {
                NSColor(red: 0.36, green: 0.68, blue: 0.95, alpha: 1).setFill()
                NSBezierPath(roundedRect: NSRect(x: icon.x - 30, y: icon.y - 24, width: 60, height: 48), xRadius: 6, yRadius: 6).fill()
            }
            NSGraphicsContext.restoreGraphicsState()

            let textShadow = NSShadow()
            textShadow.shadowColor = NSColor.black.withAlphaComponent(0.85)
            textShadow.shadowBlurRadius = 2.5
            textShadow.shadowOffset = NSSize(width: 0, height: -1)
            let label = NSAttributedString(string: names[i % names.count], attributes: [
                .font: NSFont.systemFont(ofSize: 12, weight: .medium),
                .foregroundColor: NSColor.white,
                .shadow: textShadow,
            ])
            let size = label.size()
            label.draw(at: NSPoint(x: icon.x - size.width / 2, y: icon.y + 36))
        }
        NSGraphicsContext.restoreGraphicsState()
        return context.makeImage()
    }

    static func write(_ image: CGImage, to url: URL) -> Bool {
        guard let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else { return false }
        return (try? png.write(to: url)) != nil
    }

    /// Writes `<theme>-sheet.png` (all layouts at half size) and
    /// `<theme>-zoom.png` (a full-resolution detail of the typical layout).
    static func run(directory: URL, theme: Theme, renderer: Renderer, model: IslandModel) -> Bool {
        renderer.theme = theme
        let tile = CGSize(width: screen.width / 2, height: screen.height / 2)
        let columns = 2
        let rows = (layouts.count + columns - 1) / columns
        let gap: CGFloat = 12
        let sheetWidth = Int(CGFloat(columns) * tile.width + CGFloat(columns + 1) * gap)
        let sheetHeight = Int(CGFloat(rows) * tile.height + CGFloat(rows + 1) * gap)
        guard let sheet = CGContext(data: nil, width: sheetWidth, height: sheetHeight, bitsPerComponent: 8, bytesPerRow: 0,
                                    space: CGColorSpaceCreateDeviceRGB(),
                                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
        sheet.setFillColor(CGColor(gray: 0.12, alpha: 1))
        sheet.fill(CGRect(x: 0, y: 0, width: sheetWidth, height: sheetHeight))
        sheet.interpolationQuality = .high

        let name = theme.slug
        for (i, layout) in layouts.enumerated() {
            guard let image = render(layout: layout.icons, renderer: renderer, model: model) else { return false }
            let column = i % columns, row = i / columns
            let x = gap + CGFloat(column) * (tile.width + gap)
            let y = CGFloat(sheetHeight) - gap - tile.height - CGFloat(row) * (tile.height + gap)
            sheet.draw(image, in: CGRect(x: x, y: y, width: tile.width, height: tile.height))
            if layout.name == "typical" {
                let crop = CGRect(x: image.width - 1500, y: 500, width: 1500, height: 1000)
                if let detail = image.cropping(to: crop) {
                    _ = write(detail, to: directory.appendingPathComponent("\(name)-zoom.png"))
                }
            }
        }
        guard let image = sheet.makeImage() else { return false }
        return write(image, to: directory.appendingPathComponent("\(name)-sheet.png"))
    }
}
