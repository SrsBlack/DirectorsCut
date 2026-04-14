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
        self.timelineViewModel = TimelineViewModel(
            timeline: project.timeline,
            editHistory: editHistory
        )

        setupAutosave()
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

        case .removeTrack(_, let index):
            if index < project.timeline.tracks.count {
                project.timeline.tracks.remove(at: index)
            }

        case .batch(let commands, _):
            for cmd in commands {
                apply(cmd)
            }

        default:
            break
        }

        project.markModified()
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
