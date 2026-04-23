import AVFoundation
import Metal
import CoreVideo
import Effects

/// Custom AVVideoCompositing implementation that uses Metal for GPU-accelerated
/// frame compositing, effects, and transitions.
///
/// AVFoundation calls `startRequest(_:)` once per output frame.  We:
///
///   1. Acquire the source pixel buffer for the current track
///   2. Read the per-clip effects from the request's
///      `DCCompositionInstruction` (built by `CompositionBuilder`)
///   3. Run each enabled effect through `FilterPipeline`, ping-ponging
///      between two scratch textures
///   4. Write the final result to the output pixel buffer
public final class MetalCompositor: NSObject, AVVideoCompositing {
    private var device: MTLDevice?
    private var commandQueue: MTLCommandQueue?
    private var textureCache: CVMetalTextureCache?
    private var filterPipeline: FilterPipeline?

    /// Two reusable scratch textures for ping-pong rendering.
    private var scratchA: MTLTexture?
    private var scratchB: MTLTexture?

    // MARK: - AVVideoCompositing required properties

    public var sourcePixelBufferAttributes: [String: Any]? {
        [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferMetalCompatibilityKey as String: true,
        ]
    }

    public var requiredPixelBufferAttributesForRenderContext: [String: Any] {
        [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferMetalCompatibilityKey as String: true,
        ]
    }

    public var supportsWideColorSourceFrames: Bool { true }
    public var supportsHDRSourceFrames: Bool { true }

    // MARK: - Init

    override public init() {
        super.init()
        setupMetal()
    }

    private func setupMetal() {
        guard let device = MTLCreateSystemDefaultDevice() else { return }
        self.device = device
        self.commandQueue = device.makeCommandQueue()

        var cache: CVMetalTextureCache?
        CVMetalTextureCacheCreate(nil, nil, device, nil, &cache)
        self.textureCache = cache

        // Effects' FilterPipeline owns the .metal shaders bundled with the
        // Effects target — it will load them via Bundle.module on its side.
        self.filterPipeline = FilterPipeline()
    }

    // MARK: - AVVideoCompositing

    public func renderContextChanged(_ newRenderContext: AVVideoCompositionRenderContext) {
        // Re-create scratch textures sized for the new render context.
        guard let device else { return }
        let size = newRenderContext.size
        scratchA = makeScratch(device: device, width: Int(size.width), height: Int(size.height))
        scratchB = makeScratch(device: device, width: Int(size.width), height: Int(size.height))
    }

    public func startRequest(_ request: AVAsynchronousVideoCompositionRequest) {
        autoreleasepool {
            guard let device, let textureCache else {
                request.finishCancelledRequest()
                return
            }

            // Allocate destination pixel buffer.
            guard let outputBuffer = request.renderContext.newPixelBuffer() else {
                request.finishCancelledRequest()
                return
            }

            // Find the active source frame using the instruction (preferred)
            // or fall back to the first source track.
            let instruction = request.videoCompositionInstruction as? DCCompositionInstruction
            let trackID = instruction?.primaryTrackID
                ?? request.sourceTrackIDs.first?.int32Value
                ?? kCMPersistentTrackID_Invalid

            guard trackID != kCMPersistentTrackID_Invalid,
                  let sourceBuffer = request.sourceFrame(byTrackID: trackID) else {
                fillBlack(outputBuffer)
                request.finish(withComposedVideoFrame: outputBuffer)
                return
            }

            // Build textures from buffers.
            guard let sourceTex = makeTexture(from: sourceBuffer, cache: textureCache, device: device, write: false),
                  let outputTex = makeTexture(from: outputBuffer, cache: textureCache, device: device, write: true)
            else {
                copyPixelBuffer(from: sourceBuffer, to: outputBuffer)
                request.finish(withComposedVideoFrame: outputBuffer)
                return
            }

            // No effects → straight copy.
            let effects = instruction?.effects ?? []
            if effects.isEmpty || filterPipeline == nil {
                copyPixelBuffer(from: sourceBuffer, to: outputBuffer)
                request.finish(withComposedVideoFrame: outputBuffer)
                return
            }

            // Apply the effect chain.  Read from sourceTex into scratchA,
            // then ping-pong A↔B for each subsequent effect, finally write
            // to outputTex.
            applyEffectChain(
                effects: effects,
                input: sourceTex,
                output: outputTex
            )

            request.finish(withComposedVideoFrame: outputBuffer)
        }
    }

    public func cancelAllPendingVideoCompositionRequests() {
        // No queued state to cancel — each request is processed synchronously.
    }

    // MARK: - Effect chain dispatch

    /// Applies a list of effects from `input` → `output`, using `scratchA`/`scratchB`
    /// to ping-pong intermediate results when there's more than one effect.
    private func applyEffectChain(
        effects: [Effect],
        input: MTLTexture,
        output: MTLTexture
    ) {
        guard let pipeline = filterPipeline else { return }
        guard let scratchA, let scratchB else {
            // No scratch yet → only safe to apply the first effect direct to output.
            if let first = effects.first {
                dispatch(pipeline: pipeline, effect: first, input: input, output: output)
            }
            return
        }

        var current: MTLTexture = input
        var nextScratch = scratchA
        var otherScratch = scratchB

        for (i, effect) in effects.enumerated() {
            let isLast = (i == effects.count - 1)
            let dst: MTLTexture = isLast ? output : nextScratch

            dispatch(pipeline: pipeline, effect: effect, input: current, output: dst)

            current = dst
            // swap scratches
            (nextScratch, otherScratch) = (otherScratch, nextScratch)
        }
    }

    /// Dispatch a single effect via the FilterPipeline.
    private func dispatch(pipeline: FilterPipeline, effect: Effect, input: MTLTexture, output: MTLTexture) {
        switch effect.type {
        case .colorCorrection, .colorGrading:
            pipeline.applyColorCorrection(
                input: input,
                output: output,
                brightness:  effect.parameters["brightness"]?.floatValue  ?? 0,
                contrast:    effect.parameters["contrast"]?.floatValue    ?? 1,
                saturation:  effect.parameters["saturation"]?.floatValue  ?? 1,
                temperature: effect.parameters["temperature"]?.floatValue ?? 6500,
                tint:        effect.parameters["tint"]?.floatValue        ?? 0,
                exposure:    effect.parameters["exposure"]?.floatValue    ?? 0,
                highlights:  effect.parameters["highlights"]?.floatValue  ?? 0,
                shadows:     effect.parameters["shadows"]?.floatValue     ?? 0
            )

        case .gaussianBlur, .motionBlur:
            pipeline.applyBlur(
                input: input,
                output: output,
                radius: effect.parameters["radius"]?.floatValue ?? 10
            )

        case .chromaKey:
            pipeline.applyChromaKey(
                input: input,
                output: output,
                threshold: effect.parameters["threshold"]?.floatValue ?? 0.4,
                smoothing: effect.parameters["smoothing"]?.floatValue ?? 0.1
            )

        case .vignette:
            pipeline.applyVignette(
                input: input,
                output: output,
                intensity: effect.parameters["intensity"]?.floatValue ?? 0.5,
                radius: effect.parameters["radius"]?.floatValue ?? 0.8
            )

        case .saturation:
            pipeline.applyColorCorrection(
                input: input, output: output,
                saturation: effect.parameters["saturation"]?.floatValue ?? 1
            )

        case .temperature:
            pipeline.applyColorCorrection(
                input: input, output: output,
                temperature: effect.parameters["temperature"]?.floatValue ?? 6500
            )

        case .sharpen:
            pipeline.applySharpen(
                input: input,
                output: output,
                amount: effect.parameters["amount"]?.floatValue ?? 0.5
            )

        case .flip, .mirror, .crop, .filmGrain, .lut:
            blitCopy(input: input, output: output)
        }
    }

    // MARK: - Helpers

    private func makeTexture(
        from pixelBuffer: CVPixelBuffer,
        cache: CVMetalTextureCache,
        device: MTLDevice,
        write: Bool
    ) -> MTLTexture? {
        let w = CVPixelBufferGetWidth(pixelBuffer)
        let h = CVPixelBufferGetHeight(pixelBuffer)
        var metalTex: CVMetalTexture?
        let status = CVMetalTextureCacheCreateTextureFromImage(
            nil, cache, pixelBuffer, nil,
            .bgra8Unorm, w, h, 0, &metalTex
        )
        guard status == kCVReturnSuccess, let metalTex else { return nil }
        return CVMetalTextureGetTexture(metalTex)
    }

    private func makeScratch(device: MTLDevice, width: Int, height: Int) -> MTLTexture? {
        let desc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        desc.usage = [.shaderRead, .shaderWrite]
        return device.makeTexture(descriptor: desc)
    }

    private func blitCopy(input: MTLTexture, output: MTLTexture) {
        guard let device, let queue = commandQueue,
              let cmd = queue.makeCommandBuffer(),
              let blit = cmd.makeBlitCommandEncoder() else { return }
        _ = device // silence unused-warning when device captured but not used directly
        let size = MTLSize(width: min(input.width, output.width),
                           height: min(input.height, output.height),
                           depth: 1)
        blit.copy(
            from: input,  sourceSlice: 0, sourceLevel: 0,
            sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
            sourceSize: size,
            to: output, destinationSlice: 0, destinationLevel: 0,
            destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0)
        )
        blit.endEncoding()
        cmd.commit()
        cmd.waitUntilCompleted()
    }

    private func fillBlack(_ buffer: CVPixelBuffer) {
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        if let base = CVPixelBufferGetBaseAddress(buffer) {
            let size = CVPixelBufferGetDataSize(buffer)
            memset(base, 0, size)
        }
    }

    private func copyPixelBuffer(from source: CVPixelBuffer, to dest: CVPixelBuffer) {
        CVPixelBufferLockBaseAddress(source, .readOnly)
        CVPixelBufferLockBaseAddress(dest, [])
        defer {
            CVPixelBufferUnlockBaseAddress(source, .readOnly)
            CVPixelBufferUnlockBaseAddress(dest, [])
        }
        if let s = CVPixelBufferGetBaseAddress(source),
           let d = CVPixelBufferGetBaseAddress(dest) {
            let size = min(CVPixelBufferGetDataSize(source), CVPixelBufferGetDataSize(dest))
            memcpy(d, s, size)
        }
    }
}
