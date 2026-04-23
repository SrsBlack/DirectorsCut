#if canImport(UIKit)
import SwiftUI

/// Root view: shows the project browser, switches to the editor when a project is opened.
public struct ContentView: View {
    @StateObject private var appState = AppState()

    public init() {}

    public var body: some View {
        Group {
            if appState.isEditorActive {
                EditorLayout(appState: appState)
            } else {
                ProjectBrowserView(
                    onOpenProject: { url in appState.openProject(from: url) },
                    onNewProject:  { proj in appState.startNewProject(proj) }
                )
            }
        }
        .preferredColorScheme(.dark)
    }
}
#endif
