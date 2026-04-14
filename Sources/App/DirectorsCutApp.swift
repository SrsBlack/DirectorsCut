#if canImport(UIKit)
import SwiftUI

// NOTE: This file is used by the Xcode app target (DirectorsCut.xcodeproj).
// The @main entry point is declared in the Xcode target, not here.
// See docs/XcodeSetup.md for how to wire this up.

/// Root SwiftUI scene for Directors Cut.
/// The Xcode app target declares @main and calls this.
///
/// Example Xcode entry point (paste into DirectorsCutApp.swift in Xcode target):
///
///     import SwiftUI
///     import UI
///
///     @main
///     struct DirectorsCutApp: App {
///         var body: some Scene {
///             WindowGroup {
///                 EditorLayout()
///                     .preferredColorScheme(.dark)
///             }
///         }
///     }
public struct DirectorsCutScene {
    public static func makeRootView() -> some View {
        EditorLayout()
            .preferredColorScheme(.dark)
    }
}
#endif
