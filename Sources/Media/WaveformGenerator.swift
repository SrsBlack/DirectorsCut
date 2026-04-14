import AVFoundation
import Accelerate

/// Generates audio waveform data for visual display on the timeline.
public final class WaveformGenerator {
    /// Waveform samples: normalized amplitude values between 0.0 and 1.0
    public struct WaveformData {
        public let samples: [Float]
        public let duration: Double
        public let sampleRate: Double
    }

    /// Generate waveform data from an audio/video file
    public static func generate(
        from url: URL,
        samplesPerSecond: Int = 50
    ) async throws -> WaveformData {
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration).seconds

        guard duration > 0 else {
            return WaveformData(samples: [], duration: 0, sampleRate: Double(samplesPerSecond))
        }

        let totalSamples = Int(duration * Double(samplesPerSecond))

        guard let reader = try? AVAssetReader(asset: asset) else {
            return WaveformData(samples: Array(repeating: 0, count: totalSamples), duration: duration, sampleRate: Double(samplesPerSecond))
        }

        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        guard let audioTrack = audioTracks.first else {
            return WaveformData(samples: Array(repeating: 0, count: totalSamples), duration: duration, sampleRate: Double(samplesPerSecond))
        }

        let outputSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsNonInterleaved: false,
        ]

        let output = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: outputSettings)
        reader.add(output)

        guard reader.startReading() else {
            return WaveformData(samples: Array(repeating: 0, count: totalSamples), duration: duration, sampleRate: Double(samplesPerSecond))
        }

        // Read all audio samples
        var allSamples: [Int16] = []
        while let buffer = output.copyNextSampleBuffer(),
              let blockBuffer = CMSampleBufferGetDataBuffer(buffer) {
            let length = CMBlockBufferGetDataLength(blockBuffer)
            var data = Data(count: length)
            data.withUnsafeMutableBytes { ptr in
                CMBlockBufferCopyDataBytes(blockBuffer, atOffset: 0, dataLength: length, destination: ptr.baseAddress!)
            }
            let int16Buffer = data.withUnsafeBytes {
                Array($0.bindMemory(to: Int16.self))
            }
            allSamples.append(contentsOf: int16Buffer)
        }

        guard !allSamples.isEmpty else {
            return WaveformData(samples: Array(repeating: 0, count: totalSamples), duration: duration, sampleRate: Double(samplesPerSecond))
        }

        // Downsample to target resolution
        let samplesPerBucket = max(1, allSamples.count / totalSamples)
        var waveform: [Float] = []
        waveform.reserveCapacity(totalSamples)

        for i in 0..<totalSamples {
            let start = i * samplesPerBucket
            let end = min(start + samplesPerBucket, allSamples.count)
            guard start < end else {
                waveform.append(0)
                continue
            }

            // Find peak amplitude in this bucket
            var peak: Float = 0
            for j in start..<end {
                let sample = abs(Float(allSamples[j]) / Float(Int16.max))
                if sample > peak { peak = sample }
            }
            waveform.append(peak)
        }

        return WaveformData(samples: waveform, duration: duration, sampleRate: Double(samplesPerSecond))
    }
}
