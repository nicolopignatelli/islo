import AppKit
import CoreText

/// The sheet of characters the ASCII city is typed with: one row of cells,
/// white on black, each cell exactly as many pixels as a character takes on
/// a Retina screen, so nothing is rescaled. The order here is the order of
/// the `G_…` constants in ShaderCity.swift.
enum Glyphs {
    static let characters = Array(" .:,\"-=+|#%@o*~^&x<>v[]_")
    static let slots = 24
    static let cell = CGSize(width: 16, height: 32)   // pixels

    static func draw() -> CGImage? {
        let width = Int(cell.width) * slots, height = Int(cell.height)
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.setShouldSmoothFonts(false)
        let font = CTFontCreateWithName("Menlo-Bold" as CFString, 20, nil)
        for (i, character) in characters.enumerated() {
            let text = NSAttributedString(string: String(character), attributes: [
                NSAttributedString.Key(kCTFontAttributeName as String): font,
                NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(red: 1, green: 1, blue: 1, alpha: 1),
            ])
            let line = CTLineCreateWithAttributedString(text)
            let advance = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
            context.textPosition = CGPoint(x: CGFloat(i) * cell.width + (cell.width - advance) / 2, y: 9)
            CTLineDraw(line, context)
        }
        return context.makeImage()
    }
}
