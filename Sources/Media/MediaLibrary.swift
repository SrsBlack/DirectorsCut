import Foundation
import AVFoundation
import Editor

/// Manages imported media assets for a project.
@MainActor
public final class MediaLibrary: ObservableObject {
    @Published public var assets: [MediaAsset] = []

    public struct MediaAsset: Identifiable {
        public let id: UUID
        public let url: URL
        public let name: String
        public let mediaType: Clip.MediaType
        public let duration: Double
        public let fileSize: Int64
        public let resolution: CGSize

        public init(
            id: UUID = UUID(),
            url: URL,
            name: String,
            mediaType: Clip.MediaType,
            duration: Double,
            fileSize: Int64 = 0,
            resolution: CGSize = .zero
        ) {
            self.id = id
            self.url = url
            self.name = name
            self.mediaType = mediaType
            self.duration = duration
            self.fileSize = fileSize
            self.resolution = resolution
        }

        /// Human-readable file size
        public var formattedSize: String {
            ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
        }

        /// Human-readable duration
        public var formattedDuration: String {
            let minutes = Int(duration) / 60
            let seconds = Int(duration) % 60
            return String(format: "%d:%02d", minutes, seconds)
        }
    }

    public init() {}

    /// Add a media asset from a URL, probing its metadata
    public func addAsset(from url: URL) async throws -> MediaAsset {
        let avAsset = AVURLAsset(url: url)
        let duration = try await avAsset.load(.duration).seconds
        let videoTracks = try await avAsset.loadTracks(withMediaType: .video)

        let size: CGSize
        let mediaType: Clip.MediaType

        if let videoTrack = videoTracks.first {
            size = try await videoTrack.load(.naturalSize)
            mediaType = .video
        } else {
            size = .zero
            mediaType = .audio
        }

        let fileSize: Int64
        if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
           let size = attrs[.size] as? Int64 {
            fileSize = size
        } else {
            fileSize = 0
        }

        let asset = MediaAsset(
            url: url,
            name: url.deletingPathExtension().lastPathComponent,
            mediaType: mediaType,
            duration: duration,
            fileSize: fileSize,
            resolution: size
        )

        assets.append(asset)
        return asset
    }

    /// Remove an asset by ID
    public func removeAsset(id: UUID) {
        assets.removeAll { $0.id == id }
    }

    /// Create a Clip from a MediaAsset, ready to add to the timeline
    public func createClip(from asset: MediaAsset, at timelineStart: Double = 0) -> Clip {
        Clip(
            sourceURL: asset.url,
            mediaType: asset.mediaType,
            timelineStart: timelineStart,
            duration: asset.duration,
            sourceDuration: asset.duration,
            name: asset.name
        )
    }
}
