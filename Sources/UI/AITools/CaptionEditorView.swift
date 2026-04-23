#if canImport(UIKit)
import SwiftUI
import AI

/// Displays and edits AI-generated captions on a clip.
public struct CaptionEditorView: View {
    @Binding var captions: [CaptionGenerator.Caption]
    let duration: Double
    let currentTime: Double
    let onSeek: (Double) -> Void

    @State private var selectedCaptionId: UUID?
    @State private var editingText: String = ""

    public init(
        captions: Binding<[CaptionGenerator.Caption]>,
        duration: Double,
        currentTime: Double,
        onSeek: @escaping (Double) -> Void
    ) {
        self._captions = captions
        self.duration = duration
        self.currentTime = currentTime
        self.onSeek = onSeek
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Captions")
                    .font(.headline)
                Spacer()
                if !captions.isEmpty {
                    Button {
                        captions.removeAll()
                    } label: {
                        Text("Clear All")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            if captions.isEmpty {
                // Empty state
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "captions.bubble")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("No captions yet")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("Use AI Tools → Auto Captions to generate captions from speech")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    Spacer()
                }
            } else {
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach($captions) { $caption in
                            CaptionRow(
                                caption: $caption,
                                isActive: currentTime >= caption.startTime && currentTime < caption.endTime,
                                isSelected: selectedCaptionId == caption.id,
                                onTap: {
                                    selectedCaptionId = caption.id
                                    onSeek(caption.startTime)
                                },
                                onDelete: {
                                    captions.removeAll { $0.id == caption.id }
                                }
                            )
                        }
                    }
                    .padding(8)
                }
            }
        }
    }
}

private struct CaptionRow: View {
    @Binding var caption: CaptionGenerator.Caption
    let isActive: Bool
    let isSelected: Bool
    let onTap: () -> Void
    let onDelete: () -> Void

    @State private var isEditing = false

    var body: some View {
        HStack(spacing: 8) {
            // Time badge
            VStack(alignment: .trailing, spacing: 2) {
                Text(formatTime(caption.startTime))
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary)
                Text(formatTime(caption.endTime))
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            .frame(width: 44)

            // Caption text
            if isEditing {
                TextField("Caption text", text: $caption.text)
                    .font(.subheadline)
                    .onSubmit { isEditing = false }
            } else {
                Text(caption.text)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onTapGesture(count: 2) { isEditing = true }
            }

            // Delete button
            Button(role: .destructive) { onDelete() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isActive ? Color.accentColor.opacity(0.15) :
                      isSelected ? Color.secondary.opacity(0.1) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(isActive ? Color.accentColor.opacity(0.4) : Color.clear, lineWidth: 1)
        )
        .onTapGesture { onTap() }
    }

    private func formatTime(_ t: Double) -> String {
        let m = Int(t) / 60; let s = Int(t) % 60
        let ms = Int((t - Double(Int(t))) * 10)
        return String(format: "%d:%02d.%d", m, s, ms)
    }
}
#endif
