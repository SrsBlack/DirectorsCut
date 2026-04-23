import Metal
import CoreVideo
import Editor

/// Renders transitions between two video frames using Metal compute shaders.
public final class TransitionRenderer {
    private let filterPipeline: FilterPipeline?

    public init() {
        self.filterPipeline = FilterPipeline()
    }

    /// Render a single transition frame.
    ///
    /// - Parameters:
    ///   - transition: The transition definition (type, duration)
    ///   - progress: How far through the transition we are (0.0 → 1.0)
    ///   - frameA: The outgoing clip's pixel buffer
    ///   - frameB: The incoming clip's pixel buffer
    ///   - output: Destination pixel buffer
    public func render(
        transition: Transition,
        progress: Float,
        frameA: CVPixelBuffer,
        frameB: CVPixelBuffer,
        output: CVPixelBuffer
    ) {
        guard let pipeline = filterPipeline else {
            // Fallback: simple copy of whichever frame dominates
            copyFrame(progress < 0.5 ? frameA : frameB, to: output)
            return
        }

        guard
            let texA = makeTexture(from: frameA),
            let texB = makeTexture(from: frameB),
            let texOut = makeTexture(from: output)
        else {
            copyFrame(progress < 0.5 ? frameA : frameB, to: output)
            return
        }

        let (kernelName, direction): (String, Float) = kernelName(for: transition.type)
        pipeline.applyTransition(
            type: kernelName,
            texA: texA,
            texB: texB,
            output: texOut,
            progress: progress,
            direction: direction
        )
    }

    /// How many seconds before or after the cut point the transition extends.
    /// e.g. a 1-second transition extends 0.5 s before and 0.5 s after the cut.
    public static func overlap(for transition: Transition) -> Double {
        transition.duration / 2.0
    }

    /// Given a clip's end time and a transition, compute the progress value (0→1)
    /// for a given playback time.
    public static func progress(
        for transition: Transition,
        clipEndTime: Double,
        currentTime: Double
    ) -> Float {
        let start = clipEndTime - transition.duration / 2.0
        let end   = clipEndTime + transition.duration / 2.0
        guard end > start else { return 0 }
        let t = (currentTime - start) / (end - start)
        return Float(min(max(t, 0), 1))
    }

    // MARK: - Private

    private func kernelName(for type: Transition.TransitionType) -> (name: String, direction: Float) {
        switch type {
        case .crossDissolve:            return ("crossDissolve",    0)
        case .fadeToBlack:              return ("fadeTransition",    0)
        case .fadeToWhite:              return ("fadeTransition",    1)
        case .wipeLeft:                 return ("wipeTransition",    0)
        case .wipeRight:                return ("wipeTransition",    1)
        case .wipeUp:                   return ("wipeTransition",    2)
        case .wipeDown:                 return ("wipeTransition",    3)
        case .slideLeft:                return ("wipeTransition",    0)   // same wipe shader, different look at full speed
        case .slideRight:               return ("wipeTransition",    1)
        case .zoomIn:                   return ("zoomTransition",    0)
        case .zoomOut:                  return ("zoomTransition",    1)
        }
    }

    private func makeTexture(from buffer: CVPixelBuffer) -> MTLTexture? {
        guard let device = MTLCreateSystemDefaultDevice() else { return nil }
        var cache: CVMetalTextureCache?
        CVMetalTextureCacheCreate(nil, nil, device, nil, &cache)
        guard let cache else { return nil }

        let w = CVPixelBufferGetWidth(buffer)
        let h = CVPixelBufferGetHeight(buffer)
        var metalTex: CVMetalTexture?
        CVMetalTextureCacheCreateTextureFromImage(nil, cache, buffer, nil, .bgra8Unorm, w, h, 0, &metalTex)
        guard let metalTex else { return nil }
        return CVMetalTextureGetTexture(metalTex)
    }

    private func copyFrame(_ src: CVPixelBuffer, to dst: CVPixelBuffer) {
        CVPixelBufferLockBaseAddress(src, .readOnly)
        CVPixelBufferLockBaseAddress(dst, [])
        defer {
            CVPixelBufferUnlockBaseAddress(src, .readOnly)
            CVPixelBufferUnlockBaseAddress(dst, [])
        }
        if let s = CVPixelBufferGetBaseAddress(src),
           let d = CVPixelBufferGetBaseAddress(dst) {
            let sz = min(CVPixelBufferGetDataSize(src), CVPixelBufferGetDataSize(dst))
            memcpy(d, s, sz)
        }
    }
}
