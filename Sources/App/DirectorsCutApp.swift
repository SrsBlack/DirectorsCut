#if canImport(UIKit)
import SwiftUI

// The Xcode app target provides the @main entry point.
// See docs/XcodeSetup.md for how to wire this up.
//
// Paste this into the Xcode target's entry point file:
//
//     import SwiftUI
//     import UI
//
//     @main
//     struct DirectorsCutApp: App {
//         var body: some Scene {
//             WindowGroup {
//                 ContentView()
//             }
//         }
//     }

/// Helper that returns the root view for the Xcode app target.
public struct DirectorsCutScene {
    public static func makeRootView() -> some View {
        ContentView()
    }
}
#endif
