#if canImport(UIKit)
import SwiftUI

/// Panel showing available AI tools.
public struct AIToolPanel: View {
    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("AI Tools")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            List {
                AIToolRow(icon: "captions.bubble", title: "Auto Captions", description: "Generate captions from speech", badge: "Coming Soon")
                AIToolRow(icon: "person.crop.rectangle", title: "Remove Background", description: "AI background removal", badge: "Coming Soon")
                AIToolRow(icon: "scope", title: "Motion Tracking", description: "Track objects across frames", badge: "Coming Soon")
                AIToolRow(icon: "scissors", title: "Scene Detection", description: "Auto-detect scene cuts", badge: "Coming Soon")
                AIToolRow(icon: "waveform.slash", title: "Remove Silence", description: "Cut silent segments", badge: "Coming Soon")
                AIToolRow(icon: "speaker.wave.2.bubble", title: "Audio Cleanup", description: "AI noise removal", badge: "Coming Soon")
            }
            .listStyle(.plain)
        }
    }
}

struct AIToolRow: View {
    let icon: String
    let title: String
    let description: String
    let badge: String?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.accentColor)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if let badge {
                Text(badge)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.15))
                    .cornerRadius(8)
            }
        }
        .padding(.vertical, 4)
    }
}
#endif
