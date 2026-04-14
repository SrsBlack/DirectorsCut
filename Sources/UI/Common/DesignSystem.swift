#if canImport(UIKit)
import SwiftUI

/// Directors Cut design system - colors, typography, and spacing.
public enum DCTheme {
    // MARK: - Colors

    public enum Colors {
        public static let background = Color(uiColor: .systemBackground)
        public static let secondaryBackground = Color(uiColor: .secondarySystemBackground)
        public static let tertiaryBackground = Color(uiColor: .tertiarySystemBackground)

        public static let accent = Color.blue
        public static let destructive = Color.red

        // Track colors
        public static let videoTrack = Color(red: 0.2, green: 0.5, blue: 0.9)
        public static let audioTrack = Color(red: 0.2, green: 0.7, blue: 0.4)
        public static let textTrack = Color(red: 0.9, green: 0.6, blue: 0.2)

        // Timeline
        public static let playhead = Color.red
        public static let selection = Color.white
        public static let snapGuide = Color.yellow.opacity(0.7)

        // Export
        public static let success = Color.green
    }

    // MARK: - Typography

    public enum Typography {
        public static let title = Font.system(size: 20, weight: .bold, design: .default)
        public static let headline = Font.system(size: 17, weight: .semibold, design: .default)
        public static let body = Font.system(size: 15, weight: .regular, design: .default)
        public static let caption = Font.system(size: 12, weight: .regular, design: .default)
        public static let mono = Font.system(size: 12, weight: .medium, design: .monospaced)
        public static let timecode = Font.system(size: 14, weight: .medium, design: .monospaced)
    }

    // MARK: - Spacing

    public enum Spacing {
        public static let xs: CGFloat = 4
        public static let sm: CGFloat = 8
        public static let md: CGFloat = 12
        public static let lg: CGFloat = 16
        public static let xl: CGFloat = 24
        public static let xxl: CGFloat = 32
    }

    // MARK: - Corner Radius

    public enum CornerRadius {
        public static let small: CGFloat = 4
        public static let medium: CGFloat = 8
        public static let large: CGFloat = 12
        public static let pill: CGFloat = 20
    }

    // MARK: - Track Dimensions

    public enum TrackHeight {
        public static let compact: CGFloat = 44
        public static let regular: CGFloat = 56
        public static let expanded: CGFloat = 80
    }
}
#endif
