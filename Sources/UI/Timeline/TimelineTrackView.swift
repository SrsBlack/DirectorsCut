#if canImport(UIKit)
import SwiftUI

/// A single track row in the timeline showing its clips.
struct TimelineTrackView: View {
    let track: Track
    let pixelsPerSecond: Double
    let selectedClipId: UUID?
    let onClipTapped: (UUID) -> Void
    let onClipDragged: (UUID, Double) -> Void
    let onClipTrimmed: (UUID, TimelineViewModel.TrimEdge, Double) -> Void

    var body: some View {
        ZStack(alignment: .leading) {
            // Track background
            RoundedRectangle(cornerRadius: 4)
                .fill(trackColor.opacity(0.1))
                .frame(height: 56)

            // Clips
            ForEach(track.clips) { clip in
                TimelineClipView(
                    clip: clip,
                    trackType: track.type,
                    pixelsPerSecond: pixelsPerSecond,
                    isSelected: clip.id == selectedClipId,
                    onTapped: { onClipTapped(clip.id) },
                    onDragged: { newStart in onClipDragged(clip.id, newStart) },
                    onTrimmed: { edge, delta in onClipTrimmed(clip.id, edge, delta) }
                )
            }
        }
        .frame(height: 60)
    }

    private var trackColor: Color {
        switch track.type {
        case .video: return .blue
        case .audio: return .green
        case .text: return .orange
        }
    }
}
#endif
