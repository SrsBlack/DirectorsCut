#if canImport(UIKit)
import SwiftUI
import Render

/// Play/pause, scrub, and navigation controls for the video preview.
public struct TransportControls: View {
    @ObservedObject var player: PreviewPlayer

    public init(player: PreviewPlayer) {
        self.player = player
    }

    public var body: some View {
        VStack(spacing: 12) {
            // Scrub bar
            ScrubBar(
                currentTime: $player.currentTime,
                duration: player.duration,
                onSeek: { time in player.seek(to: time) }
            )

            // Control buttons
            HStack(spacing: 24) {
                // Skip to start
                Button {
                    player.seekToStart()
                } label: {
                    Image(systemName: "backward.end.fill")
                        .font(.title3)
                }

                // Step backward
                Button {
                    player.stepBackward()
                } label: {
                    Image(systemName: "backward.frame.fill")
                        .font(.title3)
                }

                // Play/Pause
                Button {
                    player.togglePlayPause()
                } label: {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title)
                        .frame(width: 44, height: 44)
                }

                // Step forward
                Button {
                    player.stepForward()
                } label: {
                    Image(systemName: "forward.frame.fill")
                        .font(.title3)
                }

                // Skip to end
                Button {
                    player.seekToEnd()
                } label: {
                    Image(systemName: "forward.end.fill")
                        .font(.title3)
                }

                Spacer()

                // Loop toggle
                Button {
                    player.isLooping.toggle()
                } label: {
                    Image(systemName: player.isLooping ? "repeat.1" : "repeat")
                        .font(.title3)
                        .foregroundColor(player.isLooping ? .accentColor : .secondary)
                }
            }
            .foregroundColor(.primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

/// Draggable scrub bar for seeking through the video.
struct ScrubBar: View {
    @Binding var currentTime: Double
    let duration: Double
    let onSeek: (Double) -> Void

    @State private var isDragging = false

    var body: some View {
        GeometryReader { geo in
            let progress = duration > 0 ? currentTime / duration : 0
            let thumbX = progress * geo.size.width

            ZStack(alignment: .leading) {
                // Track background
                Capsule()
                    .fill(Color.secondary.opacity(0.2))
                    .frame(height: 4)

                // Played progress
                Capsule()
                    .fill(Color.accentColor)
                    .frame(width: thumbX, height: 4)

                // Thumb
                Circle()
                    .fill(Color.white)
                    .frame(width: isDragging ? 16 : 12, height: isDragging ? 16 : 12)
                    .shadow(radius: 2)
                    .offset(x: thumbX - (isDragging ? 8 : 6))
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        isDragging = true
                        let ratio = max(0, min(1, value.location.x / geo.size.width))
                        let time = ratio * duration
                        currentTime = time
                        onSeek(time)
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )
        }
        .frame(height: 20)
        .animation(.easeOut(duration: 0.15), value: isDragging)
    }
}
#endif
