#if canImport(UIKit)
import SwiftUI
import Photos
import Export

/// Export settings and progress UI.
public struct ExportView: View {
    @ObservedObject var exportEngine: ExportEngine
    @State private var selectedPreset: ExportPreset = .hd1080
    @State private var showingShareSheet = false
    @State private var exportedURL: URL?
    @State private var showingSavedAlert = false

    let onExport: (ExportPreset) async throws -> URL
    let onDismiss: () -> Void

    public init(
        exportEngine: ExportEngine,
        onExport: @escaping (ExportPreset) async throws -> URL,
        onDismiss: @escaping () -> Void
    ) {
        self.exportEngine = exportEngine
        self.onExport = onExport
        self.onDismiss = onDismiss
    }

    public var body: some View {
        NavigationView {
            List {
                // Quality Selection
                Section("Quality") {
                    ForEach(ExportPreset.all) { preset in
                        Button {
                            selectedPreset = preset
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(preset.name)
                                        .foregroundColor(.primary)
                                    Text(preset.resolution)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                if preset.id == selectedPreset.id {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentColor)
                                }
                            }
                        }
                    }
                }

                // Free guarantee
                Section {
                    HStack {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.green)
                        Text("No watermark - free forever")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                // Export progress
                if exportEngine.isExporting {
                    Section("Exporting...") {
                        VStack(spacing: 8) {
                            ProgressView(value: exportEngine.progress)
                            Text("\(Int(exportEngine.progress * 100))%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // Export button
                Section {
                    Button {
                        Task { await startExport() }
                    } label: {
                        HStack {
                            Spacer()
                            if exportEngine.isExporting {
                                ProgressView()
                                    .padding(.trailing, 8)
                                Text("Exporting...")
                            } else {
                                Image(systemName: "square.and.arrow.up")
                                Text("Export \(selectedPreset.name)")
                            }
                            Spacer()
                        }
                        .font(.headline)
                    }
                    .disabled(exportEngine.isExporting)
                }
            }
            .navigationTitle("Export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onDismiss() }
                }
            }
            .alert("Saved!", isPresented: $showingSavedAlert) {
                Button("OK") { onDismiss() }
            } message: {
                Text("Your video has been saved to your camera roll.")
            }
        }
    }

    private func startExport() async {
        do {
            let url = try await onExport(selectedPreset)
            exportedURL = url

            // Save to photo library
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetCreationRequest.forAsset()
                    .addResource(with: .video, fileURL: url, options: nil)
            }
            showingSavedAlert = true
        } catch {
            exportEngine.error = error
        }
    }
}
#endif
