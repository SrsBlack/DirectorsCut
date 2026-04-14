import Foundation
import CoreMedia

/// A media clip placed on a track in the timeline.
public struct Clip: Identifiable, Codable, Equatable {
    public let id: UUID
    public var sourceURL: URL
    public var mediaType: MediaType

    /// Where this clip starts on the timeline
    public var timelineStart: Double

    /// Start offset within the source media (for trimming the beginning)
    public var sourceStartTime: Double

    /// Duration of the clip as it appears on the timeline
    public var duration: Double

    /// Original untrimmed duration of the source media
    public var sourceDuration: Double

    /// Playback speed multiplier (1.0 = normal, 0.5 = half speed, 2.0 = double)
    public var speed: Double

    /// Volume level for audio (0.0 to 1.0)
    public var volume: Float

    /// Whether audio is muted
    public var isMuted: Bool

    /// Opacity (0.0 to 1.0)
    public var opacity: Float

    /// Transform applied to the clip
    public var transform: ClipTransform

    /// Effects applied to this clip
    public var effects: [Effect]

    /// Keyframe animations on this clip's properties
    public var keyframes: [KeyframeTrack]

    /// Display name (derived from file name or user-set)
    public var name: String

    public enum MediaType: String, Codable, Equatable {
        case video
        case audio
        case image
    }

    public init(
        id: UUID = UUID(),
        sourceURL: URL,
        mediaType: MediaType,
        timelineStart: Double = 0,
        sourceStartTime: Double = 0,
        duration: Double,
        sourceDuration: Double,
        speed: Double = 1.0,
        volume: Float = 1.0,
        isMuted: Bool = false,
        opacity: Float = 1.0,
        transform: ClipTransform = ClipTransform(),
        effects: [Effect] = [],
        keyframes: [KeyframeTrack] = [],
        name: String = ""
    ) {
        self.id = id
        self.sourceURL = sourceURL
        self.mediaType = mediaType
        self.timelineStart = timelineStart
        self.sourceStartTime = sourceStartTime
        self.duration = duration
        self.sourceDuration = sourceDuration
        self.speed = speed
        self.volume = volume
        self.isMuted = isMuted
        self.opacity = opacity
        self.transform = transform
        self.effects = effects
        self.keyframes = keyframes
        self.name = name
    }

    /// The end time of this clip on the timeline
    public var timelineEnd: Double {
        timelineStart + duration
    }

    /// The effective source end time considering speed
    public var sourceEndTime: Double {
        sourceStartTime + (duration * speed)
    }

    /// Maximum duration this clip can be extended to (based on source and speed)
    public var maxDuration: Double {
        (sourceDuration - sourceStartTime) / speed
    }
}

/// Spatial transform for a clip (position, scale, rotation)
public struct ClipTransform: Codable, Equatable {
    public var positionX: Double
    public var positionY: Double
    public var scaleX: Double
    public var scaleY: Double
    public var rotation: Double  // degrees

    public init(
        positionX: Double = 0,
        positionY: Double = 0,
        scaleX: Double = 1.0,
        scaleY: Double = 1.0,
        rotation: Double = 0
    ) {
        self.positionX = positionX
        self.positionY = positionY
        self.scaleX = scaleX
        self.scaleY = scaleY
        self.rotation = rotation
    }

    public static let identity = ClipTransform()
}
