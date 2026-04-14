#if canImport(UIKit)
import UIKit
import AVFoundation

/// Generates thumbnail images from video files for the timeline display.
public final class ThumbnailGenerator {
    private let asset: AVURLAsset
    private let imageGenerator: AVAssetImageGenerator

    public init(url: URL) {
        self.asset = AVURLAsset(url: url)
        self.imageGenerator = AVAssetImageGenerator(asset: asset)
        self.imageGenerator.appliesPreferredTrackTransform = true
        self.imageGenerator.requestedTimeToleranceBefore = .zero
        self.imageGenerator.requestedTimeToleranceAfter = CMTime(seconds: 0.1, preferredTimescale: 600)
    }

    /// Generate a single thumbnail at a specific time
    public func thumbnail(at time: Double, size: CGSize = CGSize(width: 160, height: 90)) async throws -> UIImage {
        imageGenerator.maximumSize = size
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        let (cgImage, _) = try await imageGenerator.image(at: cmTime)
        return UIImage(cgImage: cgImage)
    }

    /// Generate a strip of evenly-spaced thumbnails for a timeline clip
    public func thumbnailStrip(
        startTime: Double,
        duration: Double,
        count: Int,
        size: CGSize = CGSize(width: 80, height: 45)
    ) async throws -> [UIImage] {
        imageGenerator.maximumSize = size

        let interval = duration / Double(max(count - 1, 1))
        let times = (0..<count).map { i in
            CMTime(seconds: startTime + Double(i) * interval, preferredTimescale: 600)
        }

        var thumbnails: [UIImage] = []
        thumbnails.reserveCapacity(count)

        for time in times {
            do {
                let (cgImage, _) = try await imageGenerator.image(at: time)
                thumbnails.append(UIImage(cgImage: cgImage))
            } catch {
                // Use a placeholder for failed frames
                thumbnails.append(UIImage())
            }
        }

        return thumbnails
    }

    /// Generate thumbnails and deliver them progressively via a callback
    public func generateThumbnails(
        startTime: Double,
        duration: Double,
        count: Int,
        size: CGSize = CGSize(width: 80, height: 45),
        onThumbnail: @escaping (Int, UIImage) -> Void
    ) {
        imageGenerator.maximumSize = size

        let interval = duration / Double(max(count - 1, 1))
        let times = (0..<count).map { i in
            NSValue(time: CMTime(seconds: startTime + Double(i) * interval, preferredTimescale: 600))
        }

        var index = 0
        imageGenerator.generateCGImagesAsynchronously(forTimes: times) { _, cgImage, _, _, _ in
            let image: UIImage
            if let cgImage {
                image = UIImage(cgImage: cgImage)
            } else {
                image = UIImage()
            }
            DispatchQueue.main.async {
                onThumbnail(index, image)
            }
            index += 1
        }
    }

    /// Cancel any in-progress thumbnail generation
    public func cancel() {
        imageGenerator.cancelAllCGImageGeneration()
    }
}
#endif
