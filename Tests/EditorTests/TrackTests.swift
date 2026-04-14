import XCTest
@testable import Editor

final class TrackTests: XCTestCase {
    private func makeClip(start: Double = 0, duration: Double = 5) -> Clip {
        Clip(
            sourceURL: URL(string: "file:///test.mp4")!,
            mediaType: .video,
            timelineStart: start,
            duration: duration,
            sourceDuration: 30.0
        )
    }

    func testAddClip() {
        var track = Track(name: "Video", type: .video)
        let clip = makeClip(start: 2.0, duration: 5.0)
        track.addClip(clip)
        XCTAssertEqual(track.clips.count, 1)
        XCTAssertEqual(track.duration, 7.0) // 2 + 5
    }

    func testAddClipsMaintainsOrder() {
        var track = Track(name: "Video", type: .video)
        track.addClip(makeClip(start: 10.0))
        track.addClip(makeClip(start: 0.0))
        track.addClip(makeClip(start: 5.0))
        XCTAssertEqual(track.clips[0].timelineStart, 0.0)
        XCTAssertEqual(track.clips[1].timelineStart, 5.0)
        XCTAssertEqual(track.clips[2].timelineStart, 10.0)
    }

    func testRemoveClip() {
        var track = Track(name: "Video", type: .video)
        let clip = makeClip()
        track.addClip(clip)
        let removed = track.removeClip(id: clip.id)
        XCTAssertNotNil(removed)
        XCTAssertEqual(track.clips.count, 0)
    }

    func testClipAtTime() {
        var track = Track(name: "Video", type: .video)
        let clip = makeClip(start: 2.0, duration: 5.0)
        track.addClip(clip)

        XCTAssertNil(track.clip(at: 1.0))
        XCTAssertNotNil(track.clip(at: 3.0))
        XCTAssertNotNil(track.clip(at: 6.9))
        XCTAssertNil(track.clip(at: 7.0))
    }

    func testSplitClip() {
        var track = Track(name: "Video", type: .video)
        let clip = makeClip(start: 0, duration: 10.0)
        track.addClip(clip)

        let result = track.splitClip(id: clip.id, at: 4.0)
        XCTAssertNotNil(result)
        XCTAssertEqual(track.clips.count, 2)

        let (first, second) = result!
        XCTAssertEqual(first.timelineStart, 0.0)
        XCTAssertEqual(first.duration, 4.0)
        XCTAssertEqual(second.timelineStart, 4.0)
        XCTAssertEqual(second.duration, 6.0)
    }

    func testSplitClipInvalidTime() {
        var track = Track(name: "Video", type: .video)
        let clip = makeClip(start: 0, duration: 10.0)
        track.addClip(clip)

        // Split at start - should fail
        XCTAssertNil(track.splitClip(id: clip.id, at: 0))
        // Split at end - should fail
        XCTAssertNil(track.splitClip(id: clip.id, at: 10.0))
        // Split outside clip - should fail
        XCTAssertNil(track.splitClip(id: clip.id, at: 15.0))
    }
}
