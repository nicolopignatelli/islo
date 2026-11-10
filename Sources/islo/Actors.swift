import Foundation
import simd

/// One sprite to draw. Must match `SpriteIn` in ShaderCommon.swift.
struct SpriteInstance {
    var pos: SIMD2<Float>
    var size: SIMD2<Float>
    var cell: SIMD2<Float>
    var angle: Float
    var alpha: Float
    var tint: SIMD4<Float>
    /// If not zero, the sprite's height runs this way and this far instead
    /// of square to its length: a shadow thrown on the ground.
    var fall: SIMD2<Float> = .zero
    /// x = 1: it gives its own light, and the hour does not tint it.
    var glow: SIMD2<Float> = .zero
}

/// A copy of the terrain the actors can look at, one sample every `step`
/// points: height above the edge of the icons' ground, and clearance from icons.
struct Terrain {
    var width: Int
    var height: Int
    var step: Float
    var level: [Float]
    var clear: [Float]
    /// In the pixel world only: for each 48-point tile, whether it can be walked on.
    var walk: [Bool] = []
    /// And whether it is open water a ship can cross.
    var sail: [Bool] = []
    var walkColumns = 0

    private func tile(_ p: SIMD2<Float>) -> Int? {
        guard walkColumns > 0, p.x >= 0, p.y >= 0 else { return nil }
        let column = Int(p.x / 48), row = Int(p.y / 48)
        guard column < walkColumns, row * walkColumns + column < walk.count else { return nil }
        return row * walkColumns + column
    }
    func walkable(at p: SIMD2<Float>) -> Bool { tile(p).map { walk[$0] } ?? false }
    func sailable(at p: SIMD2<Float>) -> Bool { tile(p).map { sail[$0] } ?? false }

    private func index(_ p: SIMD2<Float>) -> Int? {
        let x = Int(p.x / step), y = Int(p.y / step)
        guard p.x >= 0, p.y >= 0, x < width, y < height else { return nil }
        return y * width + x
    }

    /// nil off screen.
    func level(at p: SIMD2<Float>) -> Float? { index(p).map { level[$0] } }
    func clearance(at p: SIMD2<Float>) -> Float { index(p).map { clear[$0] } ?? 0 }
}

private enum Kind {
    case boat, turtle, crab          // shore
    case balloon, flock, plane       // clouds
    case skater, fox                 // frozen lake
    case caravan, hawk               // oasis
    case school, ray                 // reef
    case racer                       // neon grid
    case wisp, dragon                // the old forest
    case hero, ship, eagle           // pixel quest

    enum Gait { case cruise, hop, circle, lines }

    var gait: Gait {
        switch self {
        case .crab: return .hop
        case .hawk: return .circle
        case .racer, .hero, .ship: return .lines
        default: return .cruise
        }
    }

    /// Speed in points a second, how far ahead it looks, how fast it turns.
    var motion: (speed: Float, look: Float, turn: Float) {
        switch self {
        case .boat: return (13, 80, 0.8)
        case .turtle: return (8, 45, 1.1)
        case .crab: return (24, 16, 5)
        case .balloon: return (4.5, 70, 0.4)
        case .flock: return (22, 90, 0.7)
        case .plane: return (55, 60, 0)
        case .skater: return (30, 42, 2.4)
        case .fox: return (15, 40, 1.4)
        case .caravan: return (7, 70, 0.5)
        case .hawk: return (20, 0, 0.42)
        case .school: return (17, 60, 1.2)
        case .ray: return (9, 70, 0.6)
        case .racer: return (80, 0, 0)
        case .wisp: return (11, 40, 1.2)
        case .dragon: return (42, 60, 0)
        case .hero: return (30, 0, 0)
        case .ship: return (13, 0, 0)
        case .eagle: return (58, 0, 0)
        }
    }

    /// Distance between marks left behind, how many are kept, how long they last.
    var trail: (spacing: Float, count: Int, life: Float)? {
        switch self {
        case .skater: return (4, 70, 9)
        case .fox: return (8, 45, 30)
        case .caravan: return (6, 80, 1000)    // not drawn: the camels behind walk in these steps
        case .plane: return (9, 90, 14)        // the vapour it leaves, spreading and fading
        case .racer: return (8, 70, 8)         // the wall of light behind it
        case .wisp: return (7, 12, 2.5)        // sparks it sheds
        default: return nil
        }
    }
}

private struct Mark {
    var pos: SIMD2<Float>
    var heading: Float
    var age: Float = 0
}

/// One fish of a school: it swims for itself, keeping near its place.
private struct Fish {
    var pos: SIMD2<Float>
    var vel: SIMD2<Float>
    var slot: SIMD2<Float>
    var stroke: Float
}

private struct Actor {
    var kind: Kind
    var pos: SIMD2<Float>
    var heading: Float
    var alpha: Float = 0
    var age: Float = 0
    var seed: Float
    /// Hoppers alternate between moving and standing still.
    var moving = true
    var timer: Float = 0
    var marks: [Mark] = []
    /// A school's fish.
    var fish: [Fish] = []
    /// A turn still being made (radians left), and a spurt of speed dying away.
    var veer: Float = 0
    var spurt: Float = 0
    /// How steadily a plane banks, radians a second.
    var bank: Float = 0
}

/// The inhabitants of a landscape: where they are and what they do next.
/// Each keeps to its own ground by looking a little ahead on the terrain and
/// turning away from what is not home.
final class ActorSystem {
    var terrain: Terrain?
    var landscape: Landscape = .shore {
        didSet { if landscape != oldValue { reset() } }
    }
    private var actors: [Actor] = []
    private var state: UInt64 = 42
    /// 1 just after the ground changed, fading to 0: fish scatter while it lasts.
    private var alarm: Float = 0
    private var scatter = false

    private var roster: [(Kind, Int)] {
        switch landscape {
        case .shore: return [(.boat, 3), (.turtle, 4), (.crab, 5)]
        case .clouds: return [(.flock, 2), (.plane, 1)]
        case .lake: return [(.skater, 2), (.fox, 1)]
        case .oasis: return [(.caravan, 1), (.hawk, 1)]
        case .reef: return [(.school, 2), (.ray, 1)]
        case .grid: return [(.racer, 3)]
        case .forest: return [(.wisp, 4), (.dragon, 1)]
        case .city: return []
        case .pixel: return [(.hero, 3), (.ship, 1), (.eagle, 1)]
        }
    }

    private func random() -> Float {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        z ^= z >> 31
        return Float(z >> 40) / Float(1 << 24)
    }

    func reset() {
        actors.removeAll()
        state = 42
        alarm = 0
    }

    /// The ground just changed somewhere.
    func startle() {
        alarm = 1
        scatter = true
    }

    private func isHome(_ kind: Kind, _ p: SIMD2<Float>, in terrain: Terrain) -> Bool {
        guard let level = terrain.level(at: p) else { return false }
        let clear = terrain.clearance(at: p)
        switch kind {
        case .boat: return level < -0.21
        case .turtle: return level > -0.34 && level < -0.08
        case .crab: return level > 0.15 && clear > 1.35
        case .balloon: return clear > 1.5
        case .flock: return clear > 1.2
        case .plane, .hawk, .dragon, .eagle: return true
        case .skater: return level > 0.07 && clear > 1.3
        case .fox: return level < -0.08
        case .caravan: return level < -0.16
        case .school: return clear > 1.35
        case .ray: return clear > 1.4
        case .racer: return level < -0.20 && clear > 1.6
        case .wisp: return level < -0.07
        case .hero: return terrain.walkable(at: p) && clear > 1.5      // never across an icon
        case .ship: return terrain.sailable(at: p)
        }
    }

    func update(dt: Float, size: SIMD2<Float>) {
        guard let terrain else { return }
        alarm = max(alarm - dt * 0.5, 0)

        // Bring in whoever is missing, where there is room for them.
        for (kind, wanted) in roster where actors.filter({ $0.kind == kind }).count < wanted {
            if kind == .plane || kind == .dragon || kind == .eagle {
                // A plane comes in from beyond any edge, now and then, bound
                // for somewhere across the middle of the view, on a long shallow
                // curve. So does a dragon, more seldom.
                guard random() < dt * (kind == .dragon ? 0.025 : 0.05) else { continue }
                let out: Float = kind == .dragon ? 120 : 60
                let along = random()
                let p: SIMD2<Float>
                let edge = Int(random() * 3.999)
                switch edge {
                case 0: p = [-out, size.y * along]
                case 1: p = [size.x + out, size.y * along]
                case 2: p = [size.x * along, -out]
                default: p = [size.x * along, size.y + out]
                }
                let aim = SIMD2<Float>(size.x * (0.25 + 0.5 * random()), size.y * (0.25 + 0.5 * random()))
                var plane = Actor(kind: kind, pos: p, heading: atan2(aim.y - p.y, aim.x - p.x), seed: random() * 100)
                plane.alpha = 1
                plane.bank = (random() - 0.5) * 0.02
                if kind == .eagle {
                    // In the pixel world it flies dead straight, along the grid.
                    plane.heading = [0, Float.pi, Float.pi / 2, -Float.pi / 2][edge]
                    plane.bank = 0
                }
                actors.append(plane)
                continue
            }
            for _ in 0..<8 {
                let p = SIMD2<Float>(random() * size.x, random() * size.y)
                let margin: Float = 40
                guard p.x > margin, p.y > margin, p.x < size.x - margin, p.y < size.y - margin,
                      isHome(kind, p, in: terrain) else { continue }
                var newcomer = Actor(kind: kind, pos: p, heading: random() * 2 * .pi, seed: random() * 100)
                if kind == .hero {
                    // Each of the three wanderers is someone: take whoever is not on the map.
                    let here = Set(actors.filter { $0.kind == .hero }.map { Int($0.bank) })
                    newcomer.bank = Float((0..<3).first { !here.contains($0) } ?? 0)
                }
                actors.append(newcomer)
                break
            }
        }

        for i in actors.indices {
            var actor = actors[i]
            actor.age += dt
            let home = isHome(actor.kind, actor.pos, in: terrain)
            if actor.kind == .plane || actor.kind == .dragon || actor.kind == .eagle {
                // Never fades: it flies in from outside and on out of sight,
                // and is gone once its vapour has left the view too.
                let far: Float = actor.kind == .plane ? 800 : (actor.kind == .dragon ? 260 : 120)
                let gone = actor.pos.x < -far || actor.pos.y < -far || actor.pos.x > size.x + far || actor.pos.y > size.y + far
                actor.alpha = gone ? 0 : 1
            } else {
                actor.alpha = home ? min(actor.alpha + dt * 1.2, 1) : actor.alpha - dt * 2.5
            }
            var (speed, look, turn) = actor.kind.motion

            func ahead(_ offset: Float) -> Bool {
                let a = actor.heading + offset
                return isHome(actor.kind, actor.pos + look * SIMD2<Float>(cos(a), sin(a)), in: terrain)
            }
            /// Looks ahead; if that is not home, turns toward the side that is.
            func steer(wander: Float) {
                if !ahead(0) {
                    let left = ahead(-0.9), right = ahead(0.9)
                    let side: Float = (right && !left) ? 1 : ((left && !right) ? -1 : (actor.seed > 50 ? 1 : -1))
                    actor.heading += side * turn * dt
                } else {
                    actor.heading += sin(actor.age * 0.31 + actor.seed) * wander * dt
                }
            }

            switch actor.kind.gait {
            case .cruise:
                switch actor.kind {
                case .turtle:
                    speed *= 0.6 + 0.4 * max(0, sin(actor.age * 3.2 + actor.seed))   // glides between strokes
                    steer(wander: 0.12)
                case .skater:
                    steer(wander: 0.9)                                              // long lazy curves
                case .school:
                    // A school idles, then darts: now and then it wheels onto a
                    // new course with a spurt of speed that dies away.
                    actor.timer -= dt
                    if actor.timer <= 0 {
                        actor.timer = 2.5 + random() * 6
                        actor.veer = (random() - 0.5) * 2.6
                        actor.spurt = 0.6 + random() * 0.9
                    }
                    let turning = actor.veer * min(dt * 2.2, 1)
                    actor.heading += turning
                    actor.veer -= turning
                    actor.spurt *= exp(-dt * 0.9)
                    speed *= 0.55 + 0.25 * sin(actor.age * 0.5 + actor.seed) + actor.spurt + 1.5 * alarm
                    steer(wander: 0.35)
                case .ray:
                    // Each beat of the wings carries it forward, then it glides.
                    speed *= 0.75 + 0.45 * max(0, sin(actor.age * 1.6))
                    steer(wander: 0.30)
                case .plane, .dragon, .eagle:
                    actor.heading += actor.bank * dt
                case .wisp:
                    speed *= 0.6 + 0.4 * sin(actor.age * 0.7 + actor.seed)       // drifts, lingers, drifts on
                    steer(wander: 0.9)
                default:
                    steer(wander: 0.12)
                }
            case .hop:
                actor.timer -= dt
                if actor.timer <= 0 {
                    actor.moving.toggle()
                    actor.timer = actor.moving ? 0.4 + random() * 1.2 : 1.2 + random() * 4
                    if actor.moving { actor.heading += (random() - 0.5) * 4 }
                }
                if !actor.moving { speed = 0 }
                steer(wander: 0.12)
            case .circle:
                actor.heading += turn * dt * (actor.seed > 50 ? 1 : -1)
            case .lines:
                // It rides the lines of the grid and turns only at a crossing,
                // square to its course, keeping to open floor.
                let pitch: Float = 48
                // Racers ride the lines between squares; the hero walks from the
                // middle of one tile to the middle of the next.
                let origin: Float = actor.kind == .racer ? 0 : 24
                func course(_ heading: Float) -> SIMD2<Float> { SIMD2<Float>(cos(heading).rounded(), sin(heading).rounded()) }
                if actor.timer == 0 {
                    actor.pos = ((actor.pos - origin) / pitch).rounded(.toNearestOrAwayFromZero) * pitch + origin
                    actor.heading = Float(Int(random() * 3.999)) * .pi / 2
                    actor.timer = 1
                    actor.veer = 0
                }
                // A wanderer stops now and then to look about.
                if actor.timer > 1 {
                    actor.timer = max(1, actor.timer - dt)
                    speed = 0
                    break
                }
                var left = speed * dt
                let toCrossing = pitch - actor.veer
                if left >= toCrossing {
                    actor.pos = ((actor.pos + course(actor.heading) * toCrossing - origin) / pitch).rounded(.toNearestOrAwayFromZero) * pitch + origin
                    left -= toCrossing
                    actor.veer = 0
                    func open(_ offset: Float) -> Bool {
                        let d = course(actor.heading + offset)
                        return isHome(actor.kind, actor.pos + d * pitch, in: terrain) && (actor.kind != .racer || isHome(actor.kind, actor.pos + d * pitch * 2, in: terrain))
                    }
                    if actor.kind == .hero, self.random() < 0.12 { actor.timer = 1 + 2 + self.random() * 5 }
                    let turns = [Float.pi / 2, -Float.pi / 2].filter(open)
                    if open(0), turns.isEmpty || self.random() < 0.72 {
                        // straight on
                    } else if !turns.isEmpty {
                        actor.heading += turns[Int(self.random() * Float(turns.count) * 0.999)]
                    } else if !open(0) {
                        actor.heading += .pi
                    }
                }
                actor.pos += course(actor.heading) * left
                actor.veer += left
                speed = 0
            }
            let before = actor.pos
            actor.pos += speed * dt * SIMD2<Float>(cos(actor.heading), sin(actor.heading))

            if let trail = actor.kind.trail {
                for j in actor.marks.indices { actor.marks[j].age += dt }
                if simd_distance(actor.marks.first?.pos ?? before - [trail.spacing, 0], actor.pos) >= trail.spacing {
                    actor.marks.insert(Mark(pos: actor.pos, heading: actor.heading), at: 0)
                }
                actor.marks.removeAll { $0.age > trail.life }
                if actor.marks.count > trail.count { actor.marks.removeLast(actor.marks.count - trail.count) }
            }
            if actor.kind == .school { swim(&actor, dt: dt, velocity: (actor.pos - before) / max(dt, 0.0001)) }
            actors[i] = actor
        }
        scatter = false
        actors.removeAll { $0.alpha <= 0 && $0.age > 0.5 }
    }

    /// Moves each fish of a school. Every fish makes for its own place in the
    /// moving school, a place that itself drifts about; it keeps clear of
    /// its neighbours, and bolts outward when the ground changes.
    private func swim(_ actor: inout Actor, dt: Float, velocity: SIMD2<Float>) {
        if actor.fish.isEmpty {
            for k in 0..<14 {
                let a = sin(Float(k) * 12.9898 + actor.seed) * 43758.5453, b = sin(Float(k) * 78.233 + actor.seed) * 12543.123
                let slot = SIMD2<Float>((a - floor(a) - 0.5) * 52, (b - floor(b) - 0.5) * 34)
                let c = cos(actor.heading), s = sin(actor.heading)
                let pos = actor.pos + SIMD2<Float>(slot.x * c - slot.y * s, slot.x * s + slot.y * c)
                actor.fish.append(Fish(pos: pos, vel: velocity, slot: slot, stroke: Float(k) * 1.7))
            }
        }
        let c = cos(actor.heading), s = sin(actor.heading)
        let spread = 1 + 1.6 * alarm
        for k in actor.fish.indices {
            var fish = actor.fish[k]
            let fk = Float(k)
            // its place wanders a little within the school
            let drift = SIMD2<Float>(sin(actor.age * 0.43 + fk * 2.1), cos(actor.age * 0.37 + fk * 1.3)) * 7
            let slot = (fish.slot + drift) * spread
            let place = actor.pos + SIMD2<Float>(slot.x * c - slot.y * s, slot.x * s + slot.y * c)
            var want = velocity + (place - fish.pos) * 1.1
            for (j, other) in actor.fish.enumerated() where j != k {
                let apart = fish.pos - other.pos
                let d = simd_length(apart)
                if d < 10, d > 0.01 { want += apart / d * (10 - d) * 4 }
            }
            if scatter {
                let outward = fish.pos - actor.pos
                fish.vel += simd_normalize(outward + [0.01, 0]) * (50 + 40 * random())
            }
            // some fish answer sooner than others
            fish.vel += (want - fish.vel) * min((1.6 + 1.2 * (fk.truncatingRemainder(dividingBy: 3))) * dt, 1)
            fish.pos += fish.vel * dt
            fish.stroke += dt * (4 + 0.45 * simd_length(fish.vel))
            actor.fish[k] = fish
        }
    }

    /// Runs the actors for a while so a still picture has them in place.
    func populate(size: SIMD2<Float>) {
        for _ in 0..<400 { update(dt: 0.1, size: size) }
    }

    /// The sprites to draw this frame, back to front.
    func instances(light: SIMD3<Float>, day: Daylight, palette: [SIMD4<Float>]) -> [SpriteInstance] {
        // Where a shadow lands that is `len` points long with the sun well up,
        // and how dark shadows are just now.
        func cast(_ len: Float) -> SIMD2<Float> { day.fall * len * day.reach }
        let dark = day.strength
        var sprites: [SpriteInstance] = []
        let lit = SIMD4<Float>(light, 0)
        let waterShadow = SIMD4<Float>(0.0, 0.15, 0.25, 1)
        let groundShadow = SIMD4<Float>(0.15, 0.12, 0.10, 1)
        func add(_ pos: SIMD2<Float>, _ size: SIMD2<Float>, _ cell: SIMD2<Float>, _ angle: Float, _ alpha: Float, _ tint: SIMD4<Float>) {
            sprites.append(SpriteInstance(pos: pos, size: size, cell: cell, angle: angle, alpha: alpha, tint: tint))
        }
        func add(_ pos: SIMD2<Float>, _ size: Float, _ cell: SIMD2<Float>, _ angle: Float, _ alpha: Float, _ tint: SIMD4<Float>) {
            add(pos, [size, size], cell, angle, alpha, tint)
        }
        func each(_ kind: Kind, _ body: (Actor, SIMD2<Float>) -> Void) {
            for actor in actors where actor.kind == kind {
                body(actor, SIMD2<Float>(cos(actor.heading), sin(actor.heading)))
            }
        }
        func tinted(_ r: Float, _ g: Float, _ b: Float) -> SIMD4<Float> { SIMD4<Float>(light * [r, g, b], 0) }
        func turned(_ v: SIMD2<Float>, by angle: Float) -> SIMD2<Float> {
            [v.x * cos(angle) - v.y * sin(angle), v.x * sin(angle) + v.y * cos(angle)]
        }

        // ---- Shore
        each(.turtle) { actor, _ in
            let frame = Float(Int(actor.age * 2.0 + actor.seed) % 4)
            add(actor.pos + cast(3.6), 30, [frame, 1], actor.heading, 0.16 * dark * actor.alpha, waterShadow)
            add(actor.pos, 30, [frame, 1], actor.heading, 0.9 * actor.alpha, tinted(0.78, 0.97, 1.0))
        }
        each(.boat) { actor, dir in
            let sway = 0.05 * sin(actor.age * 1.3 + actor.seed)
            add(actor.pos - dir * 47, 64, [1, 0], actor.heading, 0.8 * actor.alpha, lit)
            add(actor.pos + cast(7.2), 50, [0, 0], actor.heading + sway, 0.22 * dark * actor.alpha, waterShadow)
            add(actor.pos, 50, [0, 0], actor.heading + sway, actor.alpha, lit)
        }
        each(.crab) { actor, _ in
            let frame: Float = actor.moving ? Float(Int(actor.age * 9) % 2) : 0
            // Crabs walk sideways: the body is turned a quarter from its path.
            let facing = actor.heading + .pi / 2
            add(actor.pos + cast(1.8), 17, [frame, 2], facing, 0.25 * dark * actor.alpha, groundShadow)
            add(actor.pos, 17, [frame, 2], facing, actor.alpha, lit)
        }

        // ---- Above the clouds: everything flies, so shadows fall far away.
        each(.balloon) { actor, _ in
            let colours: [SIMD3<Float>] = [[1.0, 0.45, 0.36], [1.0, 0.80, 0.36], [0.40, 0.78, 0.85], [0.95, 0.60, 0.80]]
            let size = 34 + 12 * (actor.seed / 100)
            let turn = actor.seed + 0.15 * sin(actor.age * 0.2)
            add(actor.pos + cast(25), size, [2, 0], turn, 0.13 * dark * actor.alpha, [0.1, 0.2, 0.4, 1])
            add(actor.pos, size, [2, 0], turn, actor.alpha, SIMD4<Float>(light * colours[Int(actor.seed) % colours.count], 0))
        }
        each(.flock) { actor, _ in
            // Seven birds in a V behind their leader.
            for k in 0..<7 {
                let rank = Float((k + 1) / 2), side: Float = k % 2 == 0 ? 1 : -1
                let offset = turned([-13 * rank, 9 * rank * side], by: actor.heading)
                let frame = Float(2 + Int(actor.age * 3.5 + Float(k) * 0.4) % 2)
                add(actor.pos + offset + cast(18.6), 15, [frame, 2], actor.heading, 0.10 * dark * actor.alpha, [0.1, 0.2, 0.4, 1])
                add(actor.pos + offset, 15, [frame, 2], actor.heading, actor.alpha, lit)
            }
        }
        each(.plane) { actor, _ in
            // Twin trails of vapour along the way it came: thin and bright
            // just behind it, wider and fainter as they age.
            for mark in actor.marks.dropFirst(2) {
                let k = mark.age / 14
                let across = SIMD2<Float>(-sin(mark.heading), cos(mark.heading))
                for wing in [Float(-3.5), 3.5] {
                    add(mark.pos + across * wing * (1 + k), [13, 2.2 + 7 * k], [2, 5], mark.heading, 0.75 * (1 - k) * (1 - k), lit)
                }
            }
            // It leans into its turn.
            let lean = 1 - min(abs(actor.bank) * 6, 0.12)
            add(actor.pos + cast(28.6), [32, 32 * lean], [3, 0], actor.heading, 0.10 * dark * actor.alpha, [0.1, 0.2, 0.4, 1])
            add(actor.pos, [32, 32 * lean], [3, 0], actor.heading, actor.alpha, lit)
        }

        // ---- Frozen lake
        each(.skater) { actor, _ in
            // The lines their blades leave, fading.
            for mark in actor.marks {
                add(mark.pos, [5.5, 1.5], [2, 5], mark.heading, 0.6 * (1 - mark.age / 9) * actor.alpha, lit)
            }
            let frame = Float(Int(actor.age * 2.2 + actor.seed) % 2)
            add(actor.pos + cast(3.6), 21, [frame, 3], actor.heading, 0.25 * dark * actor.alpha, [0.1, 0.2, 0.4, 1])
            add(actor.pos, 21, [frame, 3], actor.heading, actor.alpha, lit)
        }
        each(.fox) { actor, _ in
            // Paw prints, left and right by turns.
            for (j, mark) in actor.marks.enumerated() {
                let side: Float = j % 2 == 0 ? 2.2 : -2.2
                let pos = mark.pos + turned([0, side], by: mark.heading)
                add(pos, [3.4, 2.4], [2, 5], mark.heading, 0.55 * (1 - mark.age / 30) * actor.alpha, [0.45, 0.56, 0.74, 1])
            }
            let facing = actor.heading + 0.07 * sin(actor.age * 7)
            add(actor.pos + cast(3.6), 27, [1, 4], facing, 0.22 * dark * actor.alpha, [0.1, 0.2, 0.4, 1])
            add(actor.pos, 27, [1, 4], facing, actor.alpha, lit)
        }

        // ---- Desert oasis
        each(.caravan) { actor, _ in
            // Four camels in single file, each walking the leader's path a
            // fixed distance behind it. The path is a string of marks; a
            // camel's place is found between two of them, so it moves
            // smoothly rather than from mark to mark.
            // Hoof prints along the way they came, left and right by turns,
            // fading out toward the far end.
            for (j, mark) in actor.marks.enumerated() {
                let fade = 1 - Float(j) / 80
                let side: Float = j % 2 == 0 ? 3.2 : -3.2
                let at = mark.pos + turned([0, side], by: mark.heading)
                add(at, [3.6, 2.6], [2, 5], mark.heading, 0.30 * fade * actor.alpha, SIMD4<Float>(light * [0.55, 0.38, 0.24], 1))
            }
            for k in (0..<4).reversed() {
                var pos = actor.pos
                var heading = actor.heading
                if k > 0 {
                    guard let first = actor.marks.first else { continue }
                    let behind = Float(k) * 44 - simd_distance(actor.pos, first.pos)
                    let at = max(behind, 0) / 6
                    let i = Int(at)
                    guard i + 1 < actor.marks.count else { continue }
                    let f = at - Float(i)
                    let a = actor.marks[i], b = actor.marks[i + 1]
                    pos = a.pos + (b.pos - a.pos) * f
                    var turn = b.heading - a.heading
                    turn = atan2(sin(turn), cos(turn))
                    heading = a.heading + turn * f
                }
                // A camel paces: both legs of one side together, so its body
                // rocks from side to side and yaws a little with every stride.
                let stride = actor.age * 3.7 + Float(k) * 1.3
                let along = SIMD2<Float>(cos(heading), sin(heading))
                let across = SIMD2<Float>(-sin(heading), cos(heading))
                let body = pos + across * 0.9 * sin(stride)
                let facing = heading + 0.06 * sin(stride + 0.6)

                // The shadow in profile, thrown the way every shadow here falls:
                // each part of the camel lands as far from its feet as it stands
                // high. Its four legs swing as the camel walks.
                let fall = cast(62)
                func onShadow(_ u: Float, _ v: Float) -> SIMD2<Float> {
                    pos + along * (u - 48) * (44.0 / 96) + fall * (v - 48) / 96
                }
                for (hip, phase) in [(34.0, 1.0), (39.0, -1.0), (60.0, -1.0), (65.0, 1.0)] as [(Float, Float)] {
                    let top = onShadow(hip, 68), foot = onShadow(hip + 6 * sin(stride) * phase, 48.5)
                    let leg = foot - top
                    add((top + foot) / 2, [simd_length(leg) + 1.5, 1.7], [2, 5], atan2(leg.y, leg.x), 0.32 * dark * actor.alpha, groundShadow)
                }
                sprites.append(SpriteInstance(pos: pos, size: [44, 44], cell: [1, 6], angle: heading, alpha: 0.32 * dark * actor.alpha, tint: groundShadow, fall: fall))
                add(body, 44 * (1 + 0.015 * sin(stride * 2)), [2, 4], facing, actor.alpha, lit)
            }
        }
        each(.hawk) { actor, _ in
            add(actor.pos + cast(33.6), 24, [2, 2], actor.heading, 0.15 * dark * actor.alpha, groundShadow)
            add(actor.pos, 24, [2, 2], actor.heading, actor.alpha, tinted(0.50, 0.37, 0.27))
        }

        // ---- Coral reef
        each(.ray) { actor, _ in
            let size = 46 * (1 + 0.03 * sin(actor.age * 1.6))
            add(actor.pos + cast(10), size, [3, 4], actor.heading, 0.20 * dark * actor.alpha, waterShadow)
            add(actor.pos, size, [3, 4], actor.heading, actor.alpha, tinted(0.80, 0.95, 1.0))
        }
        each(.school) { actor, _ in
            // Each fish points the way it is swimming and beats its tail
            // faster the faster it goes.
            let colour: SIMD4<Float> = actor.seed > 50 ? tinted(1.0, 0.82, 0.36) : tinted(0.55, 0.82, 1.0)
            for fish in actor.fish {
                let pace = simd_length(fish.vel)
                let heading = pace > 0.5 ? atan2(fish.vel.y, fish.vel.x) : actor.heading
                let facing = heading + min(0.10 + 0.012 * pace, 0.35) * sin(fish.stroke)
                add(fish.pos + cast(3.6), 12, [0, 5], facing, 0.14 * dark * actor.alpha, waterShadow)
                add(fish.pos, 12, [0, 5], facing, actor.alpha, colour)
            }
        }

        // ---- Neon grid: everything is light, and takes the colour of the hour.
        func shine(_ pos: SIMD2<Float>, _ size: SIMD2<Float>, _ cell: SIMD2<Float>, _ angle: Float, _ alpha: Float, _ colour: SIMD3<Float>) {
            sprites.append(SpriteInstance(pos: pos, size: size, cell: cell, angle: angle, alpha: alpha, tint: SIMD4<Float>(colour, 1), glow: [1, 0]))
        }
        func colour(_ slot: Int) -> SIMD3<Float> {
            slot < palette.count ? SIMD3<Float>(palette[slot].x, palette[slot].y, palette[slot].z) : [1, 1, 1]
        }
        each(.racer) { actor, dir in
            let own = colour(1) + (colour(2) - colour(1)) * day.night
            let rival = colour(3) + (colour(4) - colour(3)) * day.night
            let hue = actor.seed > 66 ? rival : own
            // The wall of light it draws behind it, fading toward the far end.
            for (j, mark) in actor.marks.enumerated() {
                let fade = 1 - Float(j) / 70
                shine(mark.pos, [8, 9], [2, 5], mark.heading, 0.22 * fade * actor.alpha, hue)
                shine(mark.pos, [8.5, 3], [2, 5], mark.heading, fade * actor.alpha, hue + ([1, 1, 1] - hue) * 0.45)
            }
            shine(actor.pos, [34, 34], [0, 4], 0, 0.55 * actor.alpha, hue)
            shine(actor.pos - dir * 3, [17, 6.5], [2, 5], actor.heading, actor.alpha, hue)
            shine(actor.pos - dir * 2, [11, 2.4], [2, 5], actor.heading, actor.alpha, [1, 1, 1])
        }

        // ---- The old forest: wisps of light among the trees, and now and
        // then a dragon crossing high overhead, its shadow far below it.
        each(.dragon) { actor, _ in
            // It soars, and every so often takes three slow beats.
            //
            // Each wing is a little skeleton of three bones (upper arm,
            // forearm, hand) posed in space and then looked at from above.
            // Two things move it. It is raised and lowered about the body,
            // which from above only makes it look shorter the further it is
            // from level. And it folds: the elbow goes back and the wrist
            // comes forward and in toward the body, like a Z closing, while
            // the hand trails back. The down stroke is the longer part, with
            // the wing fully open; it folds as it rises and opens again at
            // the top; and the hand is always a little behind the arm.
            let scale: Float = 170.0 / 96
            let facing = actor.heading + 0.03 * sin(actor.age * 0.7 + actor.seed)
            let along = SIMD2<Float>(cos(facing), sin(facing)), across = SIMD2<Float>(-sin(facing), cos(facing))

            func smooth(_ a: Float, _ b: Float, _ x: Float) -> Float { let k = max(0, min(1, (x - a) / (b - a))); return k * k * (3 - 2 * k) }
            let cycle = (actor.age + actor.seed).truncatingRemainder(dividingBy: 10.5)
            let effort = smooth(0, 0.5, cycle) * (1 - smooth(3.9, 4.5, cycle))        // 1 while beating, 0 gliding
            /// How high the wing is held, in radians above level, at a point in the beat.
            func raised(_ phase: Float) -> Float {
                let f = phase - floor(phase)
                let k = f < 0.6 ? f / 0.6 : 1 - (f - 0.6) / 0.4
                return (55 - 90 * (0.5 - 0.5 * cos(.pi * k))) * .pi / 180
            }
            /// How far it is folded, 0 open … 1 shut, at a point in the beat.
            func folded(_ phase: Float) -> Float {
                let f = phase - floor(phase)
                return smooth(0.48, 0.80, f) * (1 - smooth(0.84, 1.0, f))
            }
            let phase = cycle / 1.5
            let glideUp: Float = 0.10, glideFold: Float = 0.06
            let armUp = glideUp + (raised(phase) - glideUp) * effort
            let handUp = glideUp + (raised(phase - 0.08) - glideUp) * effort
            // Only a hint of folding: seen from above, more of it reads as the
            // wing swinging sideways rather than rising.
            let armFold = glideFold + (0.20 * folded(phase) - glideFold) * effort
            let handFold = glideFold + (0.20 * folded(phase - 0.06) - glideFold) * effort
            // What tells the eye, from above, that a wing has gone up or down:
            // it catches the light differently as it tilts, it comes nearer and
            // so looks a little larger, and its shadow slides away from the
            // body's shadow. Heights are in points above the body.
            let eye: Float = 260                                  // how far above the dragon we are
            let wristHigh = 20 * scale * sin(armUp), handHigh = wristHigh + 14 * scale * sin(handUp)
            let bodyHigh = 5 * effort * sin(2 * .pi * (phase - 0.2))   // it rises on the down stroke
            let rock = 0.06 * sin(actor.age * 0.53 + actor.seed)
            let surge = along * 1.6 * effort * sin(2 * .pi * (phase - 0.1))

            /// Draws the dragon, or with `shadow` its shadow on the ground far below.
            func parts(shadow: Bool) {
                let alpha = shadow ? 0.28 * dark * actor.alpha : actor.alpha
                let tint: SIMD4<Float>? = shadow ? groundShadow : nil
                /// Where something this high above the body appears.
                func lifted(_ high: Float) -> SIMD2<Float> { shadow ? cast(75 + bodyHigh + high) : .zero }
                let pos = actor.pos + surge + lifted(0)
                // The tail: links that follow one another through a slow wave.
                var joint = pos - along * 12 * scale
                for k in 0..<7 {
                    let fk = Float(k)
                    let swing = 0.22 * sin(actor.age * 1.3 - fk * 0.7) * (0.25 + fk / 7)
                    let way = facing + .pi + swing
                    let next = joint + SIMD2<Float>(cos(way), sin(way)) * 8.5
                    add((joint + next) / 2, [10.5, 6.2 - 0.6 * fk], [2, 5], way, alpha, tint ?? SIMD4<Float>(light * [0.60, 0.14, 0.11], 1))
                    joint = next
                    if k == 6 { add(joint, [9, 7], [2, 5], way + .pi / 4, alpha, tint ?? SIMD4<Float>(light * [0.34, 0.07, 0.07], 1)) }
                }
                for side in [Float(-1), 1] {
                    // A point of the wing, given as (forward, outward) in the
                    // wing's own plane, seen from above when the wing is
                    // raised by `up`.
                    func seen(_ v: SIMD2<Float>, _ up: Float) -> SIMD2<Float> {
                        (along * v.x + across * side * v.y * cos(up) * (1 + side * rock)) * scale
                    }
                    /// One piece of the wing: its joint at `joint`, turned `turn`
                    /// toward the front from where it lies in the open wing.
                    func piece(_ cell: SIMD2<Float>, _ joint: SIMD2<Float>, _ turn: Float, _ up: Float, _ high: Float) {
                        let near = shadow ? 1 : 1 + high / eye
                        let x = seen([cos(turn), -sin(turn)], up) * 96 * near, y = seen([sin(turn), cos(turn)], up) * 96 * near
                        // A wing tilted toward the sun is brighter, one tilted away darker.
                        let facingSun = cos(up) - side * sin(up) * simd_dot(across, day.fall)
                        let shade = 0.50 + 0.50 * max(0.3, min(1.5, facingSun))
                        let colour = tint ?? SIMD4<Float>(light * shade, 0)
                        sprites.append(SpriteInstance(pos: joint + lifted(high) - lifted(0), size: [simd_length(x), 1], cell: cell, angle: atan2(x.y, x.x),
                                                      alpha: alpha, tint: colour, fall: y))
                    }
                    func bone(_ length: Float, _ angle: Float) -> SIMD2<Float> { SIMD2<Float>(sin(angle), cos(angle)) * length }
                    let degrees = Float.pi / 180
                    let upperTurn = -40 * degrees * armFold, foreTurn = 35 * degrees * armFold, handTurn = -62 * degrees * handFold
                    let shoulder = pos + along * 9 * scale + across * side * 3 * scale
                    let elbowHigh = wristHigh * 0.45
                    let elbow = shoulder + seen(bone(9, -15 * degrees + upperTurn), armUp) * (shadow ? 1 : 1 + elbowHigh / eye)
                    let wrist = elbow + seen(bone(11, 30 * degrees + foreTurn), armUp) * (shadow ? 1 : 1 + wristHigh / eye)
                    piece([3, 6], shoulder, upperTurn, armUp, elbowHigh * 0.5)
                    piece([1, 5], elbow, foreTurn, armUp, (elbowHigh + wristHigh) / 2)
                    piece([0, 6], wrist, handTurn, handUp, (wristHigh + handHigh) / 2)
                }
                add(pos, 96 * scale, [2, 6], facing, alpha, tint ?? lit)
            }
            parts(shadow: true)
            parts(shadow: false)
        }
        each(.wisp) { actor, _ in
            let seen = actor.alpha * (0.30 + 0.70 * day.night)
            let hue = actor.seed > 50 ? colour(5) : SIMD3<Float>(0.80, 0.95, 0.60)
            let pulse = 0.85 + 0.15 * sin(actor.age * 2.3 + actor.seed)
            for mark in actor.marks {
                let drift = SIMD2<Float>(sin(mark.heading * 7 + mark.age * 2), cos(mark.heading * 5 + mark.age * 2)) * 4
                shine(mark.pos + drift, [5, 5], [0, 4], 0, 0.7 * (1 - mark.age / 2.5) * seen, hue)
            }
            shine(actor.pos, [36 * pulse, 36 * pulse], [0, 4], 0, 0.55 * seen, hue)
            shine(actor.pos, [10, 10], [0, 4], 0, seen, [1, 1, 1])
        }

        // ---- Pixel quest: figures stand square to the screen, face one of
        // four ways, and move a whole pixel (3 points) at a time.
        func snapped(_ p: SIMD2<Float>) -> SIMD2<Float> { (p / 3).rounded(.down) * 3 }
        each(.ship) { actor, _ in
            // A ship under sail, rising and falling a pixel on the swell.
            let swell: Float = sin(actor.age * 1.6) > 0 ? 0 : 3
            sprites.append(SpriteInstance(pos: snapped(actor.pos) + [0, swell - 6], size: [cos(actor.heading) < -0.5 ? -48 : 48, 48], cell: [0, 14], angle: 0,
                                          alpha: actor.alpha, tint: lit))
        }
        each(.hero) { actor, _ in
            // Three wanderers go their own ways: a swordsman, a sorceress and
            // an archer. Each has nine cells in the sprite sheet from row 7 on:
            // three views, three pictures of each. A tile is two steps: foot
            // forward, feet passing, other foot forward, feet passing. One
            // who has stopped stands facing us.
            let resting = actor.timer > 1
            let stride = resting ? 1 : [0, 1, 2, 1][Int(actor.veer / 48 * 4) % 4]
            let dx = cos(actor.heading).rounded(), dy = sin(actor.heading).rounded()
            let view = resting || dy > 0.5 ? 0 : (dy < -0.5 ? 2 : 1)
            let index = Int(actor.bank) * 9 + view * 3 + stride
            let cell = SIMD2<Float>(Float(index % 4), Float(7 + index / 4))
            let feet = snapped(actor.pos)
            add(feet + [0, 15], [22, 8], [2, 5], 0, 0.30 * actor.alpha, groundShadow)
            // The cell is 24 pixels square, the figure's feet two pixels from its foot.
            sprites.append(SpriteInstance(pos: feet + [0, -18], size: [!resting && dx < -0.5 ? -72 : 72, 72], cell: cell, angle: 0,
                                          alpha: actor.alpha, tint: lit))
        }
        each(.eagle) { actor, _ in
            // An eagle crossing high up, and its shadow on the land.
            let frame = Float(1 + Int(actor.age * 2.5) % 2)
            let turn = actor.heading + .pi / 2          // the picture faces up the screen
            let pos = snapped(actor.pos)
            add(pos + snapped(cast(34)), 48, [frame, 14], turn, 0.26 * dark * actor.alpha, groundShadow)
            add(pos, 48, [frame, 14], turn, actor.alpha, lit)
        }
        return sprites
    }
}
