#if canImport(UIKit)
import UIKit
import PhotosUI
import AVFoundation
import UniformTypeIdentifiers
import Editor

/// Handles importing media from the camera roll and files.
@MainActor
public final class MediaImporter: NSObject, ObservableObject {
    @Published public var importedAssets: [ImportedAsset] = []
    @Published public var isImporting = false

    public struct ImportedAsset: Identifiable {
        public let id = UUID()
        public let url: URL
        public let mediaType: Clip.MediaType
        public let duration: Double
        public let naturalSize: CGSize
        public let name: String
    }

    /// Create a PHPickerViewController configured for video/image selection
    public func makePickerController(selectionLimit: Int = 0) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.selectionLimit = selectionLimit
        config.filter = .any(of: [.videos, .images])
        config.preferredAssetRepresentationMode = .current
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        return picker
    }

    /// Import a video from a URL (Files app, drag & drop, etc.)
    public func importFile(at url: URL) async throws -> ImportedAsset {
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration)
        let tracks = try await asset.loadTracks(withMediaType: .video)
        let size = try await tracks.first?.load(.naturalSize) ?? CGSize(width: 1920, height: 1080)

        let name = url.deletingPathExtension().lastPathComponent

        let hasVideo = !tracks.isEmpty
        let mediaType: Clip.MediaType = hasVideo ? .video : .audio

        let imported = ImportedAsset(
            url: url,
            mediaType: mediaType,
            duration: duration.seconds,
            naturalSize: size,
            name: name
        )
        importedAssets.append(imported)
        return imported
    }

    /// Copy an imported file to the app's documents for persistence
    public func copyToProjectStorage(_ asset: ImportedAsset, projectId: UUID) throws -> URL {
        let projectMediaDir = ProjectFile.projectsDirectory
            .appendingPathComponent(projectId.uuidString, isDirectory: true)
            .appendingPathComponent("media", isDirectory: true)

        try FileManager.default.createDirectory(at: projectMediaDir, withIntermediateDirectories: true)

        let destURL = projectMediaDir.appendingPathComponent(asset.url.lastPathComponent)

        if !FileManager.default.fileExists(atPath: destURL.path) {
            try FileManager.default.copyItem(at: asset.url, to: destURL)
        }

        return destURL
    }
}

extension MediaImporter: PHPickerViewControllerDelegate {
    public nonisolated func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        Task { @MainActor in
            picker.dismiss(animated: true)

            guard !results.isEmpty else { return }
            isImporting = true

            for result in results {
                let provider = result.itemProvider

                if provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
                    if let url = try? await loadFileURL(from: provider, type: .movie) {
                        _ = try? await importFile(at: url)
                    }
                } else if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                    if let url = try? await loadFileURL(from: provider, type: .image) {
                        _ = try? await importFile(at: url)
                    }
                }
            }

            isImporting = false
        }
    }

    private func loadFileURL(from provider: NSItemProvider, type: UTType) async throws -> URL? {
        try await withCheckedThrowingContinuation { continuation in
            provider.loadFileRepresentation(forTypeIdentifier: type.identifier) { url, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let url else {
                    continuation.resume(returning: nil)
                    return
                }
                // Copy to temp location since the provided URL is temporary
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString)
                    .appendingPathExtension(url.pathExtension)
                do {
                    try FileManager.default.copyItem(at: url, to: tempURL)
                    continuation.resume(returning: tempURL)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
#endif
