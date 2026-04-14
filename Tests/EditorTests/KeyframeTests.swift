import XCTest
@testable import Editor

final class KeyframeTests: XCTestCase {
    func testLinearInterpolation() {
        let a = Keyframe(time: 0, value: 0, interpolation: .linear)
        let b = Keyframe(time: 10, value: 100, interpolation: .linear)
        let result = Keyframe.interpolate(from: a, to: b, at: 5)
        XCTAssertEqual(result, 50, accuracy: 0.01)
    }

    func testLinearInterpolationEdges() {
        let a = Keyframe(time: 0, value: 0, interpolation: .linear)
        let b = Keyframe(time: 10, value: 100, interpolation: .linear)
        XCTAssertEqual(Keyframe.interpolate(from: a, to: b, at: 0), 0, accuracy: 0.01)
        XCTAssertEqual(Keyframe.interpolate(from: a, to: b, at: 10), 100, accuracy: 0.01)
    }

    func testHoldInterpolation() {
        let a = Keyframe(time: 0, value: 50, interpolation: .linear)
        let b = Keyframe(time: 10, value: 100, interpolation: .hold)
        let result = Keyframe.interpolate(from: a, to: b, at: 5)
        XCTAssertEqual(result, 50) // Hold keeps the "from" value
    }

    func testKeyframeTrackValue() {
        var track = KeyframeTrack(property: .opacity)
        track.addKeyframe(Keyframe(time: 0, value: 1.0, interpolation: .linear))
        track.addKeyframe(Keyframe(time: 2, value: 0.0, interpolation: .linear))

        XCTAssertEqual(track.value(at: 0), 1.0, accuracy: 0.01)
        XCTAssertEqual(track.value(at: 1), 0.5, accuracy: 0.01)
        XCTAssertEqual(track.value(at: 2), 0.0, accuracy: 0.01)
    }

    func testKeyframeTrackBeforeFirstKeyframe() {
        var track = KeyframeTrack(property: .opacity)
        track.addKeyframe(Keyframe(time: 5, value: 0.5, interpolation: .linear))

        // Before the first keyframe should return the first keyframe's value
        XCTAssertEqual(track.value(at: 0), 0.5)
    }

    func testKeyframeTrackAfterLastKeyframe() {
        var track = KeyframeTrack(property: .opacity)
        track.addKeyframe(Keyframe(time: 0, value: 0.5, interpolation: .linear))
        track.addKeyframe(Keyframe(time: 5, value: 1.0, interpolation: .linear))

        // After the last keyframe should return the last keyframe's value
        XCTAssertEqual(track.value(at: 10), 1.0)
    }

    func testKeyframeTrackEmpty() {
        let track = KeyframeTrack(property: .opacity)
        XCTAssertNil(track.value(at: 5))
    }

    func testAddAndRemoveKeyframe() {
        var track = KeyframeTrack(property: .positionX)
        let kf = Keyframe(time: 5, value: 100)
        track.addKeyframe(kf)
        XCTAssertEqual(track.keyframes.count, 1)

        track.removeKeyframe(id: kf.id)
        XCTAssertEqual(track.keyframes.count, 0)
    }
}
