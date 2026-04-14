#if canImport(UIKit)
import SwiftUI

/// Displays and edits the parameters of a single effect on a clip.
public struct EffectControls: View {
    let effect: Effect
    let onUpdate: (Effect) -> Void
    let onRemove: () -> Void

    public init(effect: Effect, onUpdate: @escaping (Effect) -> Void, onRemove: @escaping () -> Void) {
        self.effect = effect
        self.onUpdate = onUpdate
        self.onRemove = onRemove
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Effect header
            HStack {
                Image(systemName: iconName)
                    .foregroundColor(.accentColor)
                Text(effectTitle)
                    .font(.subheadline).fontWeight(.medium)
                Spacer()
                Toggle("", isOn: enabledBinding)
                    .labelsHidden()
                    .scaleEffect(0.85)
                Button(role: .destructive) { onRemove() } label: {
                    Image(systemName: "trash").font(.caption)
                }
                .foregroundColor(.red)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            if effect.isEnabled {
                Divider()
                parameterControls
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
            }
        }
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(10)
    }

    // MARK: - Per-effect parameter UI

    @ViewBuilder
    private var parameterControls: some View {
        switch effect.type {
        case .colorCorrection, .colorGrading:
            colorCorrectionControls

        case .gaussianBlur:
            floatSlider(key: "radius", label: "Radius", range: 0...50)

        case .chromaKey:
            VStack(spacing: 8) {
                floatSlider(key: "threshold", label: "Threshold", range: 0...1)
                floatSlider(key: "smoothing", label: "Smoothing", range: 0...0.5)
            }

        case .vignette:
            VStack(spacing: 8) {
                floatSlider(key: "intensity", label: "Intensity", range: 0...1)
                floatSlider(key: "radius",    label: "Radius",    range: 0...1)
            }

        case .saturation:
            floatSlider(key: "saturation", label: "Saturation", range: 0...4)

        case .temperature:
            floatSlider(key: "temperature", label: "Temperature (K)", range: 2000...12000)

        default:
            Text("No adjustable parameters")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var colorCorrectionControls: some View {
        VStack(spacing: 6) {
            floatSlider(key: "exposure",    label: "Exposure",    range: -3...3)
            floatSlider(key: "brightness",  label: "Brightness",  range: -1...1)
            floatSlider(key: "contrast",    label: "Contrast",    range: 0...4,   neutral: 1)
            floatSlider(key: "highlights",  label: "Highlights",  range: -1...1)
            floatSlider(key: "shadows",     label: "Shadows",     range: -1...1)
            floatSlider(key: "saturation",  label: "Saturation",  range: 0...4,   neutral: 1)
            floatSlider(key: "temperature", label: "Temperature", range: 2000...12000, neutral: 6500)
            floatSlider(key: "tint",        label: "Tint",        range: -1...1)
        }
    }

    // MARK: - Helpers

    private func floatSlider(
        key: String,
        label: String,
        range: ClosedRange<Float>,
        neutral: Float? = nil
    ) -> some View {
        let current = effect.parameters[key]?.floatValue ?? (neutral ?? range.lowerBound)
        return VStack(spacing: 2) {
            HStack {
                Text(label).font(.caption).foregroundColor(.secondary)
                Spacer()
                Text(String(format: "%.2f", current)).font(.caption.monospacedDigit())
                if let neutral, current != neutral {
                    Button("↩") {
                        var updated = effect
                        updated.parameters[key] = .float(neutral)
                        onUpdate(updated)
                    }
                    .font(.caption2)
                    .foregroundColor(.accentColor)
                }
            }
            Slider(value: Binding(
                get: { current },
                set: { newVal in
                    var updated = effect
                    updated.parameters[key] = .float(newVal)
                    onUpdate(updated)
                }
            ), in: range)
        }
    }

    private var enabledBinding: Binding<Bool> {
        Binding(
            get: { effect.isEnabled },
            set: { val in
                var updated = effect
                updated.isEnabled = val
                onUpdate(updated)
            }
        )
    }

    private var effectTitle: String {
        switch effect.type {
        case .colorCorrection:  return "Color Correction"
        case .colorGrading:     return "Color Grading"
        case .gaussianBlur:     return "Blur"
        case .chromaKey:        return "Chroma Key"
        case .vignette:         return "Vignette"
        case .saturation:       return "Saturation"
        case .temperature:      return "Temperature"
        case .motionBlur:       return "Motion Blur"
        case .sharpen:          return "Sharpen"
        case .filmGrain:        return "Film Grain"
        case .crop:             return "Crop"
        case .flip:             return "Flip"
        case .mirror:           return "Mirror"
        case .lut:              return "LUT"
        }
    }

    private var iconName: String {
        switch effect.type {
        case .colorCorrection, .colorGrading: return "slider.horizontal.3"
        case .gaussianBlur, .motionBlur:      return "camera.filters"
        case .chromaKey:                       return "person.crop.rectangle.badge.minus"
        case .vignette:                        return "circle.dashed"
        case .saturation:                      return "drop.halffull"
        case .temperature:                     return "thermometer.medium"
        case .sharpen:                         return "sparkles"
        case .filmGrain:                       return "film.stack"
        case .lut:                             return "cube.transparent"
        default:                               return "wand.and.stars"
        }
    }
}

/// Panel that lists all effects on the selected clip and lets you add/reorder/remove them.
public struct EffectListPanel: View {
    let clip: Clip?
    let onAddEffect: (Effect.EffectType) -> Void
    let onUpdateEffect: (UUID, Effect) -> Void
    let onRemoveEffect: (UUID) -> Void

    @State private var showingEffectPicker = false

    public init(
        clip: Clip?,
        onAddEffect: @escaping (Effect.EffectType) -> Void,
        onUpdateEffect: @escaping (UUID, Effect) -> Void,
        onRemoveEffect: @escaping (UUID) -> Void
    ) {
        self.clip = clip
        self.onAddEffect = onAddEffect
        self.onUpdateEffect = onUpdateEffect
        self.onRemoveEffect = onRemoveEffect
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Effects")
                    .font(.headline)
                Spacer()
                if clip != nil {
                    Button { showingEffectPicker = true } label: {
                        Image(systemName: "plus.circle.fill").font(.title3)
                    }
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 8)

            Divider()

            if let clip {
                if clip.effects.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(clip.effects) { effect in
                                EffectControls(
                                    effect: effect,
                                    onUpdate: { onUpdateEffect(effect.id, $0) },
                                    onRemove: { onRemoveEffect(effect.id) }
                                )
                            }
                        }
                        .padding(12)
                    }
                }
            } else {
                emptyState
            }
        }
        .confirmationDialog("Add Effect", isPresented: $showingEffectPicker, titleVisibility: .visible) {
            Button("Color Correction") { onAddEffect(.colorCorrection) }
            Button("Blur")             { onAddEffect(.gaussianBlur) }
            Button("Chroma Key")       { onAddEffect(.chromaKey) }
            Button("Vignette")         { onAddEffect(.vignette) }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "wand.and.stars")
                .font(.system(size: 36)).foregroundColor(.secondary)
            Text(clip == nil ? "Select a clip" : "No effects added")
                .font(.subheadline).foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}
#endif
