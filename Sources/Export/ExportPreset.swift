import AVFoundation

/// Export quality presets for Directors Cut.
/// All presets are available for free - no watermark, no restrictions.
public struct ExportPreset: Identifiable {
    public let id: String
    public let name: String
    public let width: Int
    public let height: Int
    public let videoBitRate: Int
    public let audioBitRate: Int
    public let codec: AVVideoCodecType
    public let fileType: AVFileType
    public let isHDR: Bool

    public var resolution: String {
        "\(width) x \(height)"
    }

    // MARK: - Standard Presets

    public static let hd720 = ExportPreset(
        id: "720p", name: "720p HD",
        width: 1280, height: 720,
        videoBitRate: 5_000_000, audioBitRate: 128_000,
        codec: .h264, fileType: .mp4, isHDR: false
    )

    public static let hd1080 = ExportPreset(
        id: "1080p", name: "1080p Full HD",
        width: 1920, height: 1080,
        videoBitRate: 10_000_000, audioBitRate: 192_000,
        codec: .h264, fileType: .mp4, isHDR: false
    )

    public static let hd1080HEVC = ExportPreset(
        id: "1080p_hevc", name: "1080p HEVC",
        width: 1920, height: 1080,
        videoBitRate: 8_000_000, audioBitRate: 192_000,
        codec: .hevc, fileType: .mp4, isHDR: false
    )

    public static let uhd4K = ExportPreset(
        id: "4k", name: "4K Ultra HD",
        width: 3840, height: 2160,
        videoBitRate: 40_000_000, audioBitRate: 256_000,
        codec: .hevc, fileType: .mp4, isHDR: false
    )

    public static let uhd4KHDR = ExportPreset(
        id: "4k_hdr", name: "4K HDR",
        width: 3840, height: 2160,
        videoBitRate: 50_000_000, audioBitRate: 256_000,
        codec: .hevc, fileType: .mp4, isHDR: true
    )

    // Vertical formats for social media
    public static let vertical1080 = ExportPreset(
        id: "1080p_vertical", name: "1080p Vertical (Reels/TikTok)",
        width: 1080, height: 1920,
        videoBitRate: 10_000_000, audioBitRate: 192_000,
        codec: .h264, fileType: .mp4, isHDR: false
    )

    public static let square1080 = ExportPreset(
        id: "1080p_square", name: "1080p Square",
        width: 1080, height: 1080,
        videoBitRate: 8_000_000, audioBitRate: 192_000,
        codec: .h264, fileType: .mp4, isHDR: false
    )

    /// All available presets
    public static let all: [ExportPreset] = [
        .hd720, .hd1080, .hd1080HEVC, .uhd4K, .uhd4KHDR,
        .vertical1080, .square1080,
    ]

    /// Build AVAssetWriter video settings from this preset
    public var videoSettings: [String: Any] {
        var settings: [String: Any] = [
            AVVideoCodecKey: codec,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: videoBitRate,
                AVVideoProfileLevelKey: codec == .hevc
                    ? kVTProfileLevel_HEVC_Main_AutoLevel as String
                    : AVVideoProfileLevelH264HighAutoLevel,
            ],
        ]

        if isHDR {
            settings[AVVideoColorPropertiesKey] = [
                AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_2020,
                AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_2100_HLG,
                AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_2020,
            ]
        }

        return settings
    }

    /// Build AVAssetWriter audio settings
    public var audioSettings: [String: Any] {
        [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 48000,
            AVNumberOfChannelsKey: 2,
            AVEncoderBitRateKey: audioBitRate,
        ]
    }
}
