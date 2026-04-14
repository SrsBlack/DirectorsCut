import Foundation

/// A track in the timeline that holds clips.
public struct Track: Identifiable, Codable, Equatable {
    public let id: UUID
    public var name: String
    public var type: TrackType
    public var clips: [Clip]
    public var isLocked: Bool
    public var isVisible: Bool
    public var isMuted: Bool
    public var volume: Float

    public enum TrackType: String, Codable, Equatable {
        case video
        case audio
        case text
    }

    public init(
        id: UUID = UUID(),
        name: String = "",
        type: TrackType,
        clips: [Clip] = [],
        isLocked: Bool = false,
        isVisible: Bool = true,
        isMuted: Bool = false,
        volume: Float = 1.0
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.clips = clips
        self.isLocked = isLocked
        self.isVisible = isVisible
        self.isMuted = isMuted
        self.volume = volume
    }

    /// Total duration of this track (end time of the last clip)
    public var duration: Double {
        clips.map(\.timelineEnd).max() ?? 0
    }

    /// Find a clip at the given time
    public func clip(at time: Double) -> Clip? {
        clips.first { time >= $0.timelineStart && time < $0.timelineEnd }
    }

    /// Find the index of a clip by ID
    public func clipIndex(id: UUID) -> Int? {
        clips.firstIndex { $0.id == id }
    }

    /// Add a clip, maintaining chronological order
    public mutating func addClip(_ clip: Clip) {
        clips.append(clip)
        clips.sort { $0.timelineStart < $1.timelineStart }
    }

    /// Remove a clip by ID
    @discardableResult
    public mutating func removeClip(id: UUID) -> Clip? {
        guard let index = clipIndex(id: id) else { return nil }
        return clips.remove(at: index)
    }

    /// Split a clip at the given timeline time, returning the two resulting clips
    public mutating func splitClip(id: UUID, at time: Double) -> (Clip, Clip)? {
        guard let index = clipIndex(id: id) else { return nil }
        let clip = clips[index]

        guard time > clip.timelineStart && time < clip.timelineEnd else { return nil }

        let splitPoint = time - clip.timelineStart
        let sourceOffset = splitPoint * clip.speed

        var firstHalf = clip
        firstHalf.duration = splitPoint

        var secondHalf = clip
        secondHalf.sourceStartTime = clip.sourceStartTime + sourceOffset
        secondHalf.timelineStart = time
        secondHalf.duration = clip.duration - splitPoint

        // Give the second half a new ID
        let newId = UUID()
        secondHalf = Clip(
            id: newId,
            sourceURL: secondHalf.sourceURL,
            mediaType: secondHalf.mediaType,
            timelineStart: secondHalf.timelineStart,
            sourceStartTime: secondHalf.sourceStartTime,
            duration: secondHalf.duration,
            sourceDuration: secondHalf.sourceDuration,
            speed: secondHalf.speed,
            volume: secondHalf.volume,
            isMuted: secondHalf.isMuted,
            opacity: secondHalf.opacity,
            transform: secondHalf.transform,
            effects: secondHalf.effects,
            keyframes: secondHalf.keyframes,
            name: secondHalf.name
        )

        clips[index] = firstHalf
        clips.insert(secondHalf, at: index + 1)

        return (firstHalf, secondHalf)
    }
}
