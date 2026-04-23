#if canImport(UIKit)
import SwiftUI

/// Shows available transitions and lets the user pick one + set its duration.
/// Presented when the user taps the gap between two adjacent clips.
public struct TransitionPickerView: View {
    @State private var selectedType: Transition.TransitionType = .crossDissolve
    @State private var duration: Double = 0.5

    let onApply: (Transition) -> Void
    let onCancel: () -> Void

    public init(
        onApply: @escaping (Transition) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.onApply = onApply
        self.onCancel = onCancel
    }

    public var body: some View {
        NavigationView {
            List {
                // Duration control
                Section("Duration") {
                    VStack(spacing: 4) {
                        Slider(value: $duration, in: 0.1...3.0, step: 0.1)
                        Text(String(format: "%.1f seconds", duration))
                            .font(.caption.monospacedDigit())
                            .foregroundColor(.secondary)
                    }
                }

                // Transition types
                Section("Style") {
                    ForEach(Transition.TransitionType.allCases, id: \.self) { type in
                        Button {
                            selectedType = type
                        } label: {
                            HStack(spacing: 12) {
                                TransitionIcon(type: type)
                                    .frame(width: 40, height: 28)

                                Text(displayName(for: type))
                                    .foregroundColor(.primary)

                                Spacer()

                                if selectedType == type {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentColor)
                                }
                            }
                        }
                    }
                }

                // Apply button
                Section {
                    Button {
                        onApply(Transition(type: selectedType, duration: duration))
                    } label: {
                        HStack {
                            Spacer()
                            Text("Apply Transition").fontWeight(.semibold)
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Transition")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
            }
        }
    }

    private func displayName(for type: Transition.TransitionType) -> String {
        switch type {
        case .crossDissolve: return "Cross Dissolve"
        case .fadeToBlack:   return "Fade to Black"
        case .fadeToWhite:   return "Fade to White"
        case .wipeLeft:      return "Wipe Left"
        case .wipeRight:     return "Wipe Right"
        case .wipeUp:        return "Wipe Up"
        case .wipeDown:      return "Wipe Down"
        case .slideLeft:     return "Slide Left"
        case .slideRight:    return "Slide Right"
        case .zoomIn:        return "Zoom In"
        case .zoomOut:       return "Zoom Out"
        }
    }
}

/// Mini animated preview icon for a transition type.
struct TransitionIcon: View {
    let type: Transition.TransitionType

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.blue.opacity(0.5))

            // Show a visual hint of the transition direction
            GeometryReader { geo in
                let w = geo.size.width
                switch type {
                case .crossDissolve:
                    LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing)
                        .cornerRadius(4)
                case .fadeToBlack:
                    LinearGradient(colors: [.blue, .black], startPoint: .leading, endPoint: .trailing)
                        .cornerRadius(4)
                case .fadeToWhite:
                    LinearGradient(colors: [.blue, .white], startPoint: .leading, endPoint: .trailing)
                        .cornerRadius(4)
                case .wipeLeft, .slideLeft:
                    HStack(spacing: 0) {
                        Color.purple.frame(width: w * 0.5)
                        Color.blue
                    }.cornerRadius(4)
                case .wipeRight, .slideRight:
                    HStack(spacing: 0) {
                        Color.blue
                        Color.purple.frame(width: w * 0.5)
                    }.cornerRadius(4)
                case .wipeUp:
                    VStack(spacing: 0) {
                        Color.purple.frame(height: geo.size.height * 0.5)
                        Color.blue
                    }.cornerRadius(4)
                case .wipeDown:
                    VStack(spacing: 0) {
                        Color.blue
                        Color.purple.frame(height: geo.size.height * 0.5)
                    }.cornerRadius(4)
                case .zoomIn, .zoomOut:
                    ZStack {
                        Color.blue
                        Circle()
                            .fill(Color.purple)
                            .frame(width: w * 0.5, height: w * 0.5)
                    }.cornerRadius(4)
                }
            }
        }
    }
}
#endif
