import AppKit

/// The sprite sheet for everything that moves, drawn once at launch.
/// 4 columns × 15 rows of square cells; every figure is seen from above and
/// faces right.
///
///   row 0: sailboat, wake, hot-air balloon, airliner
///   row 1: turtle, four strokes of the flippers
///   row 2: crab, two steps; bird, two beats of its wings
///   row 3: skater, two strides
///   row 4: a soft ball of light, fox, camel, ray
///   row 5: fish, the forearm of a dragon's wing, dash (a skate mark or a paw print)
///   row 6: the hand of the wing; the camel's shadow in profile; the dragon's body; the upper arm of its wing
///
/// The balloon and the fish are drawn in greys so a tint can colour them.
enum Atlas {
    static let columns = 4
    static let rows = 15
    static let cell = 192   // pixels

    static func draw() -> CGImage? {
        let width = columns * cell, height = rows * cell
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        // Draw each cell in a 96 × 96 box with the origin at its top-left.
        func inCell(_ column: Int, _ row: Int, _ body: (CGContext) -> Void) {
            context.saveGState()
            context.translateBy(x: CGFloat(column * cell), y: CGFloat(height - row * cell))
            context.scaleBy(x: CGFloat(cell) / 96, y: -CGFloat(cell) / 96)
            context.clip(to: CGRect(x: 0, y: 0, width: 96, height: 96))
            body(context)
            context.restoreGState()
        }
        inCell(0, 0, boat)
        inCell(1, 0, wake)
        for frame in 0..<4 { inCell(frame, 1) { turtle($0, sweep: [-0.45, 0.0, 0.45, 0.0][frame]) } }
        for frame in 0..<2 { inCell(frame, 2) { crab($0, step: frame == 0 ? -1 : 1) } }
        inCell(2, 0, balloon)
        inCell(3, 0, airliner)
        for frame in 0..<2 { inCell(2 + frame, 2) { bird($0, spread: frame == 0 ? 1.0 : 0.62) } }
        for frame in 0..<2 { inCell(frame, 3) { skater($0, stride: frame == 0 ? -1 : 1) } }
        inCell(1, 4, fox)
        inCell(2, 4) { camel($0, stride: 0) }
        inCell(1, 6) { camelProfile($0, stride: 0) }
        inCell(3, 4, ray)
        inCell(0, 4, orb)
        inCell(2, 6, dragon)
        inCell(3, 6, dragonUpperArm)
        inCell(0, 6, dragonHand)
        inCell(0, 5, fish)
        inCell(1, 5, dragonForearm)
        inCell(2, 5) { c in
            c.addPath(CGPath(roundedRect: CGRect(x: 8, y: 30, width: 80, height: 36), cornerWidth: 18, cornerHeight: 18, transform: nil))
            c.setFillColor(color(1, 1, 1)); c.fillPath()
        }
        // Rows 7 to 13: the three pixel-art wanderers, each pixel a hard-edged
        // square. A figure is 32 pixels wide and 48 tall, in pixels half the
        // size of the land's, and stands in the middle of its cell. Each of the three
        // has nine cells running on from the last: toward us, to the right
        // and away, three pictures of each.
        // Row 14: a ship and an eagle (wings out, wings in), 16 pixels square.
        func pixels(_ rows: [String], _ colours: [Character: PixelArt.Colour], at index: Int, inset: CGFloat, pixel: CGFloat) {
            inCell(index % 4, 7 + index / 4) { c in
                c.setShouldAntialias(false)
                PixelArt.paint(rows, colours: colours, in: c, at: CGPoint(x: inset, y: 0), pixel: pixel)
            }
        }
        var index = 0
        for member in PixelArt.party {
            for frame in member.frames {
                pixels(frame, member.colours, at: index, inset: 16, pixel: 2)
                index += 1
            }
        }
        for (i, other) in PixelArt.others.enumerated() {
            pixels(other.frames[0], other.colours, at: 28 + i, inset: 0, pixel: 6)
        }
        return context.makeImage()
    }

    private static func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
        CGColor(red: r, green: g, blue: b, alpha: a)
    }

    private static func boat(_ c: CGContext) {
        func hull(inset: CGFloat) -> CGPath {
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 11 + inset, y: 40.5 + inset))
            path.addCurve(to: CGPoint(x: 87 - inset * 2.2, y: 48), control1: CGPoint(x: 36, y: 31 + inset), control2: CGPoint(x: 70, y: 35.5 + inset))
            path.addCurve(to: CGPoint(x: 11 + inset, y: 55.5 - inset), control1: CGPoint(x: 70, y: 60.5 - inset), control2: CGPoint(x: 36, y: 65 - inset))
            path.closeSubpath()
            return path
        }
        // Hull, deck, cockpit.
        c.addPath(hull(inset: 0)); c.setFillColor(color(0.84, 0.31, 0.26)); c.fillPath()
        c.addPath(hull(inset: 2.6)); c.setFillColor(color(0.97, 0.94, 0.87)); c.fillPath()
        c.addPath(CGPath(roundedRect: CGRect(x: 19, y: 43.5, width: 20, height: 9), cornerWidth: 3, cornerHeight: 3, transform: nil))
        c.setFillColor(color(0.62, 0.44, 0.30)); c.fillPath()
        // Planking.
        c.setStrokeColor(color(0.80, 0.74, 0.64)); c.setLineWidth(0.6)
        for x in stride(from: 44.0, through: 72.0, by: 5.0) {
            c.move(to: CGPoint(x: x, y: 41.5)); c.addLine(to: CGPoint(x: x, y: 54.5)); c.strokePath()
        }
        // Sails seen from above: two slim curves full of wind.
        c.setShadow(offset: CGSize(width: 1.5, height: -2), blur: 2, color: color(0, 0, 0, 0.25))
        let main = CGMutablePath()
        main.move(to: CGPoint(x: 54, y: 48))
        main.addCurve(to: CGPoint(x: 15, y: 58), control1: CGPoint(x: 43, y: 60), control2: CGPoint(x: 27, y: 64))
        main.addCurve(to: CGPoint(x: 54, y: 48), control1: CGPoint(x: 28, y: 56), control2: CGPoint(x: 43, y: 52))
        let jib = CGMutablePath()
        jib.move(to: CGPoint(x: 56, y: 48))
        jib.addCurve(to: CGPoint(x: 84, y: 48.5), control1: CGPoint(x: 64, y: 57), control2: CGPoint(x: 76, y: 55))
        jib.addCurve(to: CGPoint(x: 56, y: 48), control1: CGPoint(x: 75, y: 50.5), control2: CGPoint(x: 64, y: 50))
        c.addPath(main); c.addPath(jib); c.setFillColor(color(1, 1, 1)); c.fillPath()
        c.setShadow(offset: .zero, blur: 0, color: nil)
        c.setFillColor(color(0.30, 0.22, 0.18)); c.fillEllipse(in: CGRect(x: 53, y: 46.2, width: 3.6, height: 3.6))
    }

    /// The bow wave spreading behind a boat whose stern is at the right edge.
    private static func wake(_ c: CGContext) {
        c.setLineCap(.round)
        for side in [-1.0, 1.0] {
            for i in 0..<14 {
                let t0 = CGFloat(i) / 14, t1 = CGFloat(i + 1) / 14
                c.setStrokeColor(color(1, 1, 1, 0.75 * (1 - t0) * (1 - t0)))
                c.setLineWidth(2.4 - 1.4 * t0)
                c.move(to: CGPoint(x: 94 - 88 * t0, y: 48 + side * (4 + 22 * t0)))
                c.addLine(to: CGPoint(x: 94 - 88 * t1, y: 48 + side * (4 + 22 * t1)))
                c.strokePath()
            }
        }
        for i in 0..<9 {
            let t = CGFloat(i) / 9
            c.setFillColor(color(1, 1, 1, 0.35 * (1 - t)))
            c.fillEllipse(in: CGRect(x: 86 - 62 * t, y: 46.5 + (i % 2 == 0 ? -2.5 : 1.5), width: 6 - 3 * t, height: 3))
        }
    }

    private static func turtle(_ c: CGContext, sweep: CGFloat) {
        let skin = color(0.52, 0.62, 0.42)
        func flipper(at base: CGPoint, angle: CGFloat, length: CGFloat, width: CGFloat) {
            c.saveGState()
            c.translateBy(x: base.x, y: base.y)
            c.rotate(by: angle)
            let path = CGMutablePath()
            path.move(to: .zero)
            path.addCurve(to: CGPoint(x: length, y: 0), control1: CGPoint(x: length * 0.3, y: -width), control2: CGPoint(x: length * 0.8, y: -width * 0.8))
            path.addCurve(to: .zero, control1: CGPoint(x: length * 0.7, y: width * 0.5), control2: CGPoint(x: length * 0.3, y: width * 0.4))
            c.addPath(path); c.setFillColor(skin); c.fillPath()
            c.restoreGState()
        }
        for side in [-1.0, 1.0] as [CGFloat] {
            flipper(at: CGPoint(x: 57, y: 48 + side * 11), angle: side * (1.15 + sweep), length: 24, width: 7 * side)
            flipper(at: CGPoint(x: 33, y: 48 + side * 10), angle: side * (2.35 - sweep * 0.5), length: 13, width: 5 * side)
        }
        // Tail and head.
        c.setFillColor(skin)
        c.move(to: CGPoint(x: 29, y: 45)); c.addLine(to: CGPoint(x: 20, y: 48)); c.addLine(to: CGPoint(x: 29, y: 51)); c.fillPath()
        c.fillEllipse(in: CGRect(x: 63, y: 42.5, width: 15, height: 11))
        c.setFillColor(color(0.20, 0.26, 0.20))
        c.fillEllipse(in: CGRect(x: 73, y: 43.6, width: 1.8, height: 1.8)); c.fillEllipse(in: CGRect(x: 73, y: 50.6, width: 1.8, height: 1.8))
        // Shell with its plates.
        c.setFillColor(color(0.30, 0.44, 0.31)); c.fillEllipse(in: CGRect(x: 25, y: 32, width: 43, height: 32))
        c.setFillColor(color(0.42, 0.56, 0.36)); c.fillEllipse(in: CGRect(x: 29, y: 35.5, width: 35, height: 25))
        c.setStrokeColor(color(0.30, 0.44, 0.31)); c.setLineWidth(1.3)
        c.strokeEllipse(in: CGRect(x: 38, y: 41.5, width: 17, height: 13))
        for (from, to) in [((38.5, 44), (31, 40)), ((38.5, 52), (31, 56)), ((54.5, 44), (62, 40)), ((54.5, 52), (62, 56)), ((46.5, 41.5), (46.5, 35.5)), ((46.5, 54.5), (46.5, 60.5))] {
            c.move(to: CGPoint(x: from.0, y: from.1)); c.addLine(to: CGPoint(x: to.0, y: to.1)); c.strokePath()
        }
    }

    private static func crab(_ c: CGContext, step: CGFloat) {
        let shell = color(0.88, 0.40, 0.27), dark = color(0.70, 0.28, 0.20)
        c.setLineCap(.round)
        c.setStrokeColor(dark); c.setLineWidth(2.6)
        // Legs out to both sides, alternating as it walks.
        for side in [-1.0, 1.0] as [CGFloat] {
            for i in 0..<3 {
                let x = 40 + CGFloat(i) * 6
                let swing = step * (i % 2 == 0 ? 3.5 : -3.5) * side
                c.move(to: CGPoint(x: x, y: 48 + side * 12))
                c.addQuadCurve(to: CGPoint(x: x - 3 + swing, y: 48 + side * 31), control: CGPoint(x: x + 3, y: 48 + side * 24))
                c.strokePath()
            }
            // Claws held out in front.
            c.setLineWidth(3.4)
            c.move(to: CGPoint(x: 55, y: 48 + side * 11))
            c.addQuadCurve(to: CGPoint(x: 67, y: 48 + side * 16), control: CGPoint(x: 60, y: 48 + side * 19))
            c.strokePath()
            c.setLineWidth(2.6)
            c.setFillColor(shell); c.fillEllipse(in: CGRect(x: 63.5, y: 48 + side * 15 - 5.5, width: 12, height: 11))
            c.setFillColor(color(0.99, 0.93, 0.86))
            c.move(to: CGPoint(x: 76, y: 48 + side * 15)); c.addLine(to: CGPoint(x: 70, y: 48 + side * 13.5)); c.addLine(to: CGPoint(x: 70, y: 48 + side * 16.5)); c.fillPath()
        }
        // Body, a paler back, eyes on stalks.
        c.setFillColor(dark); c.fillEllipse(in: CGRect(x: 34, y: 31.5, width: 25, height: 33))
        c.setFillColor(shell); c.fillEllipse(in: CGRect(x: 35.5, y: 33, width: 22, height: 30))
        c.setFillColor(color(0.95, 0.55, 0.38)); c.fillEllipse(in: CGRect(x: 39, y: 38, width: 11, height: 20))
        for side in [-1.0, 1.0] as [CGFloat] {
            c.setFillColor(color(1, 1, 1)); c.fillEllipse(in: CGRect(x: 57, y: 48 + side * 5 - 2.4, width: 4.8, height: 4.8))
            c.setFillColor(color(0.12, 0.10, 0.10)); c.fillEllipse(in: CGRect(x: 59, y: 48 + side * 5 - 1.2, width: 2.4, height: 2.4))
        }
    }

    /// Light with no edge: bright in the middle, gone at the rim.
    private static func orb(_ c: CGContext) {
        let stops = [color(1, 1, 1, 1), color(1, 1, 1, 0.5), color(1, 1, 1, 0.14), color(1, 1, 1, 0)] as CFArray
        guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: stops, locations: [0, 0.22, 0.6, 1]) else { return }
        c.drawRadialGradient(gradient, startCenter: CGPoint(x: 48, y: 48), startRadius: 0, endCenter: CGPoint(x: 48, y: 48), endRadius: 46, options: [])
    }

    /// A dragon's body from above: legs tucked in, a ridged back, a long
    /// neck, a horned head. Its wings and tail are separate, so they can move.
    private static func dragon(_ c: CGContext) {
        let hide = color(0.60, 0.14, 0.11), dark = color(0.34, 0.07, 0.07)
        c.setFillColor(dark)
        for side in [-1.0, 1.0] as [CGFloat] { c.fillEllipse(in: CGRect(x: 33, y: 48 + side * 5.5 - 2.5, width: 10, height: 5)) }
        c.setFillColor(hide); c.fillEllipse(in: CGRect(x: 32, y: 42, width: 33, height: 12))
        polygon(c, [(60, 44.5), (60, 51.5), (80, 50), (80, 46)], hide)
        c.setFillColor(color(0.76, 0.24, 0.16)); c.fillEllipse(in: CGRect(x: 37, y: 45, width: 24, height: 6))
        for k in 0..<9 { let x = CGFloat(34 + k * 5); polygon(c, [(x, 46.6), (x + 3.6, 48), (x, 49.4)], dark) }
        polygon(c, [(79, 45.5), (70, 40), (76, 46.5)], color(0.92, 0.86, 0.72))
        polygon(c, [(79, 50.5), (70, 56), (76, 49.5)], color(0.92, 0.86, 0.72))
        polygon(c, [(76, 44), (84, 44.5), (92, 48), (84, 51.5), (76, 52), (74, 48)], hide)
        c.setFillColor(color(1.0, 0.82, 0.25))
        c.fillEllipse(in: CGRect(x: 81, y: 45, width: 2.2, height: 1.8)); c.fillEllipse(in: CGRect(x: 81, y: 49.2, width: 2.2, height: 1.8))
    }

    // A wing is three pieces, like a bat's: the upper arm, from shoulder to
    // elbow; the forearm, from elbow to wrist; and the hand, three long
    // fingers spreading from the wrist. Each carries the skin behind it, cut
    // generously so the pieces overlap however the wing is folded, and each
    // has its joint at the middle of its cell, so it turns about that. They
    // are drawn as they lie when the wing is fully open.
    private static let wingSkin = color(0.50, 0.11, 0.10), wingEdge = color(0.30, 0.06, 0.06)
    private static let wingHide = color(0.60, 0.14, 0.11), wingRidge = color(0.74, 0.25, 0.16)

    /// A limb or finger: a strip that narrows from one end to the other,
    /// with rounded ends.
    private static func limb(_ c: CGContext, from a: CGPoint, to b: CGPoint, _ w0: CGFloat, _ w1: CGFloat, _ fill: CGColor) {
        let dx = b.x - a.x, dy = b.y - a.y, length = max(sqrt(dx * dx + dy * dy), 0.001)
        let nx = -dy / length, ny = dx / length
        c.move(to: CGPoint(x: a.x + nx * w0 / 2, y: a.y + ny * w0 / 2))
        c.addLine(to: CGPoint(x: b.x + nx * w1 / 2, y: b.y + ny * w1 / 2))
        c.addLine(to: CGPoint(x: b.x - nx * w1 / 2, y: b.y - ny * w1 / 2))
        c.addLine(to: CGPoint(x: a.x - nx * w0 / 2, y: a.y - ny * w0 / 2))
        c.closePath(); c.setFillColor(fill); c.fillPath()
        c.fillEllipse(in: CGRect(x: a.x - w0 / 2, y: a.y - w0 / 2, width: w0, height: w0))
        c.fillEllipse(in: CGRect(x: b.x - w1 / 2, y: b.y - w1 / 2, width: w1, height: w1))
    }

    /// Faint lines of strain in the skin, curving round the joint it hangs from.
    private static func strain(_ c: CGContext, in skin: CGPath, round joint: CGPoint, _ radii: [CGFloat]) {
        c.saveGState(); c.addPath(skin); c.clip()
        c.setStrokeColor(color(0.26, 0.05, 0.05, 0.22)); c.setLineWidth(0.8)
        for radius in radii { c.strokeEllipse(in: CGRect(x: joint.x - radius, y: joint.y - radius, width: radius * 2, height: radius * 2)) }
        c.restoreGState()
    }

    private static func dragonUpperArm(_ c: CGContext) {
        func at(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: 48 + x, y: 48 + y) }
        let skin = CGMutablePath()
        skin.move(to: at(2, -1)); skin.addLine(to: at(-2.3, 8.7)); skin.addLine(to: at(-28, 20))
        skin.addQuadCurve(to: at(-24, 0), control: at(-23, 9))
        skin.closeSubpath()
        c.addPath(skin); c.setFillColor(wingSkin); c.fillPath()
        c.move(to: at(-28, 20)); c.addQuadCurve(to: at(-24, 0), control: at(-23, 9))
        c.setStrokeColor(wingEdge); c.setLineWidth(1.3); c.setLineCap(.round); c.strokePath()
        // The muscled arm, the same hide as the body, with a paler ridge.
        limb(c, from: at(0, 0), to: at(-2.3, 8.7), 5.0, 3.6, wingHide)
        limb(c, from: at(0.6, 0.4), to: at(-1.6, 8.4), 1.6, 1.0, wingRidge)
    }

    private static func dragonForearm(_ c: CGContext) {
        func at(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: 48 + x, y: 48 + y) }
        let skin = CGMutablePath()
        skin.move(to: at(0, 0)); skin.addLine(to: at(5.5, 9.5)); skin.addLine(to: at(-26.5, 12.5))
        skin.addQuadCurve(to: at(-22, -8), control: at(-21, 2))
        skin.closeSubpath()
        c.addPath(skin); c.setFillColor(wingSkin); c.fillPath()
        strain(c, in: skin, round: at(0, 0), [9, 15])
        limb(c, from: at(0, 0), to: at(5.5, 9.5), 3.6, 2.6, wingHide)
        limb(c, from: at(0.7, 0.2), to: at(5.9, 9.2), 1.2, 0.8, wingRidge)
    }

    private static func dragonHand(_ c: CGContext) {
        func at(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: 48 + x, y: 48 + y) }
        let wrist = at(0, 0), ends = [at(-18, 26), at(-25, 14), at(-32, 3)]
        let skin = CGMutablePath()
        skin.move(to: wrist)
        skin.addQuadCurve(to: ends[0], control: at(-3, 17))
        skin.addQuadCurve(to: ends[1], control: at(-18, 17))
        skin.addQuadCurve(to: ends[2], control: at(-25, 6))
        skin.addLine(to: at(-30, -2))
        skin.closeSubpath()
        // The skin: a touch lighter by the wrist, deepening toward the edge.
        c.saveGState(); c.addPath(skin); c.clip()
        let tones = [color(0.54, 0.13, 0.10), wingSkin, color(0.42, 0.09, 0.09)] as CFArray
        if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: tones, locations: [0, 0.45, 1]) {
            c.drawRadialGradient(gradient, startCenter: wrist, startRadius: 0, endCenter: wrist, endRadius: 34, options: [.drawsAfterEndLocation])
        }
        c.restoreGState()
        strain(c, in: skin, round: wrist, [11, 19, 27])
        // The trailing edge, scalloped between the finger tips, a shade darker.
        let edge = CGMutablePath()
        edge.move(to: ends[0])
        edge.addQuadCurve(to: ends[1], control: at(-18, 17))
        edge.addQuadCurve(to: ends[2], control: at(-25, 6))
        c.addPath(edge); c.setStrokeColor(wingEdge); c.setLineWidth(1.3); c.setLineCap(.round); c.strokePath()
        // Three fingers, each tapering to nothing, a thin shadow behind each.
        for end in ends {
            limb(c, from: CGPoint(x: wrist.x - 0.7, y: wrist.y + 0.5), to: CGPoint(x: end.x - 0.7, y: end.y + 0.5), 2.6, 0.9, color(0.30, 0.06, 0.06, 0.55))
            limb(c, from: wrist, to: end, 2.4, 0.7, wingHide)
        }
        limb(c, from: wrist, to: ends[0], 0.9, 0.3, wingRidge)
        // The wrist, and the claw of the thumb pointing forward from it.
        c.setFillColor(wingHide); c.fillEllipse(in: CGRect(x: wrist.x - 2.0, y: wrist.y - 2.0, width: 4.0, height: 4.0))
        polygon(c, [(48 + 0.5, 48 + 1.6), (48 + 5.5, 48 + 2.6), (48 + 1.6, 48 - 0.6)], color(0.90, 0.84, 0.70))
    }

    private static func polygon(_ c: CGContext, _ points: [(CGFloat, CGFloat)], _ fill: CGColor) {
        c.move(to: CGPoint(x: points[0].0, y: points[0].1))
        for point in points.dropFirst() { c.addLine(to: CGPoint(x: point.0, y: point.1)) }
        c.closePath(); c.setFillColor(fill); c.fillPath()
    }

    private static func balloon(_ c: CGContext) {
        // From above: twelve gores, light and dark by turns, round a crown.
        let centre = CGPoint(x: 48, y: 48)
        for i in 0..<12 {
            let a0 = CGFloat(i) / 12 * 2 * .pi, a1 = CGFloat(i + 1) / 12 * 2 * .pi
            c.move(to: centre)
            c.addArc(center: centre, radius: 38, startAngle: a0, endAngle: a1, clockwise: false)
            c.closePath()
            c.setFillColor(i % 2 == 0 ? color(1, 1, 1) : color(0.66, 0.66, 0.66)); c.fillPath()
        }
        // The side away from the sun is darker; the crown catches the light.
        c.saveGState()
        c.addEllipse(in: CGRect(x: 10, y: 10, width: 76, height: 76)); c.clip()
        c.setFillColor(color(0, 0, 0, 0.20)); c.fillEllipse(in: CGRect(x: 24, y: 26, width: 86, height: 86))
        c.restoreGState()
        c.setFillColor(color(1, 1, 1)); c.fillEllipse(in: CGRect(x: 40, y: 40, width: 16, height: 16))
        c.setFillColor(color(0.55, 0.55, 0.55)); c.fillEllipse(in: CGRect(x: 44.5, y: 44.5, width: 7, height: 7))
    }

    private static func airliner(_ c: CGContext) {
        let wing = color(0.84, 0.87, 0.92), body = color(0.97, 0.97, 0.98)
        for side in [-1.0, 1.0] as [CGFloat] {
            polygon(c, [(56, 48), (38, 48 + side * 40), (31, 48 + side * 40), (40, 48)], wing)
            polygon(c, [(22, 48), (13, 48 + side * 15), (9, 48 + side * 15), (13, 48)], wing)
            c.setFillColor(color(0.50, 0.54, 0.62))
            c.addPath(CGPath(roundedRect: CGRect(x: 43, y: 48 + side * 16 - 2.5, width: 11, height: 5), cornerWidth: 2, cornerHeight: 2, transform: nil)); c.fillPath()
        }
        c.addPath(CGPath(roundedRect: CGRect(x: 8, y: 43.5, width: 80, height: 9), cornerWidth: 4.5, cornerHeight: 4.5, transform: nil))
        c.setFillColor(body); c.fillPath()
        c.setFillColor(color(0.25, 0.32, 0.45)); c.fillEllipse(in: CGRect(x: 80, y: 45.5, width: 5, height: 5))
    }

    private static func bird(_ c: CGContext, spread: CGFloat) {
        // Wings swept back from the shoulders; `spread` folds them on the upbeat.
        for side in [-1.0, 1.0] as [CGFloat] {
            let tip = CGPoint(x: 40 - 8 * (1 - spread), y: 48 + side * 40 * spread)
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 58, y: 48 + side * 3))
            path.addQuadCurve(to: tip, control: CGPoint(x: 58, y: 48 + side * 26 * spread))
            path.addQuadCurve(to: CGPoint(x: 44, y: 48 + side * 3), control: CGPoint(x: 44, y: 48 + side * 20 * spread))
            c.addPath(path); c.setFillColor(color(0.97, 0.97, 0.97)); c.fillPath()
            c.setFillColor(color(0.45, 0.47, 0.52)); c.fillEllipse(in: CGRect(x: tip.x - 3, y: tip.y - 3, width: 7, height: 6))
        }
        polygon(c, [(40, 44), (24, 41), (27, 48), (24, 55), (40, 52)], color(0.90, 0.90, 0.90))
        c.setFillColor(color(1, 1, 1)); c.fillEllipse(in: CGRect(x: 36, y: 42, width: 32, height: 12))
        polygon(c, [(66, 45.5), (76, 48), (66, 50.5)], color(0.95, 0.70, 0.25))
    }

    private static func skater(_ c: CGContext, stride: CGFloat) {
        // From above: skates, a mustard coat with arms swinging, a red hat.
        c.setFillColor(color(0.16, 0.17, 0.22))
        c.addPath(CGPath(roundedRect: CGRect(x: 52 + stride * 12, y: 39, width: 20, height: 6), cornerWidth: 3, cornerHeight: 3, transform: nil))
        c.addPath(CGPath(roundedRect: CGRect(x: 52 - stride * 12 - 20, y: 51, width: 20, height: 6), cornerWidth: 3, cornerHeight: 3, transform: nil))
        c.fillPath()
        c.setFillColor(color(0.80, 0.55, 0.14))
        c.fillEllipse(in: CGRect(x: 44 - stride * 9, y: 24, width: 12, height: 14))
        c.fillEllipse(in: CGRect(x: 44 + stride * 9, y: 58, width: 12, height: 14))
        c.setFillColor(color(0.92, 0.68, 0.20)); c.fillEllipse(in: CGRect(x: 37, y: 28, width: 22, height: 40))
        c.setFillColor(color(0.24, 0.42, 0.62))
        c.addPath(CGPath(roundedRect: CGRect(x: 24, y: 45, width: 20, height: 6), cornerWidth: 3, cornerHeight: 3, transform: nil)); c.fillPath()
        c.setFillColor(color(0.78, 0.22, 0.20)); c.fillEllipse(in: CGRect(x: 40, y: 39, width: 19, height: 18))
        c.setFillColor(color(0.98, 0.96, 0.92)); c.fillEllipse(in: CGRect(x: 46, y: 44.5, width: 7, height: 7))
    }

    private static func fox(_ c: CGContext) {
        let coat = color(0.88, 0.47, 0.17), white = color(0.98, 0.96, 0.92), dark = color(0.22, 0.16, 0.14)
        c.setFillColor(coat); c.fillEllipse(in: CGRect(x: 12, y: 42, width: 32, height: 12))
        c.setFillColor(white); c.fillEllipse(in: CGRect(x: 8, y: 43.5, width: 13, height: 9))
        for (x, y) in [(40.0, 37.0), (58.0, 37.0), (40.0, 59.0), (58.0, 59.0)] as [(CGFloat, CGFloat)] {
            c.setFillColor(dark); c.fillEllipse(in: CGRect(x: x - 3, y: y - 3, width: 7, height: 6))
        }
        c.setFillColor(coat); c.fillEllipse(in: CGRect(x: 32, y: 38.5, width: 36, height: 19))
        polygon(c, [(66, 38), (61, 31), (72, 37)], dark)
        polygon(c, [(66, 58), (61, 65), (72, 59)], dark)
        polygon(c, [(60, 39), (74, 40), (88, 48), (74, 56), (60, 57)], coat)
        polygon(c, [(76, 44), (88, 48), (76, 52)], white)
        c.setFillColor(dark); c.fillEllipse(in: CGRect(x: 85, y: 46, width: 4.5, height: 4))
    }

    /// A loaded camel from above: long neck and small head forward, two humps
    /// along its back, a bundle slung on either side.
    private static func camel(_ c: CGContext, stride: CGFloat) {
        let hide = color(0.66, 0.46, 0.28), pale = color(0.78, 0.58, 0.37), dark = color(0.42, 0.28, 0.17)
        c.setLineCap(.round)
        // Tail, body, neck, head.
        c.setStrokeColor(dark); c.setLineWidth(2)
        c.move(to: CGPoint(x: 28, y: 48)); c.addLine(to: CGPoint(x: 18, y: 48 + 3 * stride)); c.strokePath()
        c.setFillColor(hide); c.fillEllipse(in: CGRect(x: 25, y: 38, width: 44, height: 20))
        let nod = 1.5 * stride
        c.setStrokeColor(hide); c.setLineWidth(6.5)
        c.move(to: CGPoint(x: 64, y: 48)); c.addLine(to: CGPoint(x: 82, y: 48 + nod)); c.strokePath()
        c.setFillColor(dark)
        c.fillEllipse(in: CGRect(x: 79.5, y: 42.5 + nod, width: 3.5, height: 3)); c.fillEllipse(in: CGRect(x: 79.5, y: 50.5 + nod, width: 3.5, height: 3))
        c.setFillColor(hide); c.fillEllipse(in: CGRect(x: 79, y: 44 + nod, width: 13, height: 8))
        c.setFillColor(dark); c.fillEllipse(in: CGRect(x: 88.5, y: 46 + nod, width: 4, height: 4))
        // The load: a bundle slung on each side, under the blanket.
        for y in [30.5, 57.5] as [CGFloat] {
            c.addPath(CGPath(roundedRect: CGRect(x: 38, y: y, width: 19, height: 8), cornerWidth: 3, cornerHeight: 3, transform: nil))
            c.setFillColor(color(0.87, 0.82, 0.70)); c.fillPath()
            c.setFillColor(color(0.45, 0.33, 0.24)); c.fill(CGRect(x: 43, y: y, width: 1.5, height: 8)); c.fill(CGRect(x: 51, y: y, width: 1.5, height: 8))
        }
        c.setFillColor(color(0.74, 0.24, 0.22)); c.fill(CGRect(x: 42.5, y: 36, width: 10, height: 24))
        c.setFillColor(color(0.95, 0.80, 0.40)); c.fill(CGRect(x: 42.5, y: 39, width: 10, height: 1.8)); c.fill(CGRect(x: 42.5, y: 55.2, width: 10, height: 1.8))
        // Two humps, lit from the upper left.
        for x in [38.0, 57.0] as [CGFloat] {
            c.setFillColor(dark); c.fillEllipse(in: CGRect(x: x - 6.5, y: 41, width: 13, height: 14))
            c.setFillColor(pale); c.fillEllipse(in: CGRect(x: x - 7.3, y: 40.2, width: 11.5, height: 12))
        }
    }

    /// The camel's shadow thrown flat on the sand by a low sun: its side
    /// view, feet on the middle line of the cell, back toward the bottom.
    private static func camelProfile(_ c: CGContext, stride: CGFloat) {
        let ink = color(1, 1, 1)
        c.setFillColor(ink); c.setStrokeColor(ink); c.setLineCap(.round)
        // Its legs are separate sprites, so the shadow can walk.
        // Body, two humps, the load between them.
        c.fillEllipse(in: CGRect(x: 28, y: 65, width: 44, height: 15))
        c.fillEllipse(in: CGRect(x: 33, y: 73, width: 14, height: 14))
        c.fillEllipse(in: CGRect(x: 52, y: 73, width: 14, height: 14))
        c.fill(CGRect(x: 42, y: 66, width: 14, height: 16))
        // Neck curving up to the head, and the tail.
        c.setLineWidth(6)
        c.move(to: CGPoint(x: 68, y: 70))
        c.addQuadCurve(to: CGPoint(x: 80, y: 89), control: CGPoint(x: 80, y: 70)); c.strokePath()
        c.fillEllipse(in: CGRect(x: 77, y: 85.5, width: 15, height: 7.5))
        c.setLineWidth(2)
        c.move(to: CGPoint(x: 29, y: 72)); c.addLine(to: CGPoint(x: 24, y: 60 + 2 * stride)); c.strokePath()
    }
    private static func ray(_ c: CGContext) {
        let back = color(0.34, 0.40, 0.50)
        c.setStrokeColor(back); c.setLineWidth(2.2); c.setLineCap(.round)
        c.move(to: CGPoint(x: 34, y: 48)); c.addQuadCurve(to: CGPoint(x: 3, y: 46), control: CGPoint(x: 18, y: 51)); c.strokePath()
        let body = CGMutablePath()
        body.move(to: CGPoint(x: 86, y: 48))
        body.addQuadCurve(to: CGPoint(x: 50, y: 10), control: CGPoint(x: 78, y: 26))
        body.addQuadCurve(to: CGPoint(x: 30, y: 48), control: CGPoint(x: 40, y: 34))
        body.addQuadCurve(to: CGPoint(x: 50, y: 86), control: CGPoint(x: 40, y: 62))
        body.addQuadCurve(to: CGPoint(x: 86, y: 48), control: CGPoint(x: 78, y: 70))
        c.addPath(body); c.setFillColor(back); c.fillPath()
        c.setFillColor(color(0.44, 0.51, 0.61)); c.fillEllipse(in: CGRect(x: 44, y: 36, width: 30, height: 24))
        c.setFillColor(color(0.56, 0.63, 0.72))
        for (x, y) in [(54.0, 26.0), (48.0, 68.0), (62.0, 62.0), (60.0, 34.0)] as [(CGFloat, CGFloat)] { c.fillEllipse(in: CGRect(x: x, y: y, width: 4, height: 4)) }
        c.setFillColor(color(0.12, 0.14, 0.18))
        c.fillEllipse(in: CGRect(x: 74, y: 42, width: 3, height: 3)); c.fillEllipse(in: CGRect(x: 74, y: 51, width: 3, height: 3))
    }

    private static func fish(_ c: CGContext) {
        polygon(c, [(30, 48), (10, 32), (14, 48), (10, 64)], color(0.70, 0.70, 0.70))
        let body = CGMutablePath()
        body.move(to: CGPoint(x: 88, y: 48))
        body.addQuadCurve(to: CGPoint(x: 26, y: 48), control: CGPoint(x: 58, y: 18))
        body.addQuadCurve(to: CGPoint(x: 88, y: 48), control: CGPoint(x: 58, y: 78))
        c.addPath(body); c.setFillColor(color(1, 1, 1)); c.fillPath()
        c.saveGState(); c.addPath(body); c.clip()
        c.setFillColor(color(0.55, 0.55, 0.55)); c.fill(CGRect(x: 40, y: 20, width: 8, height: 56)); c.fill(CGRect(x: 58, y: 20, width: 8, height: 56))
        c.restoreGState()
        c.setFillColor(color(0.10, 0.10, 0.12)); c.fillEllipse(in: CGRect(x: 74, y: 41, width: 6, height: 6))
    }
}
