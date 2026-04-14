import XCTest
@testable import Editor

final class EditHistoryTests: XCTestCase {
    func testRecordAndUndo() {
        let history = EditHistory()
        let command = EditCommand.addTrack(track: Track(name: "Test", type: .video))
        history.record(command)

        XCTAssertTrue(history.canUndo)
        XCTAssertFalse(history.canRedo)
        XCTAssertEqual(history.undoActionName, "Add Track")

        let undone = history.popUndo()
        XCTAssertNotNil(undone)
        XCTAssertFalse(history.canUndo)
        XCTAssertTrue(history.canRedo)
    }

    func testUndoAndRedo() {
        let history = EditHistory()
        let command = EditCommand.setFramerate(old: 30, new: 60)
        history.record(command)

        _ = history.popUndo()
        XCTAssertTrue(history.canRedo)
        XCTAssertEqual(history.redoActionName, "Change Frame Rate")

        let redone = history.popRedo()
        XCTAssertNotNil(redone)
        XCTAssertTrue(history.canUndo)
        XCTAssertFalse(history.canRedo)
    }

    func testRecordClearsRedo() {
        let history = EditHistory()
        history.record(.setFramerate(old: 30, new: 60))
        _ = history.popUndo()
        XCTAssertTrue(history.canRedo)

        // Recording a new command should clear redo
        history.record(.setFramerate(old: 30, new: 24))
        XCTAssertFalse(history.canRedo)
    }

    func testMaxHistorySize() {
        let history = EditHistory(maxHistorySize: 3)

        for i in 0..<5 {
            history.record(.setFramerate(old: Double(i), new: Double(i + 1)))
        }

        XCTAssertEqual(history.undoStack.count, 3)
    }

    func testClear() {
        let history = EditHistory()
        history.record(.setFramerate(old: 30, new: 60))
        _ = history.popUndo()

        history.clear()
        XCTAssertFalse(history.canUndo)
        XCTAssertFalse(history.canRedo)
    }

    func testCommandInverse() {
        let trackId = UUID()
        let command = EditCommand.setTrackVolume(trackId: trackId, oldVolume: 0.5, newVolume: 1.0)
        let inverse = command.inverse

        if case .setTrackVolume(let id, let old, let new) = inverse {
            XCTAssertEqual(id, trackId)
            XCTAssertEqual(old, 1.0)
            XCTAssertEqual(new, 0.5)
        } else {
            XCTFail("Inverse should be setTrackVolume")
        }
    }
}
