import Foundation

/// An effect applied to a clip (filter, color adjustment, etc.)
public struct Effect: Identifiable, Codable, Equatable {
    public let id: UUID
    public var type: EffectType
    public var parameters: [String: EffectParameter]
    public var isEnabled: Bool

    public enum EffectType: String, Codable, Equatable {
        // Color
        case colorCorrection
        case colorGrading
        case lut
        case saturation
        case temperature

        // Blur / Sharpen
        case gaussianBlur
        case motionBlur
        case sharpen

        // Stylize
        case vignette
        case chromaKey
        case filmGrain

        // Transform
        case crop
        case flip
        case mirror
    }

    public init(
        id: UUID = UUID(),
        type: EffectType,
        parameters: [String: EffectParameter] = [:],
        isEnabled: Bool = true
    ) {
        self.id = id
        self.type = type
        self.parameters = parameters
        self.isEnabled = isEnabled
    }

    /// Create a default color correction effect
    public static func colorCorrection() -> Effect {
        Effect(type: .colorCorrection, parameters: [
            "brightness": .float(0.0),
            "contrast": .float(1.0),
            "saturation": .float(1.0),
            "temperature": .float(6500),
            "tint": .float(0.0),
            "exposure": .float(0.0),
            "highlights": .float(0.0),
            "shadows": .float(0.0),
        ])
    }

    /// Create a gaussian blur effect
    public static func blur(radius: Float = 10.0) -> Effect {
        Effect(type: .gaussianBlur, parameters: [
            "radius": .float(radius),
        ])
    }

    /// Create a chroma key (green screen) effect
    public static func chromaKey() -> Effect {
        Effect(type: .chromaKey, parameters: [
            "keyColor": .color(0.0, 1.0, 0.0, 1.0),  // green
            "threshold": .float(0.4),
            "smoothing": .float(0.1),
        ])
    }

    /// Create a vignette effect
    public static func vignette(intensity: Float = 0.5) -> Effect {
        Effect(type: .vignette, parameters: [
            "intensity": .float(intensity),
            "radius": .float(0.8),
        ])
    }
}

/// A typed parameter value for an effect
public enum EffectParameter: Codable, Equatable {
    case float(Float)
    case int(Int)
    case bool(Bool)
    case string(String)
    case color(Float, Float, Float, Float) // r, g, b, a
    case point(Double, Double)

    public var floatValue: Float? {
        if case .float(let v) = self { return v }
        return nil
    }

    public var intValue: Int? {
        if case .int(let v) = self { return v }
        return nil
    }

    public var boolValue: Bool? {
        if case .bool(let v) = self { return v }
        return nil
    }
}
