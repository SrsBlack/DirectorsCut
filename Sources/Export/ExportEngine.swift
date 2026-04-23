import AVFoundation
import Combine
import Editor
import Render

/// Exports video compositions to files using AVAssetWriter.
/// No watermarks. Full quality. Free forever.
@MainActor
public final class ExportEngine: ObservableObject {
    @Published public var progress: Double = 0
    @Published public var isExporting = false
    @Published public var error: Error?

    private var exportSession: AVAssetExportSession?

    public init() {}

    /// Export a composition to a file using AVAssetExportSession for simplicity.
    /// For full quality control, use exportWithAssetWriter instead.
    public func export(
        composition: CompositionBuilder.CompositionResult,
        preset: ExportPreset,
        to outputURL: URL
    ) async throws {
        isExporting = true
        progress = 0
        error = nil

        defer {
            isExporting = false
        }

        // Remove existing file at output URL
        try? FileManager.default.removeItem(at: outputURL)

        // Use AVAssetWriter for full control (no watermark, custom quality)
        try await exportWithAssetWriter(
            composition: composition,
            preset: preset,
            outputURL: outputURL
        )

        progress = 1.0
    }

    /// Export using AVAssetWriter for complete control over output quality.
    private func exportWithAssetWriter(
        composition: CompositionBuilder.CompositionResult,
        preset: ExportPreset,
        outputURL: URL
    ) async throws {
        let writer = try AVAssetWriter(outputURL: outputURL, fileType: preset.fileType)

        // Video input
        let videoInput = AVAssetWriterInput(
            mediaType: .video,
            outputSettings: preset.videoSettings
        )
        videoInput.expectsMediaDataInRealTime = false

        if writer.canAdd(videoInput) {
            writer.add(videoInput)
        }

        // Audio input
        let audioInput = AVAssetWriterInput(
            mediaType: .audio,
            outputSettings: preset.audioSettings
        )
        audioInput.expectsMediaDataInRealTime = false

        if writer.canAdd(audioInput) {
            writer.add(audioInput)
        }

        // Set up reader
        let reader = try AVAssetReader(asset: composition.composition)

        // Video output from reader
        let videoOutput = AVAssetReaderVideoCompositionOutput(
            videoTracks: composition.composition.tracks(withMediaType: .video),
            videoSettings: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            ]
        )
        videoOutput.videoComposition = composition.videoComposition

        if reader.canAdd(videoOutput) {
            reader.add(videoOutput)
        }

        // Audio output from reader
        let audioTracks = composition.composition.tracks(withMediaType: .audio)
        var audioOutput: AVAssetReaderAudioMixOutput?
        if !audioTracks.isEmpty {
            let output = AVAssetReaderAudioMixOutput(
                audioTracks: audioTracks,
                audioSettings: [
                    AVFormatIDKey: kAudioFormatLinearPCM,
                    AVLinearPCMBitDepthKey: 32,
                    AVLinearPCMIsFloatKey: true,
                    AVLinearPCMIsNonInterleaved: false,
                ]
            )
            output.audioMix = composition.audioMix
            if reader.canAdd(output) {
                reader.add(output)
                audioOutput = output
            }
        }

        // Start reading and writing
        guard reader.startReading() else {
            throw ExportError.readerFailed(reader.error)
        }

        guard writer.startWriting() else {
            throw ExportError.writerFailed(writer.error)
        }

        writer.startSession(atSourceTime: .zero)

        let totalDuration = composition.composition.duration.seconds

        // Write video
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            videoInput.requestMediaDataWhenReady(on: DispatchQueue(label: "com.directorscut.export.video")) {
                while videoInput.isReadyForMoreMediaData {
                    if let sampleBuffer = videoOutput.copyNextSampleBuffer() {
                        videoInput.append(sampleBuffer)

                        let time = CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds
                        Task { @MainActor in
                            self.progress = min(time / totalDuration, 0.99)
                        }
                    } else {
                        videoInput.markAsFinished()
                        continuation.resume()
                        return
                    }
                }
            }
        }

        // Write audio
        if let audioOutput {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                audioInput.requestMediaDataWhenReady(on: DispatchQueue(label: "com.directorscut.export.audio")) {
                    while audioInput.isReadyForMoreMediaData {
                        if let sampleBuffer = audioOutput.copyNextSampleBuffer() {
                            audioInput.append(sampleBuffer)
                        } else {
                            audioInput.markAsFinished()
                            continuation.resume()
                            return
                        }
                    }
                }
            }
        } else {
            audioInput.markAsFinished()
        }

        // Finalize
        await writer.finishWriting()

        if writer.status == .failed {
            throw ExportError.writerFailed(writer.error)
        }
    }

    /// Cancel an in-progress export
    public func cancel() {
        exportSession?.cancelExport()
        isExporting = false
        progress = 0
    }

    /// Generate a temporary output URL for export
    public static func temporaryOutputURL(preset: ExportPreset) -> URL {
        let fileName = "DirectorsCut_\(Date().timeIntervalSince1970)"
        return FileManager.default.temporaryDirectory
            .appendingPathComponent(fileName)
            .appendingPathExtension(preset.fileType == .mp4 ? "mp4" : "mov")
    }

    public enum ExportError: LocalizedError {
        case readerFailed(Error?)
        case writerFailed(Error?)

        public var errorDescription: String? {
            switch self {
            case .readerFailed(let err):
                return "Failed to read composition: \(err?.localizedDescription ?? "Unknown error")"
            case .writerFailed(let err):
                return "Failed to write export: \(err?.localizedDescription ?? "Unknown error")"
            }
        }
    }
}
