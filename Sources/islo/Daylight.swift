import Foundation
import simd

/// The light at one moment of the day, worked out from the clock.
///
/// The sun follows its real path for the date at a middling northern
/// latitude: short, low days in winter and long, high ones in summer. The
/// picture is seen from above with south at the top, so the light comes from
/// the upper left in the morning, from the top at noon and from the upper
/// right in the evening. After dark a full moon takes the sun's place,
/// opposite it in the sky, and throws fainter shadows.
struct Daylight {
    /// The way shadows fall on the screen, as a unit vector.
    var fall: SIMD2<Float>
    /// How long they are: 1 for a sun well up, more as it sinks.
    var reach: Float
    /// How dark they are, 0…1: nothing at twilight, faint by moonlight.
    var strength: Float
    /// The colour of the light.
    var colour: SIMD3<Float>
    /// How much colour the dark takes out of things, 0…1.
    var fade: Float
    /// 0 by day, 1 by night, turning over through dawn and dusk.
    var night: Float

    /// Set by the review harness to look at a fixed hour instead of the clock.
    static var fixedHour: Double?

    static var now: Daylight {
        let date = Date()
        let calendar = Calendar.current
        let day = calendar.ordinality(of: .day, in: .year, for: date) ?? 1
        if let hour = fixedHour { return at(hour: hour, dayOfYear: day) }
        // Sun time: the clock without the summer hour.
        let parts = calendar.dateComponents([.hour, .minute, .second], from: date)
        var hour = Double(parts.hour ?? 12) + Double(parts.minute ?? 0) / 60 + Double(parts.second ?? 0) / 3600
        hour -= calendar.timeZone.daylightSavingTimeOffset(for: date) / 3600
        return at(hour: hour, dayOfYear: day)
    }

    private static let latitude = 45.0 * Double.pi / 180

    static func at(hour: Double, dayOfYear: Int) -> Daylight {
        let tilt = -23.44 * Double.pi / 180 * cos(2 * Double.pi * (Double(dayOfYear) + 10) / 365)
        let turn = (hour - 12) * 15 * Double.pi / 180
        // Where the sun stands: toward the east, toward the north, and up.
        let east = -cos(tilt) * sin(turn)
        let north = cos(latitude) * sin(tilt) - sin(latitude) * cos(tilt) * cos(turn)
        let up = sin(latitude) * sin(tilt) + cos(latitude) * cos(tilt) * cos(turn)
        let height = asin(max(-1, min(1, up))) * 180 / Double.pi   // degrees above the horizon

        // South is at the top of the screen, so east is on the left. A shadow
        // falls away from the sun; the moon stands opposite and throws it back.
        var fall = SIMD2<Double>(east, -north)
        let flat = simd_length(fall)
        fall = flat > 0.0001 ? fall / flat : [0.6, 0.8]
        if height < 0 { fall = -fall }

        let above = max(abs(height), 1) * Double.pi / 180
        let reach = min(max((1 / tan(above)) / 1.28, 0.5), 2.2)
        let strength = height > 0 ? smooth(0, 8, height) : 0.45 * smooth(4, 14, -height)

        // The colour of the light against the height of the sun.
        let keys: [(Double, SIMD3<Double>, Double)] = [
            (-14, [0.30, 0.38, 0.58], 0.45),   // night
            (-6, [0.52, 0.48, 0.70], 0.30),    // dusk
            (0, [0.97, 0.79, 0.67], 0.05),     // the sun on the horizon
            (6, [1.00, 0.93, 0.83], 0.0),      // golden hour
            (20, [1.00, 1.00, 1.00], 0.0),     // day
        ]
        var colour = keys[0].1, fade = keys[0].2
        if height >= keys[keys.count - 1].0 {
            colour = keys[keys.count - 1].1
            fade = keys[keys.count - 1].2
        } else if height > keys[0].0 {
            for i in 1..<keys.count where height <= keys[i].0 {
                let k = (height - keys[i - 1].0) / (keys[i].0 - keys[i - 1].0)
                colour = keys[i - 1].1 + (keys[i].1 - keys[i - 1].1) * k
                fade = keys[i - 1].2 + (keys[i].2 - keys[i - 1].2) * k
                break
            }
        }
        return Daylight(fall: SIMD2<Float>(Float(fall.x), Float(fall.y)), reach: Float(reach), strength: Float(strength),
                        colour: SIMD3<Float>(Float(colour.x), Float(colour.y), Float(colour.z)), fade: Float(fade),
                        night: Float(1 - smooth(-7, 5, height)))
    }

    private static func smooth(_ from: Double, _ to: Double, _ x: Double) -> Double {
        let k = max(0, min(1, (x - from) / (to - from)))
        return k * k * (3 - 2 * k)
    }

}
