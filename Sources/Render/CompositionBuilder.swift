import AVFoundation
import CoreMedia

/// Builds an AVMutableComposition from a Timeline model.
/// This is the bridge between our data model and AVFoundation's rendering engine.
public final class CompositionBuilder {

    public struct CompositionResult {
        public let composition: AVMutableComposition
        public let videoComposition: AVMutableVideoComposition
        public let audioMix: AVMutableAudioMix
    }

    /// Build an AVFoundation composition from a Timeline
    public static func build(from timeline: Timeline) async throws -> CompositionResult {
        let composition = AVMutableComposition()
        var audioMixParams: [AVMutableAudioMixInputParameters] = []

        let videoSize = CGSize(
            width: CGFloat(timeline.resolution.width),
            height: CGFloat(timeline.resolution.height)
        )

        // Process video tracks
        for track in timeline.videoTracks where track.isVisible {
            guard let compositionVideoTrack = composition.addMutableTrack(
                withMediaType: .video,
                preferredTrackID: kCMPersistentTrackID_Invalid
            ) else { continue }

            guard let compositionAudioTrack = composition.addMutableTrack(
                withMediaType: .audio,
                preferredTrackID: kCMPersistentTrackID_Invalid
            ) else { continue }

            for clip in track.clips {
                let sourceAsset = AVURLAsset(url: clip.sourceURL)

                let sourceVideoTracks = try await sourceAsset.loadTracks(withMediaType: .video)
                let sourceAudioTracks = try await sourceAsset.loadTracks(withMediaType: .audio)

                let insertTime = CMTime(seconds: clip.timelineStart, preferredTimescale: 600)
                let sourceStart = CMTime(seconds: clip.sourceStartTime, preferredTimescale: 600)
                let clipDuration = CMTime(seconds: clip.duration * clip.speed, preferredTimescale: 600)
                let timeRange = CMTimeRange(start: sourceStart, duration: clipDuration)

                // Insert video
                if let sourceVideoTrack = sourceVideoTracks.first {
                    try compositionVideoTrack.insertTimeRange(
                        timeRange,
                        of: sourceVideoTrack,
                        at: insertTime
                    )
                }

                // Insert audio
                if let sourceAudioTrack = sourceAudioTracks.first, !clip.isMuted && !track.isMuted {
                    try compositionAudioTrack.insertTimeRange(
                        timeRange,
                        of: sourceAudioTrack,
                        at: insertTime
                    )

                    // Set volume
                    let params = AVMutableAudioMixInputParameters(track: compositionAudioTrack)
                    let effectiveVolume = clip.volume * track.volume
                    params.setVolume(effectiveVolume, at: insertTime)
                    audioMixParams.append(params)
                }

                // Apply speed change by scaling time
                if clip.speed != 1.0 {
                    let scaledDuration = CMTime(seconds: clip.duration, preferredTimescale: 600)
                    compositionVideoTrack.scaleTimeRange(
                        CMTimeRange(start: insertTime, duration: clipDuration),
                        toDuration: scaledDuration
                    )
                    compositionAudioTrack.scaleTimeRange(
                        CMTimeRange(start: insertTime, duration: clipDuration),
                        toDuration: scaledDuration
                    )
                }
            }
        }

        // Process standalone audio tracks
        for track in timeline.audioTracks where !track.isMuted {
            guard let compositionAudioTrack = composition.addMutableTrack(
                withMediaType: .audio,
                preferredTrackID: kCMPersistentTrackID_Invalid
            ) else { continue }

            for clip in track.clips where !clip.isMuted {
                let sourceAsset = AVURLAsset(url: clip.sourceURL)
                let sourceAudioTracks = try await sourceAsset.loadTracks(withMediaType: .audio)

                guard let sourceAudioTrack = sourceAudioTracks.first else { continue }

                let insertTime = CMTime(seconds: clip.timelineStart, preferredTimescale: 600)
                let sourceStart = CMTime(seconds: clip.sourceStartTime, preferredTimescale: 600)
                let clipDuration = CMTime(seconds: clip.duration, preferredTimescale: 600)
                let timeRange = CMTimeRange(start: sourceStart, duration: clipDuration)

                try compositionAudioTrack.insertTimeRange(
                    timeRange,
                    of: sourceAudioTrack,
                    at: insertTime
                )

                let params = AVMutableAudioMixInputParameters(track: compositionAudioTrack)
                params.setVolume(clip.volume * track.volume, at: insertTime)
                audioMixParams.append(params)
            }
        }

        // Build video composition
        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = videoSize
        videoComposition.frameDuration = CMTime(value: 1, timescale: CMTimeScale(timeline.framerate))
        videoComposition.customVideoCompositorClass = MetalCompositor.self

        // Build per-clip instructions so each frame knows which effects to apply.
        // We walk the timeline in chronological order, emitting one DCCompositionInstruction
        // per clip on each visible video track.
        let videoTracks = composition.tracks(withMediaType: .video)
        let allTrackIDs = videoTracks.map(\.trackID)

        var instructions: [DCCompositionInstruction] = []

        for visibleTrack in timeline.videoTracks where visibleTrack.isVisible {
            // Map the model track to its corresponding composition track (by index).
            guard let modelIdx = timeline.videoTracks.firstIndex(where: { $0.id == visibleTrack.id }),
                  modelIdx < videoTracks.count else { continue }
            let avTrack = videoTracks[modelIdx]

            for clip in visibleTrack.clips {
                let start = CMTime(seconds: clip.timelineStart, preferredTimescale: 600)
                let dur   = CMTime(seconds: clip.duration,      preferredTimescale: 600)
                let range = CMTimeRange(start: start, duration: dur)

                let instr = DCCompositionInstruction(
                    timeRange: range,
                    primaryTrackID: avTrack.trackID,
                    sourceTrackIDs: allTrackIDs,
                    effects: clip.effects.filter(\.isEnabled),
                    opacity: clip.opacity
                )
                instructions.append(instr)
            }
        }

        // Sort by start time and trim to non-overlapping ranges (last clip wins for now).
        instructions.sort { $0.timeRange.start < $1.timeRange.start }

        videoComposition.instructions = instructions

        // Build audio mix
        let audioMix = AVMutableAudioMix()
        audioMix.inputParameters = audioMixParams

        return CompositionResult(
            composition: composition,
            videoComposition: videoComposition,
            audioMix: audioMix
        )
    }
}
