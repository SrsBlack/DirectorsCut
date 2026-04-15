#if canImport(UIKit)
import SwiftUI
import Combine

/// Central app state coordinating all editor components.
@MainActor
public final class AppState: ObservableObject {
    @Published public var project: Project
    @Published public var selectedClipId: UUID?

    public let editHistory = EditHistory()
    public let previewPlayer = PreviewPlayer()
    public let mediaLibrary = MediaLibrary()
    public let exportEngine = ExportEngine()
    public let timelineViewModel: TimelineViewModel

    private var autosaveTimer: Timer?
    private var projectURL: URL?

    public init() {
        let project = Project()
        self.project = project
        self.timelineViewModel = TimelineViewModel(timeline: project.timeline)

        setupAutosave()
    }

    /// The currently selected clip (computed from selectedClipId), if any.
    public var selectedClip: Clip? {
        guard let id = selectedClipId,
              let (ti, ci) = project.timeline.findClip(id: id) else { return nil }
        return project.timeline.tracks[ti].clips[ci]
    }

    /// The track ID containing the selected clip.
    public var selectedClipTrackId: UUID? {
        guard let id = selectedClipId,
              let (ti, _) = project.timeline.findClip(id: id) else { return nil }
        return project.timeline.tracks[ti].id
    }

    /// Add a clip from a media asset to the first video or audio track
    public func addClipFromAsset(_ asset: MediaLibrary.MediaAsset) {
        let clip = mediaLibrary.createClip(from: asset, at: project.timeline.duration)

        let trackIndex: Int
        switch asset.mediaType {
        case .video, .image:
            if let idx = project.timeline.tracks.firstIndex(where: { $0.type == .video }) {
                trackIndex = idx
            } else {
                let track = Track(name: "Video \(project.timeline.videoTracks.count + 1)", type: .video)
                project.timeline.addTrack(track)
                trackIndex = project.timeline.tracks.count - 1
            }
        case .audio:
            if let idx = project.timeline.tracks.firstIndex(where: { $0.type == .audio }) {
                trackIndex = idx
            } else {
                let track = Track(name: "Audio \(project.timeline.audioTracks.count + 1)", type: .audio)
                project.timeline.addTrack(track)
                trackIndex = project.timeline.tracks.count - 1
            }
        }

        project.timeline.tracks[trackIndex].addClip(clip)
        editHistory.record(.addClip(trackId: project.timeline.tracks[trackIndex].id, clip: clip))
        project.markModified()
        syncTimeline()
        rebuildComposition()
    }

    /// Undo the last edit
    public func undo() {
        guard let command = editHistory.popUndo() else { return }
        apply(command)
        syncTimeline()
        rebuildComposition()
    }

    /// Redo the last undone edit
    public func redo() {
        guard let command = editHistory.popRedo() else { return }
        apply(command)
        syncTimeline()
        rebuildComposition()
    }

    // MARK: - Timeline mutation API (called from the timeline UI)

    /// Move a clip to a new timeline position.
    public func moveClip(_ clipId: UUID, toTime newStart: Double) {
        guard let (ti, ci) = project.timeline.findClip(id: clipId) else { return }
        let trackId = project.timeline.tracks[ti].id
        let oldStart = project.timeline.tracks[ti].clips[ci].timelineStart
        let clamped = max(0, newStart)

        project.timeline.tracks[ti].clips[ci].timelineStart = clamped
        editHistory.record(.moveClip(trackId: trackId, clipId: clipId,
                                      oldStart: oldStart, newStart: clamped))
        project.markModified()
        syncTimeline()
        rebuildComposition()
    }

    /// Trim a clip from one of its edges by the given time delta.
    public func trimClip(_ clipId: UUID, edge: TrimEdge, delta: Double) {
        guard let (ti, ci) = project.timeline.findClip(id: clipId) else { return }
        let trackId = project.timeline.tracks[ti].id
        let clip = project.timeline.tracks[ti].clips[ci]

        switch edge {
        case .start:
            let newSourceStart = max(0, clip.sourceStartTime + delta * clip.speed)
            let newDuration    = max(0.1, clip.duration - delta)
            project.timeline.tracks[ti].clips[ci].sourceStartTime = newSourceStart
            project.timeline.tracks[ti].clips[ci].timelineStart  = clip.timelineStart + delta
            project.timeline.tracks[ti].clips[ci].duration       = newDuration
            editHistory.record(.trimClipStart(
                trackId: trackId, clipId: clipId,
                oldSourceStart: clip.sourceStartTime, oldDuration: clip.duration,
                newSourceStart: newSourceStart, newDuration: newDuration
            ))
        case .end:
            let newDuration = max(0.1, min(clip.maxDuration, clip.duration + delta))
            project.timeline.tracks[ti].clips[ci].duration = newDuration
            editHistory.record(.trimClipEnd(
                trackId: trackId, clipId: clipId,
                oldDuration: clip.duration, newDuration: newDuration
            ))
        }
        project.markModified()
        syncTimeline()
        rebuildComposition()
    }

    /// Split the currently selected clip at the current playhead time.
    public func splitSelectedClipAtPlayhead() {
        guard let clipId = selectedClipId,
              let (ti, _) = project.timeline.findClip(id: clipId) else { return }
        let originalClip = project.timeline.tracks[ti].clips
            .first(where: { $0.id == clipId })

        guard let originalClip,
              let (first, second) = project.timeline.tracks[ti].splitClip(id: clipId, at: previewPlayer.currentTime)
        else { return }

        editHistory.record(.splitClip(
            trackId: project.timeline.tracks[ti].id,
            originalClip: originalClip,
            firstHalf: first,
            secondHalf: second
        ))
        project.markModified()
        syncTimeline()
        rebuildComposition()
    }

    /// Delete the currently selected clip from its track.
    public func deleteSelectedClip() {
        guard let clipId = selectedClipId else { return }
        for ti in 0..<project.timeline.tracks.count {
            if let removed = project.timeline.tracks[ti].removeClip(id: clipId) {
                let trackId = project.timeline.tracks[ti].id
                editHistory.record(.removeClip(trackId: trackId, clip: removed))
                selectedClipId = nil
                project.markModified()
                syncTimeline()
                rebuildComposition()
                return
            }
        }
    }

    public enum TrimEdge {
        case start, end
    }

    // MARK: - Clip mutation API (called from the UI)

    /// Replace the selected clip's properties (volume, opacity, speed, etc.)
    /// Records the appropriate undo command for whichever fields changed.
    public func updateClip(_ updated: Clip) {
        guard let (ti, ci) = project.timeline.findClip(id: updated.id) else { return }
        let trackId = project.timeline.tracks[ti].id
        let old = project.timeline.tracks[ti].clips[ci]

        var commands: [EditCommand] = []
        if old.volume != updated.volume {
            commands.append(.setClipVolume(trackId: trackId, clipId: updated.id,
                                            oldVolume: old.volume, newVolume: updated.volume))
        }
        if old.opacity != updated.opacity {
            commands.append(.setClipOpacity(trackId: trackId, clipId: updated.id,
                                             oldOpacity: old.opacity, newOpacity: updated.opacity))
        }
        if old.speed != updated.speed {
            commands.append(.setClipSpeed(trackId: trackId, clipId: updated.id,
                                          oldSpeed: old.speed, newSpeed: updated.speed,
                                          oldDuration: old.duration, newDuration: updated.duration))
        }

        // Apply the new state directly (covers fields without dedicated commands)
        project.timeline.tracks[ti].clips[ci] = updated

        // Record undo
        switch commands.count {
        case 0:  break // nothing tracked, just a passive update
        case 1:  editHistory.record(commands[0])
        default: editHistory.record(.batch(commands: commands, description: "Update Clip"))
        }

        project.markModified()
        syncTimeline()
        rebuildComposition()
    }

    /// Add an effect to the selected clip (or a specific clip).
    public func addEffect(_ type: Effect.EffectType, to clipId: UUID? = nil) {
        let id = clipId ?? selectedClipId
        guard let id, let (ti, ci) = project.timeline.findClip(id: id) else { return }
        let trackId = project.timeline.tracks[ti].id

        let effect: Effect
        switch type {
        case .colorCorrection, .colorGrading: effect = .colorCorrection()
        case .gaussianBlur:                   effect = .blur()
        case .chromaKey:                       effect = .chromaKey()
        case .vignette:                        effect = .vignette()
        default:                               effect = Effect(type: type)
        }

        project.timeline.tracks[ti].clips[ci].effects.append(effect)
        editHistory.record(.addEffect(trackId: trackId, clipId: id, effect: effect))
        project.markModified()
        syncTimeline()
        rebuildComposition()
    }

    /// Remove an effect by its ID from the given clip.
    public func removeEffect(_ effectId: UUID, from clipId: UUID) {
        guard let (ti, ci) = project.timeline.findClip(id: clipId),
              let eIdx = project.timeline.tracks[ti].clips[ci].effects.firstIndex(where: { $0.id == effectId })
        else { return }
        let trackId = project.timeline.tracks[ti].id
        let removed = project.timeline.tracks[ti].clips[ci].effects.remove(at: eIdx)
        editHistory.record(.removeEffect(trackId: trackId, clipId: clipId, effect: removed))
        project.markModified()
        syncTimeline()
        rebuildComposition()
    }

    /// Update the parameters of an existing effect on a clip.
    public func updateEffect(_ updated: Effect, on clipId: UUID) {
        guard let (ti, ci) = project.timeline.findClip(id: clipId),
              let eIdx = project.timeline.tracks[ti].clips[ci].effects.firstIndex(where: { $0.id == updated.id })
        else { return }
        let trackId = project.timeline.tracks[ti].id
        let old = project.timeline.tracks[ti].clips[ci].effects[eIdx]
        project.timeline.tracks[ti].clips[ci].effects[eIdx] = updated
        editHistory.record(.updateEffect(trackId: trackId, clipId: clipId, oldEffect: old, newEffect: updated))
        project.markModified()
        syncTimeline()
        rebuildComposition()
    }

    /// Add a transition between two adjacent clips.
    public func addTransition(_ transition: Transition, from fromClipId: UUID, to toClipId: UUID) {
        guard let (ti, _) = project.timeline.findClip(id: fromClipId) else { return }
        let trackId = project.timeline.tracks[ti].id
        let entry = Timeline.TransitionEntry(
            transition: transition,
            fromClipId: fromClipId,
            toClipId: toClipId,
            trackId: trackId
        )
        project.timeline.addTransition(entry)
        editHistory.record(.addTransition(entry: entry))
        project.markModified()
        syncTimeline()
        rebuildComposition()
    }

    // MARK: - Export

    /// Export the current project
    public func export(preset: ExportPreset) async throws -> URL {
        let result = try await CompositionBuilder.build(from: project.timeline)
        let outputURL = ExportEngine.temporaryOutputURL(preset: preset)
        try await exportEngine.export(composition: result, preset: preset, to: outputURL)
        return outputURL
    }

    /// Save the current project
    public func save() {
        let url = projectURL ?? ProjectFile.urlForNewProject(named: project.name)
        projectURL = url
        try? ProjectFile.save(project, to: url)
    }

    /// Load a project from a URL
    public func load(from url: URL) throws {
        project = try ProjectFile.load(from: url)
        projectURL = url
        editHistory.clear()
        syncTimeline()
        rebuildComposition()
    }

    // MARK: - Private

    private func apply(_ command: EditCommand) {
        switch command {
        case .addClip(let trackId, let clip):
            guard let idx = project.timeline.tracks.firstIndex(where: { $0.id == trackId }) else { return }
            project.timeline.tracks[idx].addClip(clip)

        case .removeClip(let trackId, let clip):
            guard let idx = project.timeline.tracks.firstIndex(where: { $0.id == trackId }) else { return }
            project.timeline.tracks[idx].removeClip(id: clip.id)

        case .moveClip(let trackId, let clipId, _, let newStart):
            guard let tIdx = project.timeline.tracks.firstIndex(where: { $0.id == trackId }),
                  let cIdx = project.timeline.tracks[tIdx].clipIndex(id: clipId) else { return }
            project.timeline.tracks[tIdx].clips[cIdx].timelineStart = newStart

        case .trimClipStart(let trackId, let clipId, _, _, let newSourceStart, let newDuration):
            guard let tIdx = project.timeline.tracks.firstIndex(where: { $0.id == trackId }),
                  let cIdx = project.timeline.tracks[tIdx].clipIndex(id: clipId) else { return }
            project.timeline.tracks[tIdx].clips[cIdx].sourceStartTime = newSourceStart
            project.timeline.tracks[tIdx].clips[cIdx].duration = newDuration

        case .trimClipEnd(let trackId, let clipId, _, let newDuration):
            guard let tIdx = project.timeline.tracks.firstIndex(where: { $0.id == trackId }),
                  let cIdx = project.timeline.tracks[tIdx].clipIndex(id: clipId) else { return }
            project.timeline.tracks[tIdx].clips[cIdx].duration = newDuration

        case .setClipSpeed(let trackId, let clipId, _, let newSpeed, _, let newDuration):
            guard let tIdx = project.timeline.tracks.firstIndex(where: { $0.id == trackId }),
                  let cIdx = project.timeline.tracks[tIdx].clipIndex(id: clipId) else { return }
            project.timeline.tracks[tIdx].clips[cIdx].speed = newSpeed
            project.timeline.tracks[tIdx].clips[cIdx].duration = newDuration

        case .setClipVolume(let trackId, let clipId, _, let newVolume):
            guard let tIdx = project.timeline.tracks.firstIndex(where: { $0.id == trackId }),
                  let cIdx = project.timeline.tracks[tIdx].clipIndex(id: clipId) else { return }
            project.timeline.tracks[tIdx].clips[cIdx].volume = newVolume

        case .setClipOpacity(let trackId, let clipId, _, let newOpacity):
            guard let tIdx = project.timeline.tracks.firstIndex(where: { $0.id == trackId }),
                  let cIdx = project.timeline.tracks[tIdx].clipIndex(id: clipId) else { return }
            project.timeline.tracks[tIdx].clips[cIdx].opacity = newOpacity

        case .addTrack(let track):
            project.timeline.addTrack(track)

        case .removeTrack(let track, _):
            // Find the actual index by ID rather than relying on stored index
            if let idx = project.timeline.tracks.firstIndex(where: { $0.id == track.id }) {
                project.timeline.tracks.remove(at: idx)
            }

        case .addEffect(let trackId, let clipId, let effect):
            guard let (ti, ci) = locate(trackId: trackId, clipId: clipId) else { return }
            project.timeline.tracks[ti].clips[ci].effects.append(effect)

        case .removeEffect(let trackId, let clipId, let effect):
            guard let (ti, ci) = locate(trackId: trackId, clipId: clipId) else { return }
            project.timeline.tracks[ti].clips[ci].effects.removeAll { $0.id == effect.id }

        case .updateEffect(let trackId, let clipId, _, let newEffect):
            guard let (ti, ci) = locate(trackId: trackId, clipId: clipId) else { return }
            if let eIdx = project.timeline.tracks[ti].clips[ci].effects.firstIndex(where: { $0.id == newEffect.id }) {
                project.timeline.tracks[ti].clips[ci].effects[eIdx] = newEffect
            }

        case .splitClip(let trackId, _, let firstHalf, let secondHalf):
            guard let ti = project.timeline.tracks.firstIndex(where: { $0.id == trackId }) else { return }
            // Replace original with two halves (called via redo)
            if let idx = project.timeline.tracks[ti].clipIndex(id: firstHalf.id) {
                project.timeline.tracks[ti].clips[idx] = firstHalf
            } else {
                project.timeline.tracks[ti].addClip(firstHalf)
            }
            project.timeline.tracks[ti].addClip(secondHalf)

        case .addTransition(let entry):
            project.timeline.addTransition(entry)

        case .removeTransition(let entry):
            project.timeline.removeTransition(id: entry.id)

        case .setTrackVolume(let trackId, _, let newVolume):
            if let ti = project.timeline.tracks.firstIndex(where: { $0.id == trackId }) {
                project.timeline.tracks[ti].volume = newVolume
            }

        case .setTrackMuted(let trackId, _, let newMuted):
            if let ti = project.timeline.tracks.firstIndex(where: { $0.id == trackId }) {
                project.timeline.tracks[ti].isMuted = newMuted
            }

        case .setResolution(_, let new):
            project.timeline.resolution = new

        case .setFramerate(_, let new):
            project.timeline.framerate = new

        case .batch(let commands, _):
            for cmd in commands {
                apply(cmd)
            }
        }

        project.markModified()
    }

    /// Look up a (trackIndex, clipIndex) by IDs.
    private func locate(trackId: UUID, clipId: UUID) -> (Int, Int)? {
        guard let ti = project.timeline.tracks.firstIndex(where: { $0.id == trackId }),
              let ci = project.timeline.tracks[ti].clipIndex(id: clipId) else { return nil }
        return (ti, ci)
    }

    private func syncTimeline() {
        timelineViewModel.update(from: project.timeline)
    }

    private func rebuildComposition() {
        Task {
            if let result = try? await CompositionBuilder.build(from: project.timeline) {
                previewPlayer.loadComposition(result)
            }
        }
    }

    private func setupAutosave() {
        autosaveTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                let url = ProjectFile.autosaveURL(for: self.project)
                try? ProjectFile.save(self.project, to: url)
            }
        }
    }
}
#endif
