import MetalKit
import Accelerate
import simd

/// Runs the pipeline described in ShaderCommon.swift.
final class Renderer: NSObject, MTKViewDelegate {
    private let device: MTLDevice
    private let model: IslandModel
    private let actors = ActorSystem()
    private let queue: MTLCommandQueue
    private let dataPipeline: MTLRenderPipelineState
    // One ground and one scene pipeline per landscape, indexed by its number.
    private let groundPipelines: [MTLRenderPipelineState]
    private let scenePipelines: [MTLRenderPipelineState]
    private let spritePipeline: MTLRenderPipelineState
    private let sampler: MTLSamplerState
    private let uniforms: MTLBuffer
    private let sprites: MTLBuffer
    private let atlas: MTLTexture
    private let glyphs: MTLTexture
    private let tiles: MTLTexture
    private static let maxSprites = 512

    // Rebuilt when the size changes.
    private var data: MTLTexture?     // height, nearness of land, clear-of-icons
    private var ground: MTLTexture?   // the dry sand
    private var pointSize: CGSize = .zero
    private var pixelSize: CGSize = .zero

    private var terrainChanged = true
    /// The light of this moment, and the light the ground was last drawn in.
    private var day = Daylight.now
    private var groundLight = SIMD3<Float>(repeating: 0)
    /// The actors need a fresh copy of the terrain once it has stopped moving.
    private var terrainCopyDue = false
    private var lastTerrainCommands: MTLCommandBuffer?
    private var rings: [SIMD4<Float>] = []
    private let start = CACurrentMediaTime()
    private var lastFrame = CACurrentMediaTime()

    var theme: Theme {
        didSet {
            guard theme != oldValue else { return }
            terrainChanged = true
            actors.landscape = theme.spec.landscape
        }
    }

    // Must match `Uniforms` in ShaderCommon.swift: 8 scalars, 8 colours, 8 rings, the light, the icons.
    private static let headerFloats = 8 + 8 * 4 + 8 * 4 + 2 * 4
    private static let bufferSize = (headerFloats + IslandModel.maxBlobs * 4) * MemoryLayout<Float>.stride

    init?(device: MTLDevice, model: IslandModel, theme: Theme) {
        self.device = device
        self.model = model
        self.theme = theme

        let samplerDescriptor = MTLSamplerDescriptor()
        samplerDescriptor.minFilter = .linear
        samplerDescriptor.magFilter = .linear
        samplerDescriptor.mipFilter = .linear
        samplerDescriptor.sAddressMode = .clampToEdge
        samplerDescriptor.tAddressMode = .clampToEdge

        guard let queue = device.makeCommandQueue(),
              let uniforms = device.makeBuffer(length: Self.bufferSize, options: .storageModeShared),
              let sprites = device.makeBuffer(length: Self.maxSprites * MemoryLayout<SpriteInstance>.stride, options: .storageModeShared),
              let sampler = device.makeSamplerState(descriptor: samplerDescriptor),
              let sheet = Atlas.draw(),
              let atlas = try? MTKTextureLoader(device: device).newTexture(cgImage: sheet, options: [.generateMipmaps: true, .SRGB: false]),
              let letters = Glyphs.draw(),
              let glyphs = try? MTKTextureLoader(device: device).newTexture(cgImage: letters, options: [.SRGB: false]),
              let tileSheet = PixelArt.sheet(),
              let tiles = try? MTKTextureLoader(device: device).newTexture(cgImage: tileSheet, options: [.SRGB: false])
        else { return nil }
        self.queue = queue
        self.uniforms = uniforms
        self.sprites = sprites
        self.sampler = sampler
        self.atlas = atlas
        self.glyphs = glyphs
        self.tiles = tiles

        do {
            let library = try device.makeLibrary(source: shaderSource, options: nil)
            func pipeline(_ vertex: String, _ fragment: String, _ format: MTLPixelFormat, blend: Bool = false) throws -> MTLRenderPipelineState {
                let descriptor = MTLRenderPipelineDescriptor()
                descriptor.vertexFunction = library.makeFunction(name: vertex)
                descriptor.fragmentFunction = library.makeFunction(name: fragment)
                let attachment = descriptor.colorAttachments[0]!
                attachment.pixelFormat = format
                if blend {
                    // The atlas is premultiplied.
                    attachment.isBlendingEnabled = true
                    attachment.sourceRGBBlendFactor = .one
                    attachment.destinationRGBBlendFactor = .oneMinusSourceAlpha
                    attachment.sourceAlphaBlendFactor = .one
                    attachment.destinationAlphaBlendFactor = .oneMinusSourceAlpha
                }
                return try device.makeRenderPipelineState(descriptor: descriptor)
            }
            dataPipeline = try pipeline("fullScreenVertex", "dataFragment", .rgba16Float)
            groundPipelines = try Landscape.allCases.map { try pipeline("fullScreenVertex", $0.groundFunction, .bgra8Unorm) }
            scenePipelines = try Landscape.allCases.map { try pipeline("fullScreenVertex", $0.sceneFunction, .bgra8Unorm) }
            spritePipeline = try pipeline("spriteVertex", "spriteFragment", .bgra8Unorm, blend: true)
        } catch {
            FileHandle.standardError.write("islo: shader error: \(error)\n".data(using: .utf8)!)
            return nil
        }
        super.init()
        actors.landscape = theme.spec.landscape
    }

    // MARK: Drawing

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        let now = CACurrentMediaTime()
        // After a pause, do not jump the animation forward.
        let dt = min(now - lastFrame, 0.1)
        lastFrame = now
        let time = now - start
        let moving = model.step(dt: CGFloat(dt))
        if moving { terrainChanged = true }
        for point in model.takeSplashes() {
            rings.append([Float(point.x), Float(point.y), Float(time), 1])
            actors.startle()
        }
        rings.removeAll { Float(time) - $0.z > 3 }
        if rings.count > 8 { rings.removeFirst(rings.count - 8) }

        let points = view.bounds.size
        guard points.width >= 1, points.height >= 1,
              let drawable = view.currentDrawable,
              let pass = view.currentRenderPassDescriptor,
              let commands = queue.makeCommandBuffer() else { return }
        prepareTargets(points: points, pixels: view.drawableSize)

        // Once the land is still and drawn, let the actors see it.
        if terrainCopyDue, !moving, !terrainChanged, lastTerrainCommands?.status == .completed {
            copyTerrain()
        }
        actors.update(dt: Float(dt), size: [Float(points.width), Float(points.height)])

        writeUniforms(time: time)
        if terrainChanged {
            encodeTerrain(commands)
            lastTerrainCommands = commands
            terrainCopyDue = true
        } else if simd_distance(shadowNow, groundLight) > 0.006 {
            // The sun has moved on: the shadows on the ground need redrawing.
            encodeGround(commands)
        }
        encodeScene(commands, into: pass)
        commands.present(drawable)
        commands.commit()
    }

    /// Renders one settled frame offscreen, with the actors in place.
    func renderImage(pointSize: CGSize, scale: CGFloat, time: CFTimeInterval = 12) -> CGImage? {
        model.settle()
        _ = model.takeSplashes()
        rings.removeAll()
        let width = Int(pointSize.width * scale), height = Int(pointSize.height * scale)
        prepareTargets(points: pointSize, pixels: CGSize(width: width, height: height))
        guard let texture = makeTexture(.bgra8Unorm, width, height),
              let first = queue.makeCommandBuffer() else { return nil }
        writeUniforms(time: time)
        encodeTerrain(first)
        first.commit()
        first.waitUntilCompleted()
        copyTerrain()
        actors.reset()
        actors.populate(size: [Float(pointSize.width), Float(pointSize.height)])

        guard let second = queue.makeCommandBuffer() else { return nil }
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = texture
        pass.colorAttachments[0].loadAction = .dontCare
        pass.colorAttachments[0].storeAction = .store
        encodeScene(second, into: pass)
        second.commit()
        second.waitUntilCompleted()

        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        texture.getBytes(&bytes, bytesPerRow: width * 4, from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0)
        let info = CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.noneSkipFirst.rawValue
        let context = CGContext(data: &bytes, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: info)
        return context?.makeImage()
    }

    private func makeTexture(_ format: MTLPixelFormat, _ width: Int, _ height: Int) -> MTLTexture? {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: format, width: max(width, 1), height: max(height, 1), mipmapped: false)
        descriptor.usage = [.renderTarget, .shaderRead]
        descriptor.storageMode = .shared
        return device.makeTexture(descriptor: descriptor)
    }

    private func prepareTargets(points: CGSize, pixels: CGSize) {
        guard points != pointSize || pixels != pixelSize else { return }
        pointSize = points
        pixelSize = pixels
        data = makeTexture(.rgba16Float, Int(points.width), Int(points.height))
        ground = makeTexture(.bgra8Unorm, Int(pixels.width), Int(pixels.height))
        terrainChanged = true
        actors.terrain = nil
    }

    /// Reads the data texture back so the actors can steer by it.
    private func copyTerrain() {
        terrainCopyDue = false
        guard let data else { return }
        let width = data.width, height = data.height, count = width * height * 4
        var halves = [UInt16](repeating: 0, count: count)
        data.getBytes(&halves, bytesPerRow: width * 8, from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0)
        var floats = [Float](repeating: 0, count: count)
        halves.withUnsafeMutableBytes { source in
            floats.withUnsafeMutableBytes { destination in
                var from = vImage_Buffer(data: source.baseAddress, height: 1, width: vImagePixelCount(count), rowBytes: count * 2)
                var to = vImage_Buffer(data: destination.baseAddress, height: 1, width: vImagePixelCount(count), rowBytes: count * 4)
                vImageConvert_Planar16FtoPlanarF(&from, &to, 0)
            }
        }
        // Every second sample is plenty to steer by.
        let w = width / 2, h = height / 2
        var terrain = Terrain(width: w, height: h, step: 2,
                              level: [Float](repeating: 0, count: w * h), clear: [Float](repeating: 0, count: w * h))
        for y in 0..<h {
            for x in 0..<w {
                let source = (y * 2 * width + x * 2) * 4
                terrain.level[y * w + x] = floats[source]
                terrain.clear[y * w + x] = floats[source + 2]
            }
        }
        if theme.spec.landscape == .pixel, let ground {
            // The pixel world is walked a tile at a time: ask the painted
            // ground, at the middle and toward the corners of each tile,
            // whether all of it can be walked on, or all of it sailed.
            let pitch = 48, scale = Int((pixelSize.width / max(pointSize.width, 1)).rounded())
            let columns = width / pitch + 1, rows = height / pitch + 1
            var walk = [Bool](repeating: false, count: columns * rows), sail = walk
            var pixel = [UInt8](repeating: 0, count: 4)
            for row in 0..<rows {
                for column in 0..<columns {
                    var walkable = true, sailable = true
                    for (dx, dy) in [(24, 24), (10, 10), (38, 10), (10, 38), (38, 38)] {
                        let x = (column * pitch + dx) * scale, y = (row * pitch + dy) * scale
                        guard x < ground.width, y < ground.height else { walkable = false; sailable = false; continue }
                        ground.getBytes(&pixel, bytesPerRow: 4, from: MTLRegionMake2D(x, y, 1, 1), mipmapLevel: 0)
                        if !(pixel[3] > 38 && pixel[3] < 90) { walkable = false }
                        if pixel[3] < 230 { sailable = false }
                    }
                    walk[row * columns + column] = walkable
                    sail[row * columns + column] = sailable
                }
            }
            terrain.walk = walk
            terrain.sail = sail
            terrain.walkColumns = columns
        }
        actors.terrain = terrain
    }

    private func writeUniforms(time: CFTimeInterval) {
        let spec = theme.spec
        let blobs = model.blobs
        day = Daylight.now
        var values: [Float] = [
            Float(pointSize.width), Float(pointSize.height),
            Float(time), Float(pixelSize.width / pointSize.width),
            0, 0 /* count and landscape, written below as integers */, day.night, 0,
        ]
        func add(_ v: SIMD4<Float>) { values += [v.x, v.y, v.z, v.w] }
        for i in 0..<8 { add(i < spec.colors.count ? spec.colors[i] : SIMD4<Float>(repeating: 0)) }
        for i in 0..<8 { add(i < rings.count ? rings[i] : SIMD4<Float>(repeating: 0)) }
        // Landscapes that make their own light are not tinted by the hour.
        let tint: SIMD4<Float> = spec.landscape.selfLit ? [1, 1, 1, 0] : SIMD4<Float>(day.colour, day.fade)
        values += [day.fall.x, day.fall.y, day.reach, day.strength, tint.x, tint.y, tint.z, tint.w]
        assert(values.count == Self.headerFloats)
        for blob in blobs {
            values += [Float(blob.position.x), Float(blob.position.y), Float(blob.strength), Float(blob.seed)]
        }
        let pointer = uniforms.contents()
        values.withUnsafeBytes { pointer.copyMemory(from: $0.baseAddress!, byteCount: $0.count) }
        pointer.storeBytes(of: Int32(blobs.count), toByteOffset: 16, as: Int32.self)
        pointer.storeBytes(of: spec.landscape.rawValue, toByteOffset: 20, as: Int32.self)
    }

    private func fullScreen(_ commands: MTLCommandBuffer, _ pipeline: MTLRenderPipelineState, into texture: MTLTexture, _ textures: [MTLTexture]) {
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = texture
        pass.colorAttachments[0].loadAction = .dontCare
        pass.colorAttachments[0].storeAction = .store
        guard let encoder = commands.makeRenderCommandEncoder(descriptor: pass) else { return }
        encoder.setRenderPipelineState(pipeline)
        encoder.setFragmentBuffer(uniforms, offset: 0, index: 0)
        encoder.setFragmentSamplerState(sampler, index: 0)
        for (i, texture) in textures.enumerated() { encoder.setFragmentTexture(texture, index: i) }
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()
    }

    /// Steps 1 and 2: the terrain data and the dry ground.
    private func encodeTerrain(_ commands: MTLCommandBuffer) {
        guard let data, ground != nil else { return }
        terrainChanged = false
        fullScreen(commands, dataPipeline, into: data, [])
        encodeGround(commands)
    }

    /// Shadows as they fall just now: where a unit one lands, and how dark it is.
    private var shadowNow: SIMD3<Float> { SIMD3<Float>(day.fall * day.reach, day.strength) }

    private func encodeGround(_ commands: MTLCommandBuffer) {
        guard let data, let ground else { return }
        groundLight = shadowNow
        fullScreen(commands, groundPipelines[Int(theme.spec.landscape.rawValue)], into: ground, [data, tiles])
    }

    /// Steps 3 and 4: the scene, then the actors.
    private func encodeScene(_ commands: MTLCommandBuffer, into pass: MTLRenderPassDescriptor) {
        guard let data, let ground, let encoder = commands.makeRenderCommandEncoder(descriptor: pass) else { return }
        encoder.setRenderPipelineState(scenePipelines[Int(theme.spec.landscape.rawValue)])
        encoder.setFragmentBuffer(uniforms, offset: 0, index: 0)
        encoder.setFragmentSamplerState(sampler, index: 0)
        encoder.setFragmentTexture(ground, index: 0)
        encoder.setFragmentTexture(data, index: 1)
        encoder.setFragmentTexture(glyphs, index: 2)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)

        let instances = Array(actors.instances(light: theme.spec.actorTint, day: day, palette: theme.spec.colors).prefix(Self.maxSprites))
        if !instances.isEmpty {
            instances.withUnsafeBytes { sprites.contents().copyMemory(from: $0.baseAddress!, byteCount: $0.count) }
            encoder.setRenderPipelineState(spritePipeline)
            encoder.setVertexBuffer(uniforms, offset: 0, index: 0)
            encoder.setVertexBuffer(sprites, offset: 0, index: 1)
            encoder.setFragmentTexture(atlas, index: 0)
            encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4, instanceCount: instances.count)
        }
        encoder.endEncoding()
    }
}
