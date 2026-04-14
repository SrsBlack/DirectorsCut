#if canImport(UIKit)
import SwiftUI

/// Root content view — delegates to the main editor layout.
public struct ContentView: View {
    public init() {}

    public var body: some View {
        EditorLayout()
    }
}
#endif
