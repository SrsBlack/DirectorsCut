#if canImport(UIKit)
import SwiftUI
import Editor

/// Visual representation of a clip on the timeline.
struct TimelineClipView: View {
    let clip: Clip
    let trackType: Track.TrackType
    let pixelsPerSecond: Double
    let isSelected: Bool
    let onTapped: () -> Void
    let onDragged: (Double) -> Void
    let onTrimmed: (TimelineViewModel.TrimEdge, Double) -> Void

    @State private var dragOffset: CGFloat = 0

    private var clipWidth: CGFloat {
        CGFloat(clip.duration * pixelsPerSecond)
    }

    private var clipOffset: CGFloat {
        CGFloat(clip.timelineStart * pixelsPerSecond)
    }

    var body: some View {
        HStack(spacing: 0) {
            // Left trim handle
            trimHandle(edge: .start)

            // Clip body
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(clipColor)

                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(isSelected ? Color.white : Color.clear, lineWidth: 2)

                VStack(spacing: 2) {
                    if trackType == .video || trackType == .text {
                        Text(clip.name.isEmpty ? "Clip" : clip.name)
                            .font(.caption2)
                            .foregroundColor(.white)
                            .lineLimit(1)
                    }

                    if trackType == .audio {
                        // Waveform placeholder
                        WaveformPlaceholder()
                    }
                }
                .padding(.horizontal, 6)
            }
            .frame(width: max(clipWidth - 16, 20), height: 48)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        dragOffset = value.translation.width
                    }
                    .onEnded { value in
                        let timeDelta = Double(value.translation.width) / pixelsPerSecond
                        onDragged(clip.timelineStart + timeDelta)
                        dragOffset = 0
                    }
            )
            .onTapGesture {
                onTapped()
            }

            // Right trim handle
            trimHandle(edge: .end)
        }
        .offset(x: clipOffset + dragOffset)
    }

    private func trimHandle(edge: TimelineViewModel.TrimEdge) -> some View {
        Rectangle()
            .fill(isSelected ? Color.white.opacity(0.6) : Color.clear)
            .frame(width: 8, height: 48)
            .contentShape(Rectangle())
            .gesture(
                DragGesture()
                    .onEnded { value in
                        let timeDelta = Double(value.translation.width) / pixelsPerSecond
                        onTrimmed(edge, timeDelta)
                    }
            )
    }

    private var clipColor: Color {
        switch trackType {
        case .video: return Color(red: 0.2, green: 0.5, blue: 0.9)
        case .audio: return Color(red: 0.2, green: 0.7, blue: 0.4)
        case .text: return Color(red: 0.9, green: 0.6, blue: 0.2)
        }
    }
}

/// Placeholder waveform visualization
struct WaveformPlaceholder: View {
    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 1) {
                ForEach(0..<Int(geo.size.width / 3), id: \.self) { i in
                    let height = CGFloat.random(in: 0.2...1.0) * geo.size.height
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color.white.opacity(0.5))
                        .frame(width: 2, height: height)
                }
            }
        }
        .frame(height: 24)
    }
}
#endif
