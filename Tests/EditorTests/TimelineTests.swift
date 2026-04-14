import XCTest
@testable import Editor

final class TimelineTests: XCTestCase {
    func testDefaultTimeline() {
        let timeline = Timeline.defaultTimeline()
        XCTAssertEqual(timeline.tracks.count, 2)
        XCTAssertEqual(timeline.videoTracks.count, 1)
        XCTAssertEqual(timeline.audioTracks.count, 1)
        XCTAssertEqual(timeline.duration, 0)
    }

    func testAddTrack() {
        var timeline = Timeline.defaultTimeline()
        let track = Track(name: "Video 2", type: .video)
        timeline.addTrack(track)
        XCTAssertEqual(timeline.tracks.count, 3)
        XCTAssertEqual(timeline.videoTracks.count, 2)
    }

    func testRemoveTrack() {
        var timeline = Timeline.defaultTimeline()
        let trackId = timeline.tracks[0].id
        let removed = timeline.removeTrack(id: trackId)
        XCTAssertNotNil(removed)
        XCTAssertEqual(timeline.tracks.count, 1)
    }

    func testTimelineDuration() {
        var timeline = Timeline.defaultTimeline()
        let clip = Clip(
            sourceURL: URL(string: "file:///test.mp4")!,
            mediaType: .video,
            timelineStart: 5.0,
            duration: 10.0,
            sourceDuration: 30.0
        )
        timeline.tracks[0].addClip(clip)
        XCTAssertEqual(timeline.duration, 15.0) // 5 + 10
    }

    func testFindClip() {
        var timeline = Timeline.defaultTimeline()
        let clip = Clip(
            sourceURL: URL(string: "file:///test.mp4")!,
            mediaType: .video,
            duration: 10.0,
            sourceDuration: 30.0
        )
        timeline.tracks[0].addClip(clip)

        let found = timeline.findClip(id: clip.id)
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.trackIndex, 0)
        XCTAssertEqual(found?.clipIndex, 0)
    }

    func testResolutionPresets() {
        XCTAssertEqual(Timeline.Resolution.hd1080.width, 1920)
        XCTAssertEqual(Timeline.Resolution.hd1080.height, 1080)
        XCTAssertEqual(Timeline.Resolution.uhd4K.width, 3840)
        XCTAssertEqual(Timeline.Resolution.portrait1080.width, 1080)
        XCTAssertEqual(Timeline.Resolution.portrait1080.height, 1920)
    }
}
