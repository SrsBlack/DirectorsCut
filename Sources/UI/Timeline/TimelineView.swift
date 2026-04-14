#if canImport(UIKit)
import SwiftUI
import UIKit

/// The main timeline view backed by UIKit for performance-critical gestures.
public struct TimelineView: View {
    @ObservedObject var viewModel: TimelineViewModel
    let onClipSelected: (UUID?) -> Void
    let onTimeChanged: (Double) -> Void

    public init(
        viewModel: TimelineViewModel,
        onClipSelected: @escaping (UUID?) -> Void = { _ in },
        onTimeChanged: @escaping (Double) -> Void = { _ in }
    ) {
        self.viewModel = viewModel
        self.onClipSelected = onClipSelected
        self.onTimeChanged = onTimeChanged
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Time ruler
            TimelineRulerView(
                duration: viewModel.duration,
                pixelsPerSecond: viewModel.pixelsPerSecond,
                scrollOffset: viewModel.scrollOffset
            )
            .frame(height: 28)

            // Track area with scrolling
            ScrollView(.horizontal, showsIndicators: false) {
                ZStack(alignment: .topLeading) {
                    // Tracks
                    VStack(spacing: 2) {
                        ForEach(viewModel.tracks) { track in
                            TimelineTrackView(
                                track: track,
                                pixelsPerSecond: viewModel.pixelsPerSecond,
                                selectedClipId: viewModel.selectedClipId,
                                onClipTapped: { clipId in
                                    viewModel.selectedClipId = clipId
                                    onClipSelected(clipId)
                                },
                                onClipDragged: { clipId, newStart in
                                    viewModel.moveClip(clipId: clipId, toTime: newStart)
                                },
                                onClipTrimmed: { clipId, edge, delta in
                                    viewModel.trimClip(clipId: clipId, edge: edge, delta: delta)
                                }
                            )
                        }
                    }
                    .padding(.top, 4)

                    // Playhead
                    PlayheadView(
                        currentTime: viewModel.currentTime,
                        pixelsPerSecond: viewModel.pixelsPerSecond,
                        height: max(CGFloat(viewModel.tracks.count) * 64 + 8, 120)
                    )
                }
                .frame(width: max(viewModel.duration * viewModel.pixelsPerSecond + 100, 300))
            }
            .background(Color(uiColor: .systemBackground).opacity(0.95))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let time = max(0, Double(value.location.x) / viewModel.pixelsPerSecond)
                        viewModel.currentTime = min(time, viewModel.duration)
                        onTimeChanged(viewModel.currentTime)
                    }
            )
        }
        .background(Color(uiColor: .secondarySystemBackground))
    }
}

/// ViewModel for the timeline, managing state and edit operations.
@MainActor
public final class TimelineViewModel: ObservableObject {
    @Published public var tracks: [Track] = []
    @Published public var currentTime: Double = 0
    @Published public var duration: Double = 0
    @Published public var pixelsPerSecond: Double = 80
    @Published public var scrollOffset: CGFloat = 0
    @Published public var selectedClipId: UUID?

    private var timeline: Timeline
    private let editHistory: EditHistory

    public init(timeline: Timeline = .defaultTimeline(), editHistory: EditHistory = EditHistory()) {
        self.timeline = timeline
        self.editHistory = editHistory
        self.tracks = timeline.tracks
        self.duration = timeline.duration
    }

    /// Update from a new timeline state
    public func update(from timeline: Timeline) {
        self.timeline = timeline
        self.tracks = timeline.tracks
        self.duration = timeline.duration
    }

    /// Move a clip to a new timeline position
    public func moveClip(clipId: UUID, toTime newStart: Double) {
        guard let (trackIdx, clipIdx) = timeline.findClip(id: clipId) else { return }
        let clip = timeline.tracks[trackIdx].clips[clipIdx]
        let oldStart = clip.timelineStart

        let command = EditCommand.moveClip(
            trackId: timeline.tracks[trackIdx].id,
            clipId: clipId,
            oldStart: oldStart,
            newStart: max(0, newStart)
        )

        timeline.tracks[trackIdx].clips[clipIdx].timelineStart = max(0, newStart)
        editHistory.record(command)
        update(from: timeline)
    }

    /// Trim a clip from an edge
    public func trimClip(clipId: UUID, edge: TrimEdge, delta: Double) {
        guard let (trackIdx, clipIdx) = timeline.findClip(id: clipId) else { return }
        let clip = timeline.tracks[trackIdx].clips[clipIdx]

        switch edge {
        case .start:
            let newSourceStart = max(0, clip.sourceStartTime + delta * clip.speed)
            let newDuration = max(0.1, clip.duration - delta)
            let command = EditCommand.trimClipStart(
                trackId: timeline.tracks[trackIdx].id,
                clipId: clipId,
                oldSourceStart: clip.sourceStartTime,
                oldDuration: clip.duration,
                newSourceStart: newSourceStart,
                newDuration: newDuration
            )
            timeline.tracks[trackIdx].clips[clipIdx].sourceStartTime = newSourceStart
            timeline.tracks[trackIdx].clips[clipIdx].timelineStart = clip.timelineStart + delta
            timeline.tracks[trackIdx].clips[clipIdx].duration = newDuration
            editHistory.record(command)

        case .end:
            let newDuration = max(0.1, min(clip.maxDuration, clip.duration + delta))
            let command = EditCommand.trimClipEnd(
                trackId: timeline.tracks[trackIdx].id,
                clipId: clipId,
                oldDuration: clip.duration,
                newDuration: newDuration
            )
            timeline.tracks[trackIdx].clips[clipIdx].duration = newDuration
            editHistory.record(command)
        }

        update(from: timeline)
    }

    /// Split the selected clip at the current playhead position
    public func splitAtPlayhead() {
        guard let clipId = selectedClipId,
              let (trackIdx, _) = timeline.findClip(id: clipId) else { return }

        if timeline.tracks[trackIdx].splitClip(id: clipId, at: currentTime) != nil {
            update(from: timeline)
        }
    }

    /// Delete the selected clip
    public func deleteSelectedClip() {
        guard let clipId = selectedClipId else { return }
        for i in 0..<timeline.tracks.count {
            if let clip = timeline.tracks[i].removeClip(id: clipId) {
                let command = EditCommand.removeClip(trackId: timeline.tracks[i].id, clip: clip)
                editHistory.record(command)
                selectedClipId = nil
                update(from: timeline)
                return
            }
        }
    }

    /// Zoom in/out the timeline
    public func zoom(scale: Double) {
        pixelsPerSecond = max(20, min(300, pixelsPerSecond * scale))
    }

    public enum TrimEdge {
        case start, end
    }
}
#endif
