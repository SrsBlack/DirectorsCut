import XCTest
@testable import Editor
@testable import Render

final class CompositionBuilderTests: XCTestCase {
    func testBuildEmptyTimeline() async throws {
        let timeline = Timeline.defaultTimeline()
        let result = try await CompositionBuilder.build(from: timeline)
        XCTAssertNotNil(result.composition)
        XCTAssertNotNil(result.videoComposition)
        XCTAssertNotNil(result.audioMix)
    }
}
