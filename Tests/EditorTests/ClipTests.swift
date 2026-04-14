import XCTest
@testable import Editor

final class ClipTests: XCTestCase {
    func testClipTimelineEnd() {
        let clip = Clip(
            sourceURL: URL(string: "file:///test.mp4")!,
            mediaType: .video,
            timelineStart: 5.0,
            duration: 10.0,
            sourceDuration: 30.0
        )
        XCTAssertEqual(clip.timelineEnd, 15.0)
    }

    func testClipMaxDuration() {
        let clip = Clip(
            sourceURL: URL(string: "file:///test.mp4")!,
            mediaType: .video,
            sourceStartTime: 5.0,
            duration: 10.0,
            sourceDuration: 30.0,
            speed: 1.0
        )
        XCTAssertEqual(clip.maxDuration, 25.0) // (30 - 5) / 1.0
    }

    func testClipMaxDurationWithSpeed() {
        let clip = Clip(
            sourceURL: URL(string: "file:///test.mp4")!,
            mediaType: .video,
            sourceStartTime: 0,
            duration: 15.0,
            sourceDuration: 30.0,
            speed: 2.0
        )
        XCTAssertEqual(clip.maxDuration, 15.0) // 30 / 2.0
    }

    func testClipSourceEndTime() {
        let clip = Clip(
            sourceURL: URL(string: "file:///test.mp4")!,
            mediaType: .video,
            sourceStartTime: 5.0,
            duration: 10.0,
            sourceDuration: 30.0,
            speed: 1.0
        )
        XCTAssertEqual(clip.sourceEndTime, 15.0) // 5 + (10 * 1.0)
    }

    func testClipEquatable() {
        let url = URL(string: "file:///test.mp4")!
        let id = UUID()
        let a = Clip(id: id, sourceURL: url, mediaType: .video, duration: 10, sourceDuration: 30)
        let b = Clip(id: id, sourceURL: url, mediaType: .video, duration: 10, sourceDuration: 30)
        XCTAssertEqual(a, b)
    }

    func testClipTransformIdentity() {
        let transform = ClipTransform.identity
        XCTAssertEqual(transform.positionX, 0)
        XCTAssertEqual(transform.positionY, 0)
        XCTAssertEqual(transform.scaleX, 1.0)
        XCTAssertEqual(transform.scaleY, 1.0)
        XCTAssertEqual(transform.rotation, 0)
    }
}
