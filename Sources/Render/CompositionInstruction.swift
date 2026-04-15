import AVFoundation

/// Custom AVVideoCompositionInstruction that carries per-clip effect data.
///
/// AVFoundation gives us back this exact instance via
/// `AVAsynchronousVideoCompositionRequest.videoCompositionInstruction`,
/// so we can read the effects from inside `MetalCompositor.startRequest`.
public final class DCCompositionInstruction: NSObject, AVVideoCompositionInstructionProtocol {
    public let timeRange: CMTimeRange
    public let enablePostProcessing: Bool = false
    public let containsTweening: Bool = false
    public let requiredSourceTrackIDs: [NSValue]?
    public let passthroughTrackID: CMPersistentTrackID

    /// The effects applied to whatever clip is visible in this time range
    public let effects: [Effect]

    /// Opacity of this layer (typically the clip's opacity)
    public let opacity: Float

    /// The track ID this instruction's primary clip lives on
    public let primaryTrackID: CMPersistentTrackID

    public init(
        timeRange: CMTimeRange,
        primaryTrackID: CMPersistentTrackID,
        sourceTrackIDs: [CMPersistentTrackID],
        effects: [Effect],
        opacity: Float
    ) {
        self.timeRange = timeRange
        self.primaryTrackID = primaryTrackID
        self.passthroughTrackID = kCMPersistentTrackID_Invalid
        self.requiredSourceTrackIDs = sourceTrackIDs.map { NSValue(value: $0) }
        self.effects = effects
        self.opacity = opacity
        super.init()
    }
}
