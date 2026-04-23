import XCTest
@testable import Editor

final class TextClipTests: XCTestCase {
    func testDefaultTextClip() {
        let tc = TextClip()
        XCTAssertEqual(tc.text, "Text")
        XCTAssertEqual(tc.position, .center)
        XCTAssertEqual(tc.duration, 3.0)
        XCTAssertEqual(tc.timelineEnd, tc.timelineStart + tc.duration)
    }

    func testTimelineEnd() {
        let tc = TextClip(timelineStart: 5.0, duration: 2.0)
        XCTAssertEqual(tc.timelineEnd, 7.0)
    }

    func testStylePresets() {
        XCTAssertEqual(TextStyle.title.fontSize, 48)
        XCTAssertEqual(TextStyle.title.fontWeight, .heavy)
        XCTAssertEqual(TextStyle.subtitle.fontWeight, .medium)
        XCTAssertEqual(TextStyle.lowerThird.animation, .slideUp)
        XCTAssertNotNil(TextStyle.lowerThird.backgroundColor)
    }

    func testPresetsListNotEmpty() {
        XCTAssertGreaterThanOrEqual(TextStyle.presets.count, 4)
        for (name, _) in TextStyle.presets {
            XCTAssertFalse(name.isEmpty)
        }
    }

    func testTextPositionCases() {
        XCTAssertEqual(TextPosition.allCases.count, 9)
    }

    func testCodableColor() {
        let c = CodableColor.white
        XCTAssertEqual(c.r, 1); XCTAssertEqual(c.g, 1)
        XCTAssertEqual(c.b, 1); XCTAssertEqual(c.a, 1)
    }

    func testCodableRoundTrip() throws {
        let original = TextClip(
            text: "Hello World",
            style: .lowerThird,
            timelineStart: 2.5,
            duration: 4.0,
            position: .bottomCenter
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TextClip.self, from: data)
        XCTAssertEqual(decoded, original)
        XCTAssertEqual(decoded.text, "Hello World")
        XCTAssertEqual(decoded.position, .bottomCenter)
    }

    func testTimelineTextOverlays() {
        var timeline = Timeline.defaultTimeline()
        XCTAssertTrue(timeline.textOverlays.isEmpty)

        let tc = TextClip(text: "Title", timelineStart: 1.0, duration: 3.0)
        timeline.addTextOverlay(tc)
        XCTAssertEqual(timeline.textOverlays.count, 1)

        let visible = timeline.textOverlays(at: 2.0)
        XCTAssertEqual(visible.count, 1)
        XCTAssertEqual(visible.first?.text, "Title")

        let notVisible = timeline.textOverlays(at: 5.0)
        XCTAssertTrue(notVisible.isEmpty)

        timeline.removeTextOverlay(id: tc.id)
        XCTAssertTrue(timeline.textOverlays.isEmpty)
    }

    func testUpdateTextOverlay() {
        var timeline = Timeline.defaultTimeline()
        var tc = TextClip(text: "Before", timelineStart: 0, duration: 2.0)
        timeline.addTextOverlay(tc)

        tc.text = "After"
        timeline.updateTextOverlay(tc)

        XCTAssertEqual(timeline.textOverlays.first?.text, "After")
    }
}
