#if canImport(UIKit)
import SwiftUI

/// Properties panel for editing selected clip properties.
public struct PropertiesPanel: View {
    let clip: Clip?
    let onUpdate: (Clip) -> Void

    public init(clip: Clip?, onUpdate: @escaping (Clip) -> Void) {
        self.clip = clip
        self.onUpdate = onUpdate
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Properties")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            if let clip {
                ScrollView {
                    VStack(spacing: 16) {
                        // Clip info
                        GroupBox("Clip") {
                            VStack(alignment: .leading, spacing: 8) {
                                LabeledValue(label: "Name", value: clip.name.isEmpty ? "Untitled" : clip.name)
                                LabeledValue(label: "Duration", value: formatDuration(clip.duration))
                                LabeledValue(label: "Type", value: clip.mediaType.rawValue.capitalized)
                            }
                        }

                        // Speed
                        GroupBox("Speed") {
                            VStack {
                                Slider(
                                    value: binding(for: \.speed, in: clip),
                                    in: 0.25...4.0,
                                    step: 0.25
                                )
                                Text("\(clip.speed, specifier: "%.2f")x")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        // Volume
                        if clip.mediaType == .video || clip.mediaType == .audio {
                            GroupBox("Audio") {
                                VStack {
                                    HStack {
                                        Image(systemName: clip.isMuted ? "speaker.slash" : "speaker.wave.2")
                                        Slider(
                                            value: binding(for: \.volume, in: clip),
                                            in: 0...1
                                        )
                                        Text("\(Int(clip.volume * 100))%")
                                            .font(.caption)
                                            .frame(width: 36)
                                    }
                                }
                            }
                        }

                        // Opacity
                        GroupBox("Opacity") {
                            VStack {
                                Slider(
                                    value: binding(for: \.opacity, in: clip),
                                    in: 0...1
                                )
                                Text("\(Int(clip.opacity * 100))%")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(12)
                }
            } else {
                VStack {
                    Spacer()
                    Text("Select a clip to edit")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
        }
    }

    private func binding(for keyPath: WritableKeyPath<Clip, Double>, in clip: Clip) -> Binding<Double> {
        Binding(
            get: { clip[keyPath: keyPath] },
            set: { newValue in
                var updated = clip
                updated[keyPath: keyPath] = newValue
                onUpdate(updated)
            }
        )
    }

    private func binding(for keyPath: WritableKeyPath<Clip, Float>, in clip: Clip) -> Binding<Float> {
        Binding(
            get: { clip[keyPath: keyPath] },
            set: { newValue in
                var updated = clip
                updated[keyPath: keyPath] = newValue
                onUpdate(updated)
            }
        )
    }

    private func formatDuration(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        let ms = Int((seconds - Double(Int(seconds))) * 100)
        return String(format: "%d:%02d.%02d", mins, secs, ms)
    }
}

struct LabeledValue: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.caption)
                .foregroundColor(.primary)
        }
    }
}
#endif
