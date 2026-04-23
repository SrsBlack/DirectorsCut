import Foundation
import Editor

/// Color grading parameters used to drive the Metal color-correction shader.
public struct ColorGradingParameters: Codable, Equatable {
    // Exposure & tone
    public var exposure: Float      // -3.0 … +3.0  (0 = no change)
    public var brightness: Float    // -1.0 … +1.0  (0 = no change)
    public var contrast: Float      //  0.0 … 4.0   (1 = no change)
    public var highlights: Float    // -1.0 … +1.0  (0 = no change)
    public var shadows: Float       // -1.0 … +1.0  (0 = no change)

    // Color
    public var saturation: Float    //  0.0 … 4.0   (1 = no change)
    public var temperature: Float   // 1000 … 40000 K (6500 = neutral daylight)
    public var tint: Float          // -1.0 … +1.0  (0 = no change)

    public init(
        exposure: Float = 0,
        brightness: Float = 0,
        contrast: Float = 1,
        highlights: Float = 0,
        shadows: Float = 0,
        saturation: Float = 1,
        temperature: Float = 6500,
        tint: Float = 0
    ) {
        self.exposure = exposure
        self.brightness = brightness
        self.contrast = contrast
        self.highlights = highlights
        self.shadows = shadows
        self.saturation = saturation
        self.temperature = temperature
        self.tint = tint
    }

    /// Neutral / no-op settings
    public static let neutral = ColorGradingParameters()

    /// Warm cinematic look
    public static let warmCinematic = ColorGradingParameters(
        exposure: -0.2,
        contrast: 1.15,
        highlights: -0.2,
        shadows: 0.1,
        saturation: 0.9,
        temperature: 7200,
        tint: 0.05
    )

    /// Cool moody look
    public static let coolMoody = ColorGradingParameters(
        exposure: -0.3,
        contrast: 1.2,
        highlights: -0.3,
        shadows: -0.1,
        saturation: 0.8,
        temperature: 5500,
        tint: -0.05
    )

    /// Vintage faded look
    public static let vintage = ColorGradingParameters(
        brightness: 0.05,
        contrast: 0.85,
        highlights: -0.15,
        shadows: 0.2,
        saturation: 0.75,
        temperature: 6800
    )

    /// High-contrast punchy look
    public static let punchy = ColorGradingParameters(
        contrast: 1.3,
        highlights: -0.1,
        shadows: -0.1,
        saturation: 1.3
    )

    /// All built-in presets
    public static let presets: [(name: String, params: ColorGradingParameters)] = [
        ("Neutral",       .neutral),
        ("Warm Cinematic",.warmCinematic),
        ("Cool Moody",    .coolMoody),
        ("Vintage",       .vintage),
        ("Punchy",        .punchy),
    ]
}

/// Applies a color-grading preset or custom parameters to an Effect.
public extension Effect {
    /// Create a color-grading effect from a set of parameters
    static func colorGrading(_ params: ColorGradingParameters = .neutral) -> Effect {
        Effect(type: .colorGrading, parameters: [
            "exposure":    .float(params.exposure),
            "brightness":  .float(params.brightness),
            "contrast":    .float(params.contrast),
            "highlights":  .float(params.highlights),
            "shadows":     .float(params.shadows),
            "saturation":  .float(params.saturation),
            "temperature": .float(params.temperature),
            "tint":        .float(params.tint),
        ])
    }

    /// Extract color-grading parameters from this effect (if type matches)
    var colorGradingParameters: ColorGradingParameters? {
        guard type == .colorGrading || type == .colorCorrection else { return nil }
        return ColorGradingParameters(
            exposure:    parameters["exposure"]?.floatValue    ?? 0,
            brightness:  parameters["brightness"]?.floatValue  ?? 0,
            contrast:    parameters["contrast"]?.floatValue    ?? 1,
            highlights:  parameters["highlights"]?.floatValue  ?? 0,
            shadows:     parameters["shadows"]?.floatValue     ?? 0,
            saturation:  parameters["saturation"]?.floatValue  ?? 1,
            temperature: parameters["temperature"]?.floatValue ?? 6500,
            tint:        parameters["tint"]?.floatValue        ?? 0
        )
    }
}
