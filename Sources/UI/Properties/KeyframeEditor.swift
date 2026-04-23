#if canImport(UIKit)
import SwiftUI
import Editor

/// Displays and edits keyframe tracks for an animated property.
public struct KeyframeEditor: View {
    let track: KeyframeTrack
    let duration: Double
    let currentTime: Double
    let onAddKeyframe: (Double) -> Void      // add keyframe at time
    let onRemoveKeyframe: (UUID) -> Void
    let onUpdateKeyframe: (Keyframe) -> Void

    public init(
        track: KeyframeTrack,
        duration: Double,
        currentTime: Double,
        onAddKeyframe: @escaping (Double) -> Void,
        onRemoveKeyframe: @escaping (UUID) -> Void,
        onUpdateKeyframe: @escaping (Keyframe) -> Void
    ) {
        self.track = track
        self.duration = duration
        self.currentTime = currentTime
        self.onAddKeyframe = onAddKeyframe
        self.onRemoveKeyframe = onRemoveKeyframe
        self.onUpdateKeyframe = onUpdateKeyframe
    }

    public var body: some View {
        VStack(spacing: 8) {
            // Header row
            HStack {
                Text(track.property.displayName)
                    .font(.caption).fontWeight(.medium)
                Spacer()
                if let current = track.value(at: currentTime) {
                    Text(String(format: "%.2f", current))
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.secondary)
                }
                Button {
                    onAddKeyframe(currentTime)
                } label: {
                    Image(systemName: "diamond.fill")
                        .font(.caption)
                        .foregroundColor(hasKeyframeAtCurrentTime ? .yellow : .accentColor)
                }
                .help("Add keyframe at current time")
            }

            // Timeline strip with keyframe diamonds
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Track bar
                    Capsule()
                        .fill(Color.secondary.opacity(0.15))
                        .frame(height: 4)
                        .padding(.top, 10)

                    // Current-time indicator
                    let tx = CGFloat(currentTime / max(duration, 1)) * geo.size.width
                    Rectangle()
                        .fill(Color.red.opacity(0.5))
                        .frame(width: 1, height: 24)
                        .offset(x: tx)

                    // Keyframe diamonds
                    ForEach(track.keyframes) { kf in
                        let x = CGFloat(kf.time / max(duration, 1)) * geo.size.width
                        Image(systemName: "diamond.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.yellow)
                            .offset(x: x - 5, y: 2)
                            .onTapGesture {
                                onRemoveKeyframe(kf.id)
                            }
                    }
                }
            }
            .frame(height: 24)

            // Keyframe list
            if !track.keyframes.isEmpty {
                ForEach(track.keyframes.sorted { $0.time < $1.time }) { kf in
                    KeyframeRow(
                        keyframe: kf,
                        onUpdate: onUpdateKeyframe,
                        onRemove: { onRemoveKeyframe(kf.id) }
                    )
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(uiColor: .tertiarySystemBackground))
        .cornerRadius(8)
    }

    private var hasKeyframeAtCurrentTime: Bool {
        track.keyframes.contains { abs($0.time - currentTime) < 0.05 }
    }
}

private struct KeyframeRow: View {
    let keyframe: Keyframe
    let onUpdate: (Keyframe) -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "diamond.fill")
                .font(.caption2).foregroundColor(.yellow)
            Text(String(format: "%.2fs", keyframe.time))
                .font(.caption.monospacedDigit())
            Text("→")
                .font(.caption).foregroundColor(.secondary)
            Text(String(format: "%.2f", keyframe.value))
                .font(.caption.monospacedDigit())

            Spacer()

            // Interpolation picker
            Menu {
                ForEach(Keyframe.Interpolation.allCases, id: \.self) { interp in
                    Button(interp.displayName) {
                        var updated = keyframe
                        updated.interpolation = interp
                        onUpdate(updated)
                    }
                }
            } label: {
                Text(keyframe.interpolation.displayName)
                    .font(.caption2)
                    .foregroundColor(.accentColor)
            }

            Button(role: .destructive) { onRemove() } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.caption).foregroundColor(.red)
            }
        }
    }
}

#endif
