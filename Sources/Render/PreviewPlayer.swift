import AVFoundation
import Combine

/// Manages real-time video preview playback.
@MainActor
public final class PreviewPlayer: ObservableObject {
    @Published public var isPlaying = false
    @Published public var currentTime: Double = 0
    @Published public var duration: Double = 0
    @Published public var isLooping = false

    public let player = AVPlayer()
    private var timeObserver: Any?
    private var statusObserver: NSKeyValueObservation?
    // FIX(audit-2026-05-09 #A9): capture NotificationCenter observer tokens so they
    // can be removed in deinit. Previously the token was discarded, leaving the block
    // registered in NotificationCenter forever (the [weak self] prevented a retain
    // cycle but the center still held the block).
    private var notificationObservers: [NSObjectProtocol] = []

    public init() {
        setupTimeObserver()
    }

    deinit {
        if let timeObserver {
            player.removeTimeObserver(timeObserver)
        }
        notificationObservers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    /// Load a composition for preview playback
    public func loadComposition(_ result: CompositionBuilder.CompositionResult) {
        let playerItem = AVPlayerItem(asset: result.composition)
        playerItem.videoComposition = result.videoComposition
        playerItem.audioMix = result.audioMix

        player.replaceCurrentItem(with: playerItem)
        duration = result.composition.duration.seconds

        statusObserver = playerItem.observe(\.status) { [weak self] item, _ in
            Task { @MainActor in
                if item.status == .readyToPlay {
                    self?.duration = item.duration.seconds
                }
            }
        }

        // FIX(audit-2026-05-09 #A9): store token so removeObserver can be called in deinit.
        let observer = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                if self.isLooping {
                    self.seek(to: 0)
                    self.play()
                } else {
                    self.isPlaying = false
                }
            }
        }
        notificationObservers.append(observer)
    }

    /// Play or resume playback
    public func play() {
        player.play()
        isPlaying = true
    }

    /// Pause playback
    public func pause() {
        player.pause()
        isPlaying = false
    }

    /// Toggle play/pause
    public func togglePlayPause() {
        if isPlaying { pause() } else { play() }
    }

    /// Seek to a specific time (in seconds)
    public func seek(to time: Double) {
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        player.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
        currentTime = time
    }

    /// Seek to the beginning
    public func seekToStart() {
        seek(to: 0)
    }

    /// Seek to the end
    public func seekToEnd() {
        seek(to: duration)
    }

    /// Step forward by one frame (at 30fps)
    public func stepForward(framerate: Double = 30) {
        let frameTime = 1.0 / framerate
        seek(to: min(currentTime + frameTime, duration))
    }

    /// Step backward by one frame (at 30fps)
    public func stepBackward(framerate: Double = 30) {
        let frameTime = 1.0 / framerate
        seek(to: max(currentTime - frameTime, 0))
    }

    // MARK: - Private

    private func setupTimeObserver() {
        let interval = CMTime(seconds: 1.0 / 30.0, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor in
                self?.currentTime = time.seconds
            }
        }
    }
}
