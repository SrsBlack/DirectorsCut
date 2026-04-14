import Foundation

/// A Directors Cut project containing a timeline and metadata.
public struct Project: Identifiable, Codable {
    public let id: UUID
    public var name: String
    public var timeline: Timeline
    public var createdAt: Date
    public var modifiedAt: Date
    public var aspectRatioPreset: AspectRatioPreset

    public enum AspectRatioPreset: String, Codable, CaseIterable {
        case landscape16x9 = "16:9"
        case portrait9x16 = "9:16"
        case square1x1 = "1:1"
        case portrait4x5 = "4:5"
        case custom = "Custom"

        public var displayName: String {
            switch self {
            case .landscape16x9: return "16:9 Landscape"
            case .portrait9x16: return "9:16 Portrait (Reels/TikTok)"
            case .square1x1: return "1:1 Square"
            case .portrait4x5: return "4:5 Portrait"
            case .custom: return "Custom"
            }
        }

        public var resolution: Timeline.Resolution {
            switch self {
            case .landscape16x9: return .hd1080
            case .portrait9x16: return .portrait1080
            case .square1x1: return .square1080
            case .portrait4x5: return .portrait4x5
            case .custom: return .hd1080
            }
        }
    }

    public init(
        id: UUID = UUID(),
        name: String = "Untitled Project",
        timeline: Timeline = .defaultTimeline(),
        createdAt: Date = Date(),
        modifiedAt: Date = Date(),
        aspectRatioPreset: AspectRatioPreset = .landscape16x9
    ) {
        self.id = id
        self.name = name
        self.timeline = timeline
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.aspectRatioPreset = aspectRatioPreset
        self.timeline.resolution = aspectRatioPreset.resolution
    }

    /// Touch the modification date
    public mutating func markModified() {
        modifiedAt = Date()
    }
}
