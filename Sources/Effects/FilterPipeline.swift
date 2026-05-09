import Metal
import CoreVideo

/// Manages Metal compute pipeline for applying effects to video frames.
public final class FilterPipeline {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private var computePipelines: [String: MTLComputePipelineState] = [:]

    public init?() {
        guard let device = MTLCreateSystemDefaultDevice(),
              let queue = device.makeCommandQueue() else { return nil }
        self.device = device
        self.commandQueue = queue
        loadPipelines()
    }

    private func loadPipelines() {
        guard let library = try? device.makeDefaultLibrary(bundle: .module) else { return }

        let kernelNames = [
            "colorCorrection",
            "chromaKey",
            "gaussianBlurHorizontal",
            "gaussianBlurVertical",
            "applyLUT",
            "crossDissolve",
            "wipeTransition",
            "fadeTransition",
            "zoomTransition",
            "sharpen",
            "transformFlip",
            "filmGrain",
        ]

        for name in kernelNames {
            if let function = library.makeFunction(name: name),
               let pipeline = try? device.makeComputePipelineState(function: function) {
                computePipelines[name] = pipeline
            }
        }
    }

    /// Apply color correction to a texture
    public func applyColorCorrection(
        input: MTLTexture,
        output: MTLTexture,
        brightness: Float = 0,
        contrast: Float = 1,
        saturation: Float = 1,
        temperature: Float = 6500,
        tint: Float = 0,
        exposure: Float = 0,
        highlights: Float = 0,
        shadows: Float = 0
    ) {
        guard let pipeline = computePipelines["colorCorrection"],
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeComputeCommandEncoder() else { return }

        var params = ColorParams(
            brightness: brightness,
            contrast: contrast,
            saturation: saturation,
            temperature: temperature,
            tint: tint,
            exposure: exposure,
            highlights: highlights,
            shadows: shadows
        )

        encoder.setComputePipelineState(pipeline)
        encoder.setTexture(input, index: 0)
        encoder.setTexture(output, index: 1)
        encoder.setBytes(&params, length: MemoryLayout<ColorParams>.size, index: 0)

        dispatchThreads(encoder: encoder, pipeline: pipeline, texture: output)
        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }

    /// Apply a transition between two textures
    public func applyTransition(
        type: String,
        texA: MTLTexture,
        texB: MTLTexture,
        output: MTLTexture,
        progress: Float,
        direction: Float = 0,
        softness: Float = 0.02
    ) {
        guard let pipeline = computePipelines[type],
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeComputeCommandEncoder() else { return }

        var params = TransitionParams(progress: progress, direction: direction, softness: softness)

        encoder.setComputePipelineState(pipeline)
        encoder.setTexture(texA, index: 0)
        encoder.setTexture(texB, index: 1)
        encoder.setTexture(output, index: 2)
        encoder.setBytes(&params, length: MemoryLayout<TransitionParams>.size, index: 0)

        dispatchThreads(encoder: encoder, pipeline: pipeline, texture: output)
        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }

    /// Apply chroma key (green/blue screen removal).
    public func applyChromaKey(
        input: MTLTexture,
        output: MTLTexture,
        threshold: Float = 0.4,
        smoothing: Float = 0.1
    ) {
        guard let pipeline = computePipelines["chromaKey"],
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeComputeCommandEncoder() else { return }

        var params = ChromaKeyParams(
            keyColor: SIMD3<Float>(0, 1, 0),  // green — matches prior keyColorR/G/B: 0,1,0
            threshold: threshold, smoothing: smoothing
        )

        encoder.setComputePipelineState(pipeline)
        encoder.setTexture(input, index: 0)
        encoder.setTexture(output, index: 1)
        encoder.setBytes(&params, length: MemoryLayout<ChromaKeyParams>.size, index: 0)
        dispatchThreads(encoder: encoder, pipeline: pipeline, texture: output)
        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }

    /// Apply gaussian blur.
    public func applyBlur(input: MTLTexture, output: MTLTexture, radius: Float = 10) {
        guard let hPipeline = computePipelines["gaussianBlurHorizontal"],
              let vPipeline = computePipelines["gaussianBlurVertical"],
              let commandBuffer = commandQueue.makeCommandBuffer() else { return }

        // FIX(audit-2026-05-09 #A4-gap): the vertical pass previously bound `output`
        // as BOTH texture(0) (read) and texture(1) (write). Metal validation fires in
        // debug; release behaviour is undefined. Fix: allocate an intermediate texture
        // for the horizontal pass output and feed it into the vertical pass as input.
        //
        // FIX(audit-2026-05-09 #A5-gap): Blur.metal:18 reads params.radius as sigma
        // (`float sigma = params.radius`). Passing the user-facing radius directly
        // means a radius=10 yields sigma=10 → effective sample radius=20 — double blur.
        // Fix: convert radius → sigma = radius / 3.0 (standard Gaussian convention).
        let sigma = radius / 3.0
        var params = BlurParams(radius: sigma, kernelSize: Int32(ceil(sigma * 2)))

        // Allocate scratch texture for horizontal-pass output (intermediate result).
        let desc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: output.pixelFormat,
            width: output.width, height: output.height, mipmapped: false
        )
        desc.usage = [.shaderRead, .shaderWrite]
        guard let intermediate = device.makeTexture(descriptor: desc),
              let hEncoder = commandBuffer.makeComputeCommandEncoder() else { return }

        // Horizontal pass: input → intermediate
        hEncoder.setComputePipelineState(hPipeline)
        hEncoder.setTexture(input, index: 0)
        hEncoder.setTexture(intermediate, index: 1)
        hEncoder.setBytes(&params, length: MemoryLayout<BlurParams>.size, index: 0)
        dispatchThreads(encoder: hEncoder, pipeline: hPipeline, texture: intermediate)
        hEncoder.endEncoding()

        guard let vEncoder = commandBuffer.makeComputeCommandEncoder() else { return }

        // Vertical pass: intermediate → output (distinct textures — no aliasing)
        vEncoder.setComputePipelineState(vPipeline)
        vEncoder.setTexture(intermediate, index: 0)
        vEncoder.setTexture(output, index: 1)
        vEncoder.setBytes(&params, length: MemoryLayout<BlurParams>.size, index: 0)
        dispatchThreads(encoder: vEncoder, pipeline: vPipeline, texture: output)
        vEncoder.endEncoding()

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }

    /// Apply vignette effect.
    public func applyVignette(
        input: MTLTexture,
        output: MTLTexture,
        intensity: Float = 0.5,
        radius: Float = 0.8
    ) {
        // Implemented via the color correction kernel (darken edges).
        // For a true vignette we would add a dedicated kernel, but this
        // approximation works by reducing brightness + contrast at edges.
        guard let pipeline = computePipelines["colorCorrection"],
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeComputeCommandEncoder() else { return }

        var params = ColorParams(
            brightness: -intensity * 0.3,
            contrast: 1.0 + intensity * 0.2,
            saturation: 1, temperature: 6500, tint: 0,
            exposure: 0, highlights: 0, shadows: -intensity * 0.5
        )

        encoder.setComputePipelineState(pipeline)
        encoder.setTexture(input, index: 0)
        encoder.setTexture(output, index: 1)
        encoder.setBytes(&params, length: MemoryLayout<ColorParams>.size, index: 0)
        dispatchThreads(encoder: encoder, pipeline: pipeline, texture: output)
        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }

    /// Apply sharpen effect.
    public func applySharpen(input: MTLTexture, output: MTLTexture, amount: Float = 0.5) {
        // Approximated by boosting contrast on a slight negative blur.
        guard let pipeline = computePipelines["colorCorrection"],
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeComputeCommandEncoder() else { return }

        var params = ColorParams(
            brightness: 0,
            contrast: 1.0 + amount * 0.5,
            saturation: 1, temperature: 6500, tint: 0,
            exposure: 0, highlights: amount * 0.2, shadows: 0
        )

        encoder.setComputePipelineState(pipeline)
        encoder.setTexture(input, index: 0)
        encoder.setTexture(output, index: 1)
        encoder.setBytes(&params, length: MemoryLayout<ColorParams>.size, index: 0)
        dispatchThreads(encoder: encoder, pipeline: pipeline, texture: output)
        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }

    private func dispatchThreads(encoder: MTLComputeCommandEncoder, pipeline: MTLComputePipelineState, texture: MTLTexture) {
        let threadGroupSize = MTLSize(width: 16, height: 16, depth: 1)
        let threadGroups = MTLSize(
            width: (texture.width + threadGroupSize.width - 1) / threadGroupSize.width,
            height: (texture.height + threadGroupSize.height - 1) / threadGroupSize.height,
            depth: 1
        )
        encoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
    }
}

// MARK: - C-compatible structs matching the Metal shaders

struct ColorParams {
    var brightness: Float
    var contrast: Float
    var saturation: Float
    var temperature: Float
    var tint: Float
    var exposure: Float
    var highlights: Float
    var shadows: Float
}

struct TransitionParams {
    var progress: Float
    var direction: Float
    var softness: Float
}

// FIX(audit-2026-05-09 #A3-gap): Metal's float3 is 16-byte aligned with 16 bytes of storage
// (12 bytes data + 4 bytes implicit padding). The previous struct used three separate Floats
// (12 bytes, 4-byte aligned) so the bytes were mis-mapped: threshold landed in keyColor.w
// (discarded), smoothing shifted into threshold, and smoothing read garbage.
// Fix: use SIMD3<Float> (which Swift aligns to 16 bytes) + explicit _pad to match Metal layout.
struct ChromaKeyParams {
    var keyColor: SIMD3<Float>   // 12 bytes data, 4 bytes implicit SIMD alignment padding → 16 bytes
    var _pad: Float = 0          // explicit pad to reach 16-byte boundary before threshold
    var threshold: Float         // offset 16
    var smoothing: Float         // offset 20
}

struct BlurParams {
    var radius: Float
    var kernelSize: Int32
}
