#if canImport(UIKit)
import SwiftUI

/// App-wide settings and preferences.
public struct SettingsView: View {
    @AppStorage("defaultResolution") private var defaultResolution = "1080p"
    @AppStorage("defaultFramerate")  private var defaultFramerate = 30.0
    @AppStorage("autoSaveEnabled")   private var autoSaveEnabled = true
    @AppStorage("autoSaveInterval")  private var autoSaveInterval = 30.0
    @AppStorage("hapticFeedback")    private var hapticFeedback = true
    @AppStorage("showTimecode")      private var showTimecode = true
    @AppStorage("exportQuality")     private var exportQuality = "1080p"

    @Environment(\.dismiss) private var dismiss

    public init() {}

    public var body: some View {
        NavigationView {
            List {
                // Project defaults
                Section("New Project Defaults") {
                    Picker("Resolution", selection: $defaultResolution) {
                        Text("720p HD").tag("720p")
                        Text("1080p Full HD").tag("1080p")
                        Text("4K Ultra HD").tag("4k")
                    }
                    Picker("Frame Rate", selection: $defaultFramerate) {
                        Text("24 fps (Film)").tag(24.0)
                        Text("25 fps (PAL)").tag(25.0)
                        Text("30 fps").tag(30.0)
                        Text("60 fps").tag(60.0)
                    }
                }

                // Export
                Section("Export") {
                    Picker("Default Quality", selection: $exportQuality) {
                        Text("720p HD").tag("720p")
                        Text("1080p Full HD").tag("1080p")
                        Text("1080p HEVC").tag("1080p_hevc")
                        Text("4K Ultra HD").tag("4k")
                        Text("4K HDR").tag("4k_hdr")
                    }
                    HStack {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.green)
                        Text("No watermark — free forever")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                // Editor
                Section("Editor") {
                    Toggle("Haptic Feedback", isOn: $hapticFeedback)
                    Toggle("Show Timecode", isOn: $showTimecode)
                }

                // Auto-save
                Section("Auto-Save") {
                    Toggle("Auto-Save Projects", isOn: $autoSaveEnabled)
                    if autoSaveEnabled {
                        Picker("Interval", selection: $autoSaveInterval) {
                            Text("15 seconds").tag(15.0)
                            Text("30 seconds").tag(30.0)
                            Text("1 minute").tag(60.0)
                            Text("5 minutes").tag(300.0)
                        }
                    }
                }

                // Storage
                Section("Storage") {
                    Button(role: .destructive) {
                        clearCache()
                    } label: {
                        HStack {
                            Text("Clear Thumbnail Cache")
                            Spacer()
                            Text(cacheSize)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // About
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Made with")
                        Spacer()
                        Text("Swift + Metal")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Image(systemName: "lock.shield")
                            .foregroundColor(.green)
                        Text("All processing happens on your device. No data is sent anywhere.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var cacheSize: String {
        let cacheDir = FileManager.default.temporaryDirectory
        let size = (try? FileManager.default.allocatedSizeOfDirectory(at: cacheDir)) ?? 0
        return ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
    }

    private func clearCache() {
        let tmpDir = FileManager.default.temporaryDirectory
        if let files = try? FileManager.default.contentsOfDirectory(at: tmpDir, includingPropertiesForKeys: nil) {
            for file in files {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }
}

extension FileManager {
    func allocatedSizeOfDirectory(at url: URL) throws -> UInt64 {
        var totalSize: UInt64 = 0
        let enumerator = self.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey])
        while let fileURL = enumerator?.nextObject() as? URL {
            let size = try fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            totalSize += UInt64(size)
        }
        return totalSize
    }
}
#endif
