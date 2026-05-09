import Foundation

/// AI-powered audio noise removal for cleaning up voice recordings.
// FIX(audit-2026-05-09 #A14): added @MainActor for consistency with CaptionGenerator.swift:5.
// All AI stubs carry @Published-style state; uniform MainActor isolation prevents
// threading inconsistencies when Phase 3 wires real implementations.
@MainActor
public final class AudioDenoiser {
    public init() {}

    /// Denoise audio from a file, outputting a cleaned version.
    public func denoise(
        inputURL: URL,
        outputURL: URL,
        strength: Float = 0.7,
        progress: @escaping (Double) -> Void
    ) async throws {
        // Phase 3 implementation
        // Will use Core ML model for spectral noise reduction
    }
}
