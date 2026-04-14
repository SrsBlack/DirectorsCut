#if canImport(UIKit)
import SwiftUI

/// Directors Cut - Free Premium Video Editor
/// No watermarks. No subscriptions. No data harvesting.
@main
struct DirectorsCutApp: App {
    var body: some Scene {
        WindowGroup {
            EditorLayout()
                .preferredColorScheme(.dark)
        }
    }
}
#endif
