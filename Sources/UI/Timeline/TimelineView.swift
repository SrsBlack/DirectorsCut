#if canImport(UIKit)
import SwiftUI
import UIKit

/// The main timeline view backed by UIKit for performance-critical gestures.
///
/// All mutation events (move, trim, split, delete) are surfaced as callbacks
/// so the parent (typically `AppState` via `EditorLayout`) is the single
/// source of truth for the project — the ViewModel only holds display state
/// (zoom, scroll, selection, current time).
public struct TimelineView: View {
    @ObservedObject var viewModel: TimelineViewModel
    let onClipSelected: (UUID?) -> Void
    let onTimeChanged:  (Double) -> Void
    let onClipMoved:    (UUID, Double) -> Void
    let onClipTrimmed:  (UUID, TimelineViewModel.TrimEdge, Double) -> Void

    public init(
        viewModel: TimelineViewModel,
        onClipSelected: @escaping (UUID?) -> Void = { _ in },
        onTimeChanged:  @escaping (Double) -> Void = { _ in },
        onClipMoved:    @escaping (UUID, Double) -> Void = { _, _ in },
        onClipTrimmed:  @escaping (UUID, TimelineViewModel.TrimEdge, Double) -> Void = { _, _, _ in }
    ) {
        self.viewModel = viewModel
        self.onClipSelected = onClipSelected
        self.onTimeChanged = onTimeChanged
        self.onClipMoved = onClipMoved
        self.onClipTrimmed = onClipTrimmed
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
                                    onClipMoved(clipId, newStart)
                                },
                                onClipTrimmed: { clipId, edge, delta in
                                    onClipTrimmed(clipId, edge, delta)
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

/// Display state for the timeline (zoom, scroll, selection, current time).
/// Mutations to the underlying project happen on `AppState`, not here.
@MainActor
public final class TimelineViewModel: ObservableObject {
    @Published public var tracks: [Track] = []
    @Published public var currentTime: Double = 0
    @Published public var duration: Double = 0
    @Published public var pixelsPerSecond: Double = 80
    @Published public var scrollOffset: CGFloat = 0
    @Published public var selectedClipId: UUID?

    public init(timeline: Timeline = .defaultTimeline()) {
        self.tracks = timeline.tracks
        self.duration = timeline.duration
    }

    /// Refresh display state from a new timeline snapshot.
    public func update(from timeline: Timeline) {
        self.tracks = timeline.tracks
        self.duration = timeline.duration
    }

    /// Adjust zoom level.
    public func zoom(scale: Double) {
        pixelsPerSecond = max(20, min(300, pixelsPerSecond * scale))
    }

    public enum TrimEdge {
        case start, end
    }
}
#endif
