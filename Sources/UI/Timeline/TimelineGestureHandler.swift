#if canImport(UIKit)
import UIKit

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
    public static func snapTargets(from tracks: [Track], excluding clipId: UUID? = nil) -> [Double] {
        var targets: Set<Double> = [0] // Always snap to 0

        for track in tracks {
            for clip in track.clips where clip.id != excluding {
                targets.insert(clip.timelineStart)
                targets.insert(clip.timelineEnd)
            }
        }

        return Array(targets).sorted()
    }
}

/// Haptic feedback helper for timeline interactions
public struct HapticFeedbackHelper {
    private static let impactLight = UIImpactFeedbackGenerator(style: .light)
    private static let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private static let selection = UISelectionFeedbackGenerator()

    /// Snap feedback - light haptic
    public static func snap() {
        impactLight.impactOccurred()
    }

    /// Selection feedback
    public static func select() {
        selection.selectionChanged()
    }

    /// Split feedback - medium haptic
    public static func split() {
        impactMedium.impactOccurred()
    }

    /// Prepare generators for upcoming interactions
    public static func prepare() {
        impactLight.prepare()
        impactMedium.prepare()
        selection.prepare()
    }
}
#endif
