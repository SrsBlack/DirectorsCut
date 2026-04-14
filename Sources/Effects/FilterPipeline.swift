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
