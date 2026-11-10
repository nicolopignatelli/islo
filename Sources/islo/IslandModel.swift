import Foundation
import CoreGraphics

/// One icon's patch of land. It moves toward its target and springs up or
/// down, so the coastline reshapes with a little life when icons move.
struct Blob {
    var position: CGPoint
    var target: CGPoint
    var strength: CGFloat
    var targetStrength: CGFloat
    var velocity: CGFloat = 0
    /// 0…1, fixed for the blob's life: varies the size of its land.
    var seed: CGFloat
}

/// Main-thread only.
final class IslandModel {
    static let maxBlobs = 64
    /// Shift the land down a little so it also sits under the icon's label.
    static let labelOffset: CGFloat = 10

    private(set) var blobs: [Blob] = []
    /// Places where land just rose, sank or arrived; the renderer draws a
    /// splash at each and empties the list.
    private(set) var splashes: [CGPoint] = []

    func takeSplashes() -> [CGPoint] {
        defer { splashes.removeAll() }
        return splashes
    }

    func setTargets(_ iconPositions: [CGPoint]) {
        var remaining = iconPositions.map { CGPoint(x: $0.x, y: $0.y + Self.labelOffset) }

        // Icons that did not move keep their blob.
        var unmatched: [Int] = []
        for i in blobs.indices where blobs[i].targetStrength > 0 {
            if let j = remaining.firstIndex(of: blobs[i].target) {
                remaining.remove(at: j)
            } else {
                unmatched.append(i)
            }
        }

        // Pair the blobs that lost their icon with the nearest new positions:
        // a dragged icon takes its land along.
        var pairs: [(distance: CGFloat, blob: Int, point: Int)] = []
        for i in unmatched {
            for (j, p) in remaining.enumerated() {
                pairs.append((hypot(p.x - blobs[i].target.x, p.y - blobs[i].target.y), i, j))
            }
        }
        pairs.sort { $0.distance < $1.distance }
        var usedBlobs = Set<Int>()
        var usedPoints = Set<Int>()
        for pair in pairs where !usedBlobs.contains(pair.blob) && !usedPoints.contains(pair.point) {
            blobs[pair.blob].target = remaining[pair.point]
            splashes.append(remaining[pair.point])
            usedBlobs.insert(pair.blob)
            usedPoints.insert(pair.point)
        }

        // Land with no icon left sinks; new icons raise new land.
        for i in unmatched where !usedBlobs.contains(i) {
            blobs[i].targetStrength = 0
            splashes.append(blobs[i].position)
        }
        for (j, p) in remaining.enumerated() where !usedPoints.contains(j) {
            guard blobs.count < Self.maxBlobs else { break }
            // Seeded by where it first appears, so a layout always looks the same.
            let noise = sin(p.x * 12.9898 + p.y * 78.233) * 43758.5453
            blobs.append(Blob(position: p, target: p, strength: 0, targetStrength: 1, seed: noise - floor(noise)))
            splashes.append(p)
        }
    }

    /// Advances the motion. Returns true if the land changed.
    @discardableResult
    func step(dt: CGFloat) -> Bool {
        let move = 1 - exp(-dt * 4)
        var changed = false
        for i in blobs.indices {
            let dx = blobs[i].target.x - blobs[i].position.x
            let dy = blobs[i].target.y - blobs[i].position.y
            let ds = blobs[i].targetStrength - blobs[i].strength
            if dx == 0 && dy == 0 && ds == 0 && blobs[i].velocity == 0 { continue }
            changed = true
            if abs(dx) < 0.05 && abs(dy) < 0.05 {
                blobs[i].position = blobs[i].target
            } else {
                blobs[i].position.x += dx * move
                blobs[i].position.y += dy * move
            }
            // A slightly bouncy spring: new land overshoots, then settles.
            if abs(ds) < 0.002 && abs(blobs[i].velocity) < 0.01 {
                blobs[i].strength = blobs[i].targetStrength
                blobs[i].velocity = 0
            } else {
                blobs[i].velocity += (ds * 26 - blobs[i].velocity * 6.5) * dt
                blobs[i].strength = max(blobs[i].strength + blobs[i].velocity * dt, 0)
            }
        }
        let before = blobs.count
        blobs.removeAll { $0.targetStrength == 0 && $0.strength < 0.003 }
        return changed || blobs.count != before
    }

    /// Replaces the layout at once, with no motion. Used by the review harness.
    func reset(_ iconPositions: [CGPoint]) {
        blobs.removeAll()
        setTargets(iconPositions)
        settle()
        splashes.removeAll()
    }

    func settle() {
        for _ in 0..<2000 where step(dt: 0.05) {}
    }
}
