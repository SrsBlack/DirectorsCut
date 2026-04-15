import XCTest
@testable import Editor

/// Regression tests covering the inverse of every `EditCommand` case.
/// `command.inverse.inverse` should always produce a command equivalent
/// to the original (modulo struct ordering inside `.batch`).
final class EditCommandInverseTests: XCTestCase {
    private let trackId = UUID()
    private let clipId = UUID()

    private func sampleClip() -> Clip {
        Clip(
            id: clipId,
            sourceURL: URL(string: "file:///x.mp4")!,
            mediaType: .video,
            duration: 5,
            sourceDuration: 30,
            name: "Sample"
        )
    }

    func testAddClipInverseIsRemoveClip() {
        let cmd = EditCommand.addClip(trackId: trackId, clip: sampleClip())
        if case .removeClip(let tid, let clip) = cmd.inverse {
            XCTAssertEqual(tid, trackId)
            XCTAssertEqual(clip.id, clipId)
        } else {
            XCTFail("Inverse should be removeClip")
        }
    }

    func testMoveClipInverseSwapsOldAndNew() {
        let cmd = EditCommand.moveClip(trackId: trackId, clipId: clipId, oldStart: 1, newStart: 5)
        if case .moveClip(_, _, let old, let new) = cmd.inverse {
            XCTAssertEqual(old, 5)
            XCTAssertEqual(new, 1)
        } else {
            XCTFail("Inverse should be moveClip")
        }
    }

    func testTrimClipStartInverseSwapsValues() {
        let cmd = EditCommand.trimClipStart(
            trackId: trackId, clipId: clipId,
            oldSourceStart: 0, oldDuration: 10,
            newSourceStart: 2, newDuration: 8
        )
        if case .trimClipStart(_, _, let oldSS, let oldDur, let newSS, let newDur) = cmd.inverse {
            XCTAssertEqual(oldSS, 2);  XCTAssertEqual(oldDur, 8)
            XCTAssertEqual(newSS, 0);  XCTAssertEqual(newDur, 10)
        } else {
            XCTFail("Inverse should be trimClipStart")
        }
    }

    func testSpeedInverseAlsoRestoresDuration() {
        let cmd = EditCommand.setClipSpeed(
            trackId: trackId, clipId: clipId,
            oldSpeed: 1.0, newSpeed: 2.0,
            oldDuration: 10, newDuration: 5
        )
        if case .setClipSpeed(_, _, let oldS, let newS, let oldD, let newD) = cmd.inverse {
            XCTAssertEqual(oldS, 2.0);  XCTAssertEqual(newS, 1.0)
            XCTAssertEqual(oldD, 5);    XCTAssertEqual(newD, 10)
        } else {
            XCTFail("Inverse should be setClipSpeed")
        }
    }

    func testAddEffectInverseIsRemoveEffect() {
        let effect = Effect.colorCorrection()
        let cmd = EditCommand.addEffect(trackId: trackId, clipId: clipId, effect: effect)
        if case .removeEffect(_, _, let e) = cmd.inverse {
            XCTAssertEqual(e.id, effect.id)
        } else {
            XCTFail("Inverse should be removeEffect")
        }
    }

    func testUpdateEffectInverseSwapsOldNew() {
        let oldE = Effect.colorCorrection()
        var newE = oldE
        newE.parameters["brightness"] = .float(0.5)

        let cmd = EditCommand.updateEffect(trackId: trackId, clipId: clipId, oldEffect: oldE, newEffect: newE)
        if case .updateEffect(_, _, let returnedOld, let returnedNew) = cmd.inverse {
            XCTAssertEqual(returnedOld.parameters["brightness"]?.floatValue, 0.5)
            XCTAssertEqual(returnedNew.parameters["brightness"]?.floatValue, 0)
        } else {
            XCTFail("Inverse should be updateEffect")
        }
    }

    func testDoubleInverseIsIdentity() {
        let original = EditCommand.setClipVolume(trackId: trackId, clipId: clipId,
                                                  oldVolume: 0.3, newVolume: 0.8)
        let twice = original.inverse.inverse
        if case .setClipVolume(_, _, let oldV, let newV) = twice {
            XCTAssertEqual(oldV, 0.3)
            XCTAssertEqual(newV, 0.8)
        } else {
            XCTFail("Double inverse should equal original")
        }
    }

    func testBatchInverseReversesAndInverts() {
        let cmds: [EditCommand] = [
            .setClipVolume(trackId: trackId, clipId: clipId, oldVolume: 0.5, newVolume: 1.0),
            .setClipOpacity(trackId: trackId, clipId: clipId, oldOpacity: 1.0, newOpacity: 0.5),
        ]
        let batch = EditCommand.batch(commands: cmds, description: "Test")
        if case .batch(let inverted, let desc) = batch.inverse {
            XCTAssertEqual(inverted.count, 2)
            // First inverted command should be the inverse of the LAST original command
            if case .setClipOpacity(_, _, let oldO, let newO) = inverted[0] {
                XCTAssertEqual(oldO, 0.5);  XCTAssertEqual(newO, 1.0)
            } else { XCTFail("First inverted should be opacity") }
            XCTAssertTrue(desc.contains("Test"))
        } else {
            XCTFail("Batch inverse should still be a batch")
        }
    }
}
