import Foundation

/// Detects scene changes/cuts in video for auto-splitting long clips.
// FIX(audit-2026-05-09 #A14): @MainActor added for consistency with CaptionGenerator.swift:5.
@MainActor
public final class SceneDetector {
    public struct SceneChange {
        public let time: Double
        public let confidence: Float
    }

    public init() {}

    /// Detect scene changes in a video file.
    /// Uses a combination of histogram comparison and optional ML refinement.
    public func detectScenes(
        in videoURL: URL,
        sensitivity: Float = 0.5,
        progress: @escaping (Double) -> Void
    ) async throws -> [SceneChange] {
        // Phase 3 implementation
        // Will analyze frame-to-frame histogram differences
        return []
    }
}
