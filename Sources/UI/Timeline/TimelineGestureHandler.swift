#if canImport(UIKit)
import UIKit
import Editor

/// Handles complex gesture interactions on the timeline (pinch to zoom, snapping, haptics).
public final class TimelineGestureHandler {
    /// Snap threshold in points - clips will snap when within this distance
    public static let snapThreshold: CGFloat = 8

    /// Check if a position should snap to nearby clips or markers
    public static func snapPosition(
        time: Double,
        pixelsPerSecond: Double,
        snapTargets: [Double]
    ) -> Double? {
        let threshold = Double(snapThreshold) / pixelsPerSecond

        for target in snapTargets {
            if abs(time - target) < threshold {
                HapticFeedbackHelper.snap()
                return target
            }
        }
        return nil
    }

    /// Generate snap targets from a timeline's clips
    // FIX(audit-2026-05-09 #A2-gap): `excluding` is the external argument label;
    // `clipId` is the in-body name. The original code used `clip.id != excluding`
    // which references the label, not the parameter — a Swift compile error hidden
    // behind the UIKit canImport guard that causes CI to silently skip this file.
    public static func snapTargets(from tracks: [Track], excluding clipId: UUID? = nil) -> [Double] {
        var targets: Set<Double> = [0] // Always snap to 0

        for track in tracks {
            for clip in track.clips where clip.id != clipId {
                targets.insert(clip.timelineStart)
                targets.insert(clip.timelineEnd)
            }
        }

        return Array(targets).sorted()
    }
}

#endif
