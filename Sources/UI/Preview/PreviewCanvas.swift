#if canImport(UIKit)
import SwiftUI
import AVKit
import Render

/// Video preview canvas showing the current frame.
public struct PreviewCanvas: View {
    @ObservedObject var player: PreviewPlayer
    let aspectRatio: Double

    public init(player: PreviewPlayer, aspectRatio: Double = 16.0 / 9.0) {
        self.player = player
        self.aspectRatio = aspectRatio
    }

    public var body: some View {
        ZStack {
            Color.black

            VideoPlayerView(player: player.player)
                .aspectRatio(aspectRatio, contentMode: .fit)

            // Time overlay
            VStack {
                Spacer()
                HStack {
                    Text(formatTime(player.currentTime))
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial)
                        .cornerRadius(4)

                    Spacer()

                    Text(formatTime(player.duration))
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial)
                        .cornerRadius(4)
                }
                .padding(8)
            }
        }
        .cornerRadius(8)
    }

    private func formatTime(_ time: Double) -> String {
        let mins = Int(time) / 60
        let secs = Int(time) % 60
        let frames = Int((time - Double(Int(time))) * 30)
        return String(format: "%d:%02d:%02d", mins, secs, frames)
    }
}

/// UIKit AVPlayerLayer wrapper for SwiftUI
struct VideoPlayerView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerUIView {
        let view = PlayerUIView()
        view.player = player
        return view
    }

    func updateUIView(_ uiView: PlayerUIView, context: Context) {
        uiView.player = player
    }

    class PlayerUIView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }

        // FIX(audit-2026-05-09 #A3): replaced force-cast with guarded cast.
        // layerClass override makes this safe at runtime, but a misuse of PlayerUIView
        // outside its UIKit hierarchy would previously crash silently. assertionFailure
        // surfaces the invariant violation in debug builds.
        var playerLayer: AVPlayerLayer {
            guard let l = layer as? AVPlayerLayer else {
                assertionFailure("PreviewCanvas.layerClass should be AVPlayerLayer")
                return AVPlayerLayer()
            }
            return l
        }

        var player: AVPlayer? {
            get { playerLayer.player }
            set {
                playerLayer.player = newValue
                playerLayer.videoGravity = .resizeAspect
            }
        }
    }
}
#endif
