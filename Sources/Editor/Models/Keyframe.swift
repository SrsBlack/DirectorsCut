import Foundation

/// A single keyframe point in an animation.
public struct Keyframe: Identifiable, Codable, Equatable {
    public let id: UUID
    public var time: Double
    public var value: Double
    public var interpolation: Interpolation

    public enum Interpolation: String, Codable, Equatable, CaseIterable {
        case linear
        case easeIn
        case easeOut
        case easeInOut
        case hold     // instant jump, no interpolation
        case bezier

        public var displayName: String {
            switch self {
            case .linear:    return "Linear"
            case .easeIn:    return "Ease In"
            case .easeOut:   return "Ease Out"
            case .easeInOut: return "Ease In/Out"
            case .bezier:    return "Bezier"
            case .hold:      return "Hold"
            }
        }
    }

    public init(
        id: UUID = UUID(),
        time: Double,
        value: Double,
        interpolation: Interpolation = .easeInOut
    ) {
        self.id = id
        self.time = time
        self.value = value
        self.interpolation = interpolation
    }

    /// Interpolate between two keyframes at a given time
    public static func interpolate(from a: Keyframe, to b: Keyframe, at time: Double) -> Double {
        guard a.time != b.time else { return a.value }

        let t = (time - a.time) / (b.time - a.time)
        let clampedT = max(0, min(1, t))

        switch b.interpolation {
        case .linear:
            return a.value + (b.value - a.value) * clampedT
        case .easeIn:
            let curved = clampedT * clampedT
            return a.value + (b.value - a.value) * curved
        case .easeOut:
            let curved = 1 - (1 - clampedT) * (1 - clampedT)
            return a.value + (b.value - a.value) * curved
        case .easeInOut:
            let curved = clampedT < 0.5
                ? 2 * clampedT * clampedT
                : 1 - pow(-2 * clampedT + 2, 2) / 2
            return a.value + (b.value - a.value) * curved
        case .hold:
            return a.value
        case .bezier:
            // Cubic bezier approximation (ease-in-out style)
            let curved = clampedT * clampedT * (3 - 2 * clampedT)
            return a.value + (b.value - a.value) * curved
        }
    }
}

/// A track of keyframes animating a specific property.
public struct KeyframeTrack: Identifiable, Codable, Equatable {
    public let id: UUID
    public var property: AnimatableProperty
    public var keyframes: [Keyframe]

    public enum AnimatableProperty: String, Codable, Equatable, CaseIterable {
        case positionX
        case positionY
        case scaleX
        case scaleY
        case rotation
        case opacity
        case volume

        public var displayName: String {
            switch self {
            case .positionX: return "Position X"
            case .positionY: return "Position Y"
            case .scaleX:    return "Scale X"
            case .scaleY:    return "Scale Y"
            case .rotation:  return "Rotation"
            case .opacity:   return "Opacity"
            case .volume:    return "Volume"
            }
        }
    }

    public init(
        id: UUID = UUID(),
        property: AnimatableProperty,
        keyframes: [Keyframe] = []
    ) {
        self.id = id
        self.property = property
        self.keyframes = keyframes
    }

    /// Get the interpolated value at a given time
    public func value(at time: Double) -> Double? {
        guard !keyframes.isEmpty else { return nil }

        let sorted = keyframes.sorted { $0.time < $1.time }

        // Before first keyframe
        if time <= sorted.first!.time { return sorted.first!.value }

        // After last keyframe
        if time >= sorted.last!.time { return sorted.last!.value }

        // Find the two surrounding keyframes
        for i in 0..<(sorted.count - 1) {
            if time >= sorted[i].time && time < sorted[i + 1].time {
                return Keyframe.interpolate(from: sorted[i], to: sorted[i + 1], at: time)
            }
        }

        return sorted.last!.value
    }

    /// Add a keyframe, maintaining chronological order
    public mutating func addKeyframe(_ keyframe: Keyframe) {
        keyframes.append(keyframe)
        keyframes.sort { $0.time < $1.time }
    }

    /// Remove a keyframe by ID
    public mutating func removeKeyframe(id: UUID) {
        keyframes.removeAll { $0.id == id }
    }
}
