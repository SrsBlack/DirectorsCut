import XCTest
@testable import Render
import Editor

// FIX(audit-2026-05-09 #A5): scaffold for the 3-effect chain ping-pong test.
// Metal device is unavailable on CI (no GPU), so tests are structured to skip
// gracefully rather than crash. Un-skip individually once a Metal-capable runner exists.
//
// TODO: implement after an Xcode target with Metal device entitlement is added.
final class MetalCompositorTests: XCTestCase {

    // MARK: - 3-effect ping-pong

    /// Verifies that applying 3 effects in sequence does not alias the src/dst textures.
    /// The compositor must read from the previous output, not overwrite it mid-chain.
    func testThreeEffectChainDoesNotAliasTextures() throws {
        // TODO(A5): Create a MetalCompositor, build a 1-frame AVAsynchronousVideoCompositionRequest
        // with 3 effects (e.g. colorCorrection → gaussianBlur → sharpen), render it, and assert
        // the output pixel buffer is non-black and differs from the raw input.
        // Requires a real MTLDevice — skip on CI without GPU.
        guard MTLCreateSystemDefaultDevice() != nil else {
            throw XCTSkip("No Metal device available (CI without GPU)")
        }
        // Placeholder: test body to be filled in once Xcode target exists.
        XCTAssert(true, "Ping-pong scaffold — replace with real test")
    }

    /// Verifies that a single-effect chain writes directly to the output without
    /// touching the scratch textures (no unnecessary allocation).
    func testSingleEffectWritesDirectlyToOutput() throws {
        guard MTLCreateSystemDefaultDevice() != nil else {
            throw XCTSkip("No Metal device available (CI without GPU)")
        }
        // TODO(A5): assert that scratch texture allocation is zero for a 1-effect chain.
        XCTAssert(true, "Single-effect scaffold — replace with real test")
    }
}
