import Foundation
import simd

/// A landscape is a world with its own drawing code (one Shader*.swift file
/// each) and its own inhabitants. The raw value is the number the shaders
/// see in `Uniforms.landscape`.
enum Landscape: Int32, CaseIterable {
    case shore = 0
    case clouds = 1
    case lake = 2
    case oasis = 3
    case reef = 4
    case grid = 5
    case forest = 6
    case city = 7
    case pixel = 8

    /// The fragment functions that draw it.
    var groundFunction: String { ["shoreGround", "cloudsGround", "lakeGround", "oasisGround", "reefGround", "gridGround", "forestGround", "cityGround", "pixelGround"][Int(rawValue)] }
    /// These make their own light: the hour changes what they show, but the
    /// sun does not tint them.
    var selfLit: Bool { self == .grid || self == .city }

    var sceneFunction: String { ["shoreScene", "cloudsScene", "lakeScene", "oasisScene", "reefScene", "gridScene", "forestScene", "cityScene", "pixelScene"][Int(rawValue)] }
}

/// A theme is a landscape plus data: the eight palette slots that landscape's
/// shader documents, and the light that falls on its sprites. Both are given
/// as they look at midday; Daylight.swift turns them through the day and night.
struct ThemeSpec {
    var landscape: Landscape
    var colors: [SIMD4<Float>]
    var actorTint: SIMD3<Float>
}

enum Theme: Int32, CaseIterable {
    case island = 0
    case clouds = 4
    case lake = 5
    case oasis = 6
    case reef = 7
    case grid = 8
    case forest = 9
    case city = 10
    case pixel = 11

    var title: String {
        switch self {
        case .island: return "Island"
        case .clouds: return "Above the Clouds"
        case .lake: return "Frozen Lake"
        case .oasis: return "Desert Oasis"
        case .reef: return "Coral Reef"
        case .grid: return "Neon Grid"
        case .forest: return "Enchanted Forest"
        case .city: return "ASCII City"
        case .pixel: return "Pixel Quest"
        }
    }

    /// The name used on the command line and in file names.
    var slug: String {
        switch self {
        case .island: return "island"
        case .clouds: return "clouds"
        case .lake: return "lake"
        case .oasis: return "oasis"
        case .reef: return "reef"
        case .grid: return "grid"
        case .forest: return "forest"
        case .city: return "city"
        case .pixel: return "pixel"
        }
    }

    init?(name: String) {
        guard let match = Theme.allCases.first(where: { $0.slug == name.lowercased() }) else { return nil }
        self = match
    }

    private static let key = "theme"

    static var saved: Theme {
        Theme(rawValue: Int32(UserDefaults.standard.integer(forKey: key))) ?? .island
    }

    func save() {
        UserDefaults.standard.set(Int(rawValue), forKey: Theme.key)
    }

    var spec: ThemeSpec {
        switch self {
        case .island:
            // Cream sand, clear lagoon water.
            return ThemeSpec(landscape: .shore, colors: [
                [0.905, 0.850, 0.755, 0],     // dry sand
                [0.960, 0.890, 0.750, 0],     // wetting
                [0.200, 0.790, 0.810, 0],     // shallows
                [0.030, 0.540, 0.740, 0],     // open water
                [2.6, 0.55, 0.36, 0.9],       // loss with depth
                [1.000, 1.000, 0.990, 1.0],   // foam
                [1.000, 1.000, 0.970, 1.0],   // sparkles
                [0.930, 0.900, 0.880, 0.5],   // shade on sand
            ], actorTint: [1.0, 1.0, 1.0])
        case .clouds:
            // A bright morning: farmland and a lake far below, fair-weather cloud.
            return ThemeSpec(landscape: .clouds, colors: [
                [0.200, 0.470, 0.720, 0],     // lake
                [0.470, 0.640, 0.360, 0],     // field, green
                [0.640, 0.740, 0.430, 0],     // field, pale green
                [0.840, 0.770, 0.500, 0],     // field, wheat
                [0.220, 0.400, 0.260, 0],     // woods and hedges
                [1.000, 0.990, 0.975, 0],     // cloud in the light
                [0.790, 0.850, 0.940, 0],     // cloud in shade
                [0.650, 0.760, 0.880, 0],     // haze
            ], actorTint: [1.0, 1.0, 1.0])
        case .lake:
            // A clear winter day: blue ice, soft snow.
            return ThemeSpec(landscape: .lake, colors: [
                [0.500, 0.670, 0.810, 0],     // ice
                [0.400, 0.580, 0.760, 0],     // ice, deeper tone
                [0.945, 0.960, 0.985, 0],     // snow
                [0.780, 0.850, 0.950, 0],     // snow in shade
                [0.860, 0.930, 0.990, 0],     // frost and cracks
                [0.700, 0.780, 0.920, 0],     // shadow on ice and snow
                [0.290, 0.500, 0.370, 0],     // fir
            ], actorTint: [0.95, 0.97, 1.0])
        case .oasis:
            // Late afternoon: warm dunes, a turquoise pool.
            return ThemeSpec(landscape: .oasis, colors: [
                [0.945, 0.820, 0.600, 0],     // sand in the light
                [0.900, 0.745, 0.520, 0],     // sand
                [0.800, 0.620, 0.420, 0],     // sand in shade
                [0.340, 0.500, 0.240, 0],     // green bank
                [0.250, 0.640, 0.640, 0],     // pool at its edge
                [0.090, 0.400, 0.500, 0],     // pool at its deepest
                [0.130, 0.330, 0.180, 0],     // palm, dark
                [0.380, 0.580, 0.250, 0],     // palm, light
            ], actorTint: [1.0, 0.97, 0.92])
        case .reef:
            // Shallow tropical water over coral.
            return ThemeSpec(landscape: .reef, colors: [
                [0.300, 0.570, 0.610, 0],     // sea bed
                [0.110, 0.320, 0.430, 0],     // rock
                [0.800, 0.480, 0.500, 0],     // coral, pink
                [0.800, 0.660, 0.420, 0],     // coral, ochre
                [0.520, 0.460, 0.700, 0],     // coral, violet
                [0.800, 1.000, 0.950, 0],     // light from the surface
                [0.550, 0.750, 0.950, 0],     // what depth does to colour
                [0.550, 0.720, 0.800, 0],     // shadow under the reef's lip
            ], actorTint: [0.82, 0.96, 1.0])
        case .grid:
            // Lines of light on a dark floor: blue by day, red by night.
            return ThemeSpec(landscape: .grid, colors: [
                [0.010, 0.018, 0.036, 0],     // floor
                [0.080, 0.600, 1.000, 0],     // the light by day
                [1.000, 0.150, 0.090, 0],     // the light at night
                [1.000, 0.600, 0.100, 0],     // the rival racer by day
                [1.000, 0.860, 0.560, 0],     // the rival racer at night
            ], actorTint: [1.0, 1.0, 1.0])
        case .forest:
            // A mossy glade deep in an old wood.
            return ThemeSpec(landscape: .forest, colors: [
                [0.270, 0.400, 0.230, 0],     // moss of the glade
                [0.120, 0.310, 0.180, 0],     // leaf, dark green
                [0.240, 0.360, 0.150, 0],     // leaf, olive
                [0.600, 0.500, 0.180, 0],     // leaf, gold
                [0.520, 0.540, 0.520, 0],     // stone
                [0.500, 0.920, 0.850, 0],     // water and everything that glows
                [0.720, 0.800, 0.800, 0],     // mist
                [0.060, 0.105, 0.080, 0],     // forest floor
            ], actorTint: [1.0, 1.0, 1.0])
        case .city:
            // A town plan typed on pale paper by day, glowing on dark by night.
            return ThemeSpec(landscape: .city, colors: [
                [0.860, 0.840, 0.770, 0],     // paper by day
                [0.018, 0.024, 0.052, 0],     // paper by night
                [0.150, 0.170, 0.230, 0],     // type by day
                [0.330, 0.460, 0.820, 0],     // type by night
                [1.000, 0.800, 0.380, 0],     // lit windows, lamps and headlights
                [0.420, 0.720, 0.400, 0],     // parks
                [0.640, 0.640, 0.640, 0],     // streets by day
            ], actorTint: [1.0, 1.0, 1.0])
        case .pixel:
            // The overworld of a 16-bit adventure; its colours are in PixelArt.swift.
            return ThemeSpec(landscape: .pixel, colors: [
                [1.000, 0.860, 0.450, 0],     // lamplight in the windows
                [0.450, 0.620, 0.800, 0],     // foam on the water
                [0.640, 0.580, 0.420, 0],     // sand at its edge
            ], actorTint: [1.0, 1.0, 1.0])
        }
    }
}
