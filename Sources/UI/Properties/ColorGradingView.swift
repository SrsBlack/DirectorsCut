#if canImport(UIKit)
import SwiftUI
import Effects

/// Full colour-grading panel — wheels, sliders, and presets.
public struct ColorGradingView: View {
    @Binding var parameters: ColorGradingParameters
    let onReset: () -> Void

    @State private var activeTab: Tab = .basic

    enum Tab: String, CaseIterable {
        case basic   = "Basic"
        case tone    = "Tone"
        case presets = "Presets"
    }

    public init(parameters: Binding<ColorGradingParameters>, onReset: @escaping () -> Void) {
        self._parameters = parameters
        self.onReset = onReset
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Tab bar
            Picker("Tab", selection: $activeTab) {
                ForEach(Tab.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(8)

            Divider()

            ScrollView {
                switch activeTab {
                case .basic:   basicControls
                case .tone:    toneControls
                case .presets: presetsGrid
                }
            }
        }
    }

    // MARK: - Basic (Exposure, Contrast, Saturation)

    private var basicControls: some View {
        VStack(spacing: 12) {
            gradingSlider("Exposure",    value: $parameters.exposure,    range: -3...3,        neutral: 0)
            gradingSlider("Brightness",  value: $parameters.brightness,  range: -1...1,        neutral: 0)
            gradingSlider("Contrast",    value: $parameters.contrast,    range: 0.5...2,       neutral: 1)
            gradingSlider("Saturation",  value: $parameters.saturation,  range: 0...2,         neutral: 1)
            gradingSlider("Temperature", value: $parameters.temperature,  range: 2000...12000, neutral: 6500, format: "%.0f K")
            gradingSlider("Tint",        value: $parameters.tint,        range: -1...1,        neutral: 0)

            Button("Reset All", role: .destructive) { onReset() }
                .font(.caption)
                .padding(.top, 4)
        }
        .padding(12)
    }

    // MARK: - Tone (Highlights, Shadows)

    private var toneControls: some View {
        VStack(spacing: 12) {
            gradingSlider("Highlights", value: $parameters.highlights, range: -1...1, neutral: 0)
            gradingSlider("Shadows",    value: $parameters.shadows,    range: -1...1, neutral: 0)

            // Histogram placeholder
            GroupBox("Histogram") {
                HistogramPlaceholder()
                    .frame(height: 60)
            }
        }
        .padding(12)
    }

    // MARK: - Presets

    private var presetsGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 12) {
            ForEach(ColorGradingParameters.presets, id: \.name) { preset in
                PresetCard(name: preset.name) {
                    parameters = preset.params
                }
            }
        }
        .padding(12)
    }

    // MARK: - Helpers

    private func gradingSlider(
        _ label: String,
        value: Binding<Float>,
        range: ClosedRange<Float>,
        neutral: Float,
        format: String = "%.2f"
    ) -> some View {
        VStack(spacing: 2) {
            HStack {
                Text(label).font(.caption).foregroundColor(.secondary)
                Spacer()
                Text(String(format: format, value.wrappedValue))
                    .font(.caption.monospacedDigit())
                if value.wrappedValue != neutral {
                    Button("↩") { value.wrappedValue = neutral }
                        .font(.caption2).foregroundColor(.accentColor)
                }
            }
            Slider(value: value, in: range)
                .tint(sliderTint(label))
        }
    }

    private func sliderTint(_ label: String) -> Color {
        switch label {
        case "Temperature": return .orange
        case "Tint":        return .green
        case "Saturation":  return .purple
        default:            return .accentColor
        }
    }
}

// MARK: - Supporting views

private struct PresetCard: View {
    let name: String
    let onApply: () -> Void

    var body: some View {
        Button(action: onApply) {
            VStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.secondary.opacity(0.2))
                    .frame(height: 60)
                Text(name)
                    .font(.caption2)
                    .lineLimit(1)
                    .foregroundColor(.primary)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct HistogramPlaceholder: View {
    var body: some View {
        GeometryReader { geo in
            Canvas { ctx, size in
                // Draw a fake RGB histogram
                let channels: [(Color, Float)] = [
                    (.red,  0.6), (.green, 0.8), (.blue, 0.5)
                ]
                for (color, scale) in channels {
                    var path = Path()
                    path.move(to: CGPoint(x: 0, y: size.height))
                    for x in stride(from: 0, through: size.width, by: 2) {
                        let t = Double(x) / Double(size.width)
                        // Bell-curve-ish shape
                        let y = size.height * (1 - CGFloat(scale) * exp(-pow((t - 0.5) * 4, 2)))
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                    path.addLine(to: CGPoint(x: size.width, y: size.height))
                    path.closeSubpath()
                    ctx.fill(path, with: .color(color.opacity(0.25)))
                    ctx.stroke(path, with: .color(color.opacity(0.5)), lineWidth: 1)
                }
            }
        }
    }
}
#endif
