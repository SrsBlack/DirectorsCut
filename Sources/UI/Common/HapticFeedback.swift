#if canImport(UIKit)
import UIKit

/// Centralised haptic feedback for the editor.
///
/// Use light haptics for snapping and small confirmations, medium for actions
/// like splits/cuts, and selection feedback for moving between clips.
public struct HapticFeedbackHelper {
    private static let impactLight  = UIImpactFeedbackGenerator(style: .light)
    private static let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private static let impactHeavy  = UIImpactFeedbackGenerator(style: .heavy)
    private static let selection    = UISelectionFeedbackGenerator()
    private static let notification = UINotificationFeedbackGenerator()

    // MARK: - Editor interactions

    /// Snap feedback — light haptic when a clip snaps to a target.
    public static func snap() {
        impactLight.impactOccurred()
    }

    /// Selection changed — light click for moving between clips/tracks.
    public static func select() {
        selection.selectionChanged()
    }

    /// Cut / split — medium impact for destructive-feeling actions.
    public static func split() {
        impactMedium.impactOccurred()
    }

    /// Drop / commit — heavy impact for committing a drag operation.
    public static func drop() {
        impactHeavy.impactOccurred()
    }

    // MARK: - System feedback

    /// Successful operation (export complete, save complete).
    public static func success() {
        notification.notificationOccurred(.success)
    }

    /// Warning (e.g. trim hits maximum source length).
    public static func warning() {
        notification.notificationOccurred(.warning)
    }

    /// Error (e.g. export failed).
    public static func error() {
        notification.notificationOccurred(.error)
    }

    // MARK: - Lifecycle

    /// Pre-warm generators ahead of an interaction sequence to reduce latency.
    public static func prepare() {
        impactLight.prepare()
        impactMedium.prepare()
        impactHeavy.prepare()
        selection.prepare()
        notification.prepare()
    }
}
#endif
