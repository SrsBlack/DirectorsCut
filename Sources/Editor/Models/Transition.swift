import Foundation

/// A transition between two adjacent clips on a track.
public struct Transition: Identifiable, Codable, Equatable {
    public let id: UUID
    public var type: TransitionType
    public var duration: Double
    public var parameters: [String: Float]

    public enum TransitionType: String, Codable, Equatable, CaseIterable {
        case crossDissolve
        case fadeToBlack
        case fadeToWhite
        case wipeLeft
        case wipeRight
        case wipeUp
        case wipeDown
        case slideLeft
        case slideRight
        case zoomIn
        case zoomOut
    }

    public init(
        id: UUID = UUID(),
        type: TransitionType = .crossDissolve,
        duration: Double = 0.5,
        parameters: [String: Float] = [:]
    ) {
        self.id = id
        self.type = type
        self.duration = duration
        self.parameters = parameters
    }

    /// All available transition types with display names
    public static let allTransitions: [(type: TransitionType, name: String)] = [
        (.crossDissolve, "Cross Dissolve"),
        (.fadeToBlack, "Fade to Black"),
        (.fadeToWhite, "Fade to White"),
        (.wipeLeft, "Wipe Left"),
        (.wipeRight, "Wipe Right"),
        (.wipeUp, "Wipe Up"),
        (.wipeDown, "Wipe Down"),
        (.slideLeft, "Slide Left"),
        (.slideRight, "Slide Right"),
        (.zoomIn, "Zoom In"),
        (.zoomOut, "Zoom Out"),
    ]
}
