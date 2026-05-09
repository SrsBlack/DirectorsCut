import Foundation
import CoreGraphics

/// AI-powered object tracking using Vision framework.
/// Tracks objects across frames for pinning text/graphics to motion.
// FIX(audit-2026-05-09 #A14): @MainActor added for consistency with CaptionGenerator.swift:5.
@MainActor
public final class ObjectTracker {
    public struct TrackedRegion {
        public let frame: Int
        public let boundingBox: CGRect
        public let confidence: Float
    }

    public init() {}

    /// Track an object defined by an initial bounding box across video frames.
    public func trackObject(
        in videoURL: URL,
        initialBox: CGRect,
        startTime: Double,
        duration: Double,
        progress: @escaping (Double) -> Void
    ) async throws -> [TrackedRegion] {
        // Vision VNTrackObjectRequest integration in Phase 3
        // Will use VNSequenceRequestHandler for frame-to-frame tracking
        return []
    }
}
