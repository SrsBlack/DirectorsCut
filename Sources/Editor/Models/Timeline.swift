import Foundation

/// The timeline is the core data structure of the editor.
/// It holds all tracks, transitions, and global settings.
public struct Timeline: Codable, Equatable {
    public var tracks: [Track]
    public var transitions: [TransitionEntry]
    public var textOverlays: [TextClip]
    public var framerate: Double
    public var resolution: Resolution

    /// A transition placed between two clips
    public struct TransitionEntry: Identifiable, Codable, Equatable {
        public let id: UUID
        public var transition: Transition
        /// ID of the clip that precedes the transition
        public var fromClipId: UUID
        /// ID of the clip that follows the transition
        public var toClipId: UUID
        public var trackId: UUID

        public init(
            id: UUID = UUID(),
            transition: Transition,
            fromClipId: UUID,
            toClipId: UUID,
            trackId: UUID
        ) {
            self.id = id
            self.transition = transition
            self.fromClipId = fromClipId
            self.toClipId = toClipId
            self.trackId = trackId
        }
    }

    public struct Resolution: Codable, Equatable {
        public var width: Int
        public var height: Int

        public init(width: Int, height: Int) {
            self.width = width
            self.height = height
        }

        public static let hd720 = Resolution(width: 1280, height: 720)
        public static let hd1080 = Resolution(width: 1920, height: 1080)
        public static let uhd4K = Resolution(width: 3840, height: 2160)

        // Social media formats
        public static let portrait1080 = Resolution(width: 1080, height: 1920) // 9:16
        public static let square1080 = Resolution(width: 1080, height: 1080)   // 1:1
        public static let portrait4x5 = Resolution(width: 1080, height: 1350)  // 4:5

        public var aspectRatio: Double {
            Double(width) / Double(height)
        }

        public var displayName: String {
            switch (width, height) {
            case (1280, 720): return "720p HD"
            case (1920, 1080): return "1080p Full HD"
            case (3840, 2160): return "4K Ultra HD"
            case (1080, 1920): return "1080p Vertical"
            case (1080, 1080): return "1080p Square"
            case (1080, 1350): return "1080p 4:5"
            default: return "\(width) x \(height)"
            }
        }
    }

    public init(
        tracks: [Track] = [],
        transitions: [TransitionEntry] = [],
        textOverlays: [TextClip] = [],
        framerate: Double = 30.0,
        resolution: Resolution = .hd1080
    ) {
        self.tracks = tracks
        self.transitions = transitions
        self.textOverlays = textOverlays
        self.framerate = framerate
        self.resolution = resolution
    }

    /// Total duration of the timeline (longest track)
    public var duration: Double {
        tracks.map(\.duration).max() ?? 0
    }

    /// All video tracks
    public var videoTracks: [Track] {
        tracks.filter { $0.type == .video }
    }

    /// All audio tracks
    public var audioTracks: [Track] {
        tracks.filter { $0.type == .audio }
    }

    /// All text/overlay tracks
    public var textTracks: [Track] {
        tracks.filter { $0.type == .text }
    }

    /// Add a new track
    public mutating func addTrack(_ track: Track) {
        tracks.append(track)
    }

    /// Remove a track by ID
    @discardableResult
    public mutating func removeTrack(id: UUID) -> Track? {
        guard let index = tracks.firstIndex(where: { $0.id == id }) else { return nil }
        return tracks.remove(at: index)
    }

    /// Find a track by ID
    public func track(id: UUID) -> Track? {
        tracks.first { $0.id == id }
    }

    /// Find the track and clip for a given clip ID
    public func findClip(id: UUID) -> (trackIndex: Int, clipIndex: Int)? {
        for (trackIdx, track) in tracks.enumerated() {
            if let clipIdx = track.clipIndex(id: id) {
                return (trackIdx, clipIdx)
            }
        }
        return nil
    }

    /// Add a transition between two clips
    public mutating func addTransition(_ entry: TransitionEntry) {
        transitions.append(entry)
    }

    /// Remove a transition by ID
    public mutating func removeTransition(id: UUID) {
        transitions.removeAll { $0.id == id }
    }

    // MARK: - Text overlays

    /// Add a text overlay at the current timeline end (or a given time).
    public mutating func addTextOverlay(_ text: TextClip) {
        textOverlays.append(text)
        textOverlays.sort { $0.timelineStart < $1.timelineStart }
    }

    /// Remove a text overlay by ID.
    @discardableResult
    public mutating func removeTextOverlay(id: UUID) -> TextClip? {
        guard let idx = textOverlays.firstIndex(where: { $0.id == id }) else { return nil }
        return textOverlays.remove(at: idx)
    }

    /// Update a text overlay in place.
    public mutating func updateTextOverlay(_ updated: TextClip) {
        guard let idx = textOverlays.firstIndex(where: { $0.id == updated.id }) else { return }
        textOverlays[idx] = updated
    }

    /// Text overlays visible at a given time.
    public func textOverlays(at time: Double) -> [TextClip] {
        textOverlays.filter { time >= $0.timelineStart && time < $0.timelineEnd }
    }

    /// Create a default timeline with one video and one audio track
    public static func defaultTimeline() -> Timeline {
        Timeline(tracks: [
            Track(name: "Video 1", type: .video),
            Track(name: "Audio 1", type: .audio),
        ])
    }
}
