import Foundation

/// A reversible editing command (Command pattern for undo/redo).
public enum EditCommand: Codable, Equatable {
    // Clip operations
    case addClip(trackId: UUID, clip: Clip)
    case removeClip(trackId: UUID, clip: Clip)
    case moveClip(trackId: UUID, clipId: UUID, oldStart: Double, newStart: Double)
    case trimClipStart(trackId: UUID, clipId: UUID, oldSourceStart: Double, oldDuration: Double, newSourceStart: Double, newDuration: Double)
    case trimClipEnd(trackId: UUID, clipId: UUID, oldDuration: Double, newDuration: Double)
    case splitClip(trackId: UUID, originalClip: Clip, firstHalf: Clip, secondHalf: Clip)
    case setClipSpeed(trackId: UUID, clipId: UUID, oldSpeed: Double, newSpeed: Double, oldDuration: Double, newDuration: Double)
    case setClipVolume(trackId: UUID, clipId: UUID, oldVolume: Float, newVolume: Float)
    case setClipOpacity(trackId: UUID, clipId: UUID, oldOpacity: Float, newOpacity: Float)

    // Effect operations
    case addEffect(trackId: UUID, clipId: UUID, effect: Effect)
    case removeEffect(trackId: UUID, clipId: UUID, effect: Effect)
    case updateEffect(trackId: UUID, clipId: UUID, oldEffect: Effect, newEffect: Effect)

    // Transition operations
    case addTransition(entry: Timeline.TransitionEntry)
    case removeTransition(entry: Timeline.TransitionEntry)

    // Track operations
    case addTrack(track: Track)
    case removeTrack(track: Track, index: Int)
    case setTrackVolume(trackId: UUID, oldVolume: Float, newVolume: Float)
    case setTrackMuted(trackId: UUID, oldMuted: Bool, newMuted: Bool)

    // Timeline operations
    case setResolution(old: Timeline.Resolution, new: Timeline.Resolution)
    case setFramerate(old: Double, new: Double)

    // Batch (for grouping related commands)
    case batch(commands: [EditCommand], description: String)

    /// Human-readable description of this command
    public var displayName: String {
        switch self {
        case .addClip: return "Add Clip"
        case .removeClip: return "Delete Clip"
        case .moveClip: return "Move Clip"
        case .trimClipStart: return "Trim Start"
        case .trimClipEnd: return "Trim End"
        case .splitClip: return "Split Clip"
        case .setClipSpeed: return "Change Speed"
        case .setClipVolume: return "Change Volume"
        case .setClipOpacity: return "Change Opacity"
        case .addEffect: return "Add Effect"
        case .removeEffect: return "Remove Effect"
        case .updateEffect: return "Update Effect"
        case .addTransition: return "Add Transition"
        case .removeTransition: return "Remove Transition"
        case .addTrack: return "Add Track"
        case .removeTrack: return "Delete Track"
        case .setTrackVolume: return "Change Track Volume"
        case .setTrackMuted: return "Mute Track"
        case .setResolution: return "Change Resolution"
        case .setFramerate: return "Change Frame Rate"
        case .batch(_, let description): return description
        }
    }

    /// Create the inverse command (for undo)
    public var inverse: EditCommand {
        switch self {
        case .addClip(let trackId, let clip):
            return .removeClip(trackId: trackId, clip: clip)
        case .removeClip(let trackId, let clip):
            return .addClip(trackId: trackId, clip: clip)
        case .moveClip(let trackId, let clipId, let oldStart, let newStart):
            return .moveClip(trackId: trackId, clipId: clipId, oldStart: newStart, newStart: oldStart)
        case .trimClipStart(let trackId, let clipId, let oldSourceStart, let oldDuration, let newSourceStart, let newDuration):
            return .trimClipStart(trackId: trackId, clipId: clipId, oldSourceStart: newSourceStart, oldDuration: newDuration, newSourceStart: oldSourceStart, newDuration: oldDuration)
        case .trimClipEnd(let trackId, let clipId, let oldDuration, let newDuration):
            return .trimClipEnd(trackId: trackId, clipId: clipId, oldDuration: newDuration, newDuration: oldDuration)
        case .splitClip(let trackId, let originalClip, let firstHalf, let secondHalf):
            // Undo split: remove both halves, restore original
            return .batch(commands: [
                .removeClip(trackId: trackId, clip: firstHalf),
                .removeClip(trackId: trackId, clip: secondHalf),
                .addClip(trackId: trackId, clip: originalClip),
            ], description: "Undo Split")
        case .setClipSpeed(let trackId, let clipId, let oldSpeed, let newSpeed, let oldDuration, let newDuration):
            return .setClipSpeed(trackId: trackId, clipId: clipId, oldSpeed: newSpeed, newSpeed: oldSpeed, oldDuration: newDuration, newDuration: oldDuration)
        case .setClipVolume(let trackId, let clipId, let oldVol, let newVol):
            return .setClipVolume(trackId: trackId, clipId: clipId, oldVolume: newVol, newVolume: oldVol)
        case .setClipOpacity(let trackId, let clipId, let oldOpacity, let newOpacity):
            return .setClipOpacity(trackId: trackId, clipId: clipId, oldOpacity: newOpacity, newOpacity: oldOpacity)
        case .addEffect(let trackId, let clipId, let effect):
            return .removeEffect(trackId: trackId, clipId: clipId, effect: effect)
        case .removeEffect(let trackId, let clipId, let effect):
            return .addEffect(trackId: trackId, clipId: clipId, effect: effect)
        case .updateEffect(let trackId, let clipId, let oldEffect, let newEffect):
            return .updateEffect(trackId: trackId, clipId: clipId, oldEffect: newEffect, newEffect: oldEffect)
        case .addTransition(let entry):
            return .removeTransition(entry: entry)
        case .removeTransition(let entry):
            return .addTransition(entry: entry)
        case .addTrack(let track):
            return .removeTrack(track: track, index: 0) // index tracked at apply time
        case .removeTrack(let track, _):
            return .addTrack(track: track)
        case .setTrackVolume(let trackId, let oldVol, let newVol):
            return .setTrackVolume(trackId: trackId, oldVolume: newVol, newVolume: oldVol)
        case .setTrackMuted(let trackId, let oldMuted, let newMuted):
            return .setTrackMuted(trackId: trackId, oldMuted: newMuted, newMuted: oldMuted)
        case .setResolution(let old, let new):
            return .setResolution(old: new, new: old)
        case .setFramerate(let old, let new):
            return .setFramerate(old: new, new: old)
        case .batch(let commands, let description):
            return .batch(commands: commands.reversed().map(\.inverse), description: "Undo \(description)")
        }
    }
}
