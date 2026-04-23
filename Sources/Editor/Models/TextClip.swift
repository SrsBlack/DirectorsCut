import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// A styled text element placed on the timeline.
/// Text clips live on text-type tracks and render as overlays.
public struct TextClip: Identifiable, Codable, Equatable {
    public let id: UUID
    public var text: String
    public var style: TextStyle
    public var timelineStart: Double
    public var duration: Double
    public var position: TextPosition

    public init(
        id: UUID = UUID(),
        text: String = "Text",
        style: TextStyle = .init(),
        timelineStart: Double = 0,
        duration: Double = 3.0,
        position: TextPosition = .center
    ) {
        self.id = id
        self.text = text
        self.style = style
        self.timelineStart = timelineStart
        self.duration = duration
        self.position = position
    }

    public var timelineEnd: Double { timelineStart + duration }
}

/// Visual styling for text overlays.
public struct TextStyle: Codable, Equatable {
    public var fontName: String
    public var fontSize: Double
    public var fontWeight: FontWeight
    public var textColor: CodableColor
    public var backgroundColor: CodableColor?
    public var strokeColor: CodableColor?
    public var strokeWidth: Double
    public var shadowEnabled: Bool
    public var shadowRadius: Double
    public var alignment: TextAlignment
    public var animation: TextAnimation

    public enum FontWeight: String, Codable, Equatable, CaseIterable {
        case thin, light, regular, medium, semibold, bold, heavy, black
    }

    public enum TextAlignment: String, Codable, Equatable, CaseIterable {
        case left, center, right
    }

    public enum TextAnimation: String, Codable, Equatable, CaseIterable {
        case none
        case fadeIn
        case fadeOut
        case fadeInOut
        case typewriter
        case slideUp
        case slideDown
        case scaleUp
        case bounce

        public var displayName: String {
            switch self {
            case .none:       return "None"
            case .fadeIn:     return "Fade In"
            case .fadeOut:    return "Fade Out"
            case .fadeInOut:  return "Fade In/Out"
            case .typewriter: return "Typewriter"
            case .slideUp:    return "Slide Up"
            case .slideDown:  return "Slide Down"
            case .scaleUp:    return "Scale Up"
            case .bounce:     return "Bounce"
            }
        }
    }

    public init(
        fontName: String = "SF Pro",
        fontSize: Double = 32,
        fontWeight: FontWeight = .bold,
        textColor: CodableColor = .white,
        backgroundColor: CodableColor? = nil,
        strokeColor: CodableColor? = nil,
        strokeWidth: Double = 0,
        shadowEnabled: Bool = true,
        shadowRadius: Double = 4,
        alignment: TextAlignment = .center,
        animation: TextAnimation = .fadeInOut
    ) {
        self.fontName = fontName
        self.fontSize = fontSize
        self.fontWeight = fontWeight
        self.textColor = textColor
        self.backgroundColor = backgroundColor
        self.strokeColor = strokeColor
        self.strokeWidth = strokeWidth
        self.shadowEnabled = shadowEnabled
        self.shadowRadius = shadowRadius
        self.alignment = alignment
        self.animation = animation
    }

    // MARK: - Presets

    public static let title = TextStyle(fontSize: 48, fontWeight: .heavy, animation: .scaleUp)
    public static let subtitle = TextStyle(fontSize: 28, fontWeight: .medium, animation: .fadeInOut)
    public static let caption = TextStyle(fontSize: 20, fontWeight: .regular, animation: .fadeIn)
    public static let lowerThird = TextStyle(
        fontSize: 24, fontWeight: .semibold,
        backgroundColor: CodableColor(r: 0, g: 0, b: 0, a: 0.6),
        animation: .slideUp
    )

    public static let presets: [(name: String, style: TextStyle)] = [
        ("Title",       .title),
        ("Subtitle",    .subtitle),
        ("Caption",     .caption),
        ("Lower Third", .lowerThird),
    ]
}

/// Screen position for a text overlay.
public enum TextPosition: String, Codable, Equatable, CaseIterable {
    case topLeft, topCenter, topRight
    case centerLeft, center, centerRight
    case bottomLeft, bottomCenter, bottomRight

    public var displayName: String {
        switch self {
        case .topLeft:      return "Top Left"
        case .topCenter:    return "Top Center"
        case .topRight:     return "Top Right"
        case .centerLeft:   return "Center Left"
        case .center:       return "Center"
        case .centerRight:  return "Center Right"
        case .bottomLeft:   return "Bottom Left"
        case .bottomCenter: return "Bottom Center"
        case .bottomRight:  return "Bottom Right"
        }
    }
}

/// A platform-agnostic RGBA color for serialization.
public struct CodableColor: Codable, Equatable {
    public var r: Double, g: Double, b: Double, a: Double

    public init(r: Double, g: Double, b: Double, a: Double = 1) {
        self.r = r; self.g = g; self.b = b; self.a = a
    }

    public static let white = CodableColor(r: 1, g: 1, b: 1)
    public static let black = CodableColor(r: 0, g: 0, b: 0)
    public static let red   = CodableColor(r: 1, g: 0, b: 0)
    public static let yellow = CodableColor(r: 1, g: 1, b: 0)
}
