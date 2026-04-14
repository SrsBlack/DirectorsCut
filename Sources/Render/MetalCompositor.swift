import AVFoundation
import Metal
import CoreVideo

/// Custom AVVideoCompositing implementation that uses Metal for GPU-accelerated
/// frame compositing, effects, and transitions.
public final class MetalCompositor: NSObject, AVVideoCompositing {
    private var device: MTLDevice?
    private var commandQueue: MTLCommandQueue?
    private var textureCache: CVMetalTextureCache?
    private var pipelineState: MTLRenderPipelineState?

    // MARK: - AVVideoCompositing Required Properties

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

    // MARK: - Initialization

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

        setupPipeline(device: device)
    }

    private func setupPipeline(device: MTLDevice) {
        // Load the default shader library
        guard let library = try? device.makeDefaultLibrary(bundle: .module) else {
            // Fallback: try to create a simple passthrough shader inline
            let shaderSource = """
            #include <metal_stdlib>
            using namespace metal;

            struct VertexOut {
                float4 position [[position]];
                float2 texCoord;
            };

            vertex VertexOut compositeVertex(uint vid [[vertex_id]]) {
                float2 positions[] = {
                    float2(-1, -1), float2(1, -1), float2(-1, 1),
                    float2(-1, 1), float2(1, -1), float2(1, 1)
                };
                float2 texCoords[] = {
                    float2(0, 1), float2(1, 1), float2(0, 0),
                    float2(0, 0), float2(1, 1), float2(1, 0)
                };
                VertexOut out;
                out.position = float4(positions[vid], 0, 1);
                out.texCoord = texCoords[vid];
                return out;
            }

            fragment float4 compositeFragment(VertexOut in [[stage_in]],
                                              texture2d<float> tex [[texture(0)]]) {
                constexpr sampler s(mag_filter::linear, min_filter::linear);
                return tex.sample(s, in.texCoord);
            }
            """
            guard let library = try? device.makeLibrary(source: shaderSource, options: nil) else { return }
            createPipelineState(device: device, library: library)
            return
        }
        createPipelineState(device: device, library: library)
    }

    private func createPipelineState(device: MTLDevice, library: MTLLibrary) {
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name: "compositeVertex")
        descriptor.fragmentFunction = library.makeFunction(name: "compositeFragment")
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        self.pipelineState = try? device.makeRenderPipelineState(descriptor: descriptor)
    }

    // MARK: - AVVideoCompositing

    public func renderContextChanged(_ newRenderContext: AVVideoCompositionRenderContext) {
        // Re-setup if render size changes
    }

    public func startRequest(_ request: AVAsynchronousVideoCompositionRequest) {
        autoreleasepool {
            guard let device, let commandQueue else {
                request.finishCancelledRequest()
                return
            }

            // Get the output pixel buffer
            guard let outputBuffer = request.renderContext.newPixelBuffer() else {
                request.finishCancelledRequest()
                return
            }

            // Get source frames
            let sourceTrackIDs = request.sourceTrackIDs
            guard let firstTrackID = sourceTrackIDs.first,
                  let sourceBuffer = request.sourceFrame(byTrackID: firstTrackID.int32Value) else {
                // No source frames - fill with black
                fillBlack(outputBuffer)
                request.finish(withComposedVideoFrame: outputBuffer)
                return
            }

            // For now, simple passthrough of the first video track
            // TODO: Apply effects, blend multiple tracks, handle transitions
            if let pipelineState, let textureCache {
                renderWithMetal(
                    source: sourceBuffer,
                    output: outputBuffer,
                    device: device,
                    commandQueue: commandQueue,
                    pipelineState: pipelineState,
                    textureCache: textureCache
                )
            } else {
                copyPixelBuffer(from: sourceBuffer, to: outputBuffer)
            }

            request.finish(withComposedVideoFrame: outputBuffer)
        }
    }

    public func cancelAllPendingVideoCompositionRequests() {
        // Cancel in-flight work
    }

    // MARK: - Rendering

    private func renderWithMetal(
        source: CVPixelBuffer,
        output: CVPixelBuffer,
        device: MTLDevice,
        commandQueue: MTLCommandQueue,
        pipelineState: MTLRenderPipelineState,
        textureCache: CVMetalTextureCache
    ) {
        guard let sourceTexture = makeTexture(from: source, cache: textureCache, device: device),
              let outputTexture = makeTexture(from: output, cache: textureCache, device: device),
              let commandBuffer = commandQueue.makeCommandBuffer() else {
            copyPixelBuffer(from: source, to: output)
            return
        }

        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = outputTexture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        renderPassDescriptor.colorAttachments[0].storeAction = .store

        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            copyPixelBuffer(from: source, to: output)
            return
        }

        encoder.setRenderPipelineState(pipelineState)
        encoder.setFragmentTexture(sourceTexture, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
        encoder.endEncoding()

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }

    private func makeTexture(from pixelBuffer: CVPixelBuffer, cache: CVMetalTextureCache, device: MTLDevice) -> MTLTexture? {
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)

        var metalTexture: CVMetalTexture?
        let status = CVMetalTextureCacheCreateTextureFromImage(
            nil, cache, pixelBuffer, nil,
            .bgra8Unorm, width, height, 0, &metalTexture
        )

        guard status == kCVReturnSuccess, let metalTexture else { return nil }
        return CVMetalTextureGetTexture(metalTexture)
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

        if let srcBase = CVPixelBufferGetBaseAddress(source),
           let dstBase = CVPixelBufferGetBaseAddress(dest) {
            let size = min(CVPixelBufferGetDataSize(source), CVPixelBufferGetDataSize(dest))
            memcpy(dstBase, srcBase, size)
        }
    }
}
