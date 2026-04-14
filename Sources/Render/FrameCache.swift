import Foundation
import CoreVideo

/// LRU cache for decoded video frames to avoid re-decoding during scrubbing.
public final class FrameCache {
    private struct CacheEntry {
        let buffer: CVPixelBuffer
        let accessTime: Date
    }

    private var cache: [String: CacheEntry] = [:]
    private let maxEntries: Int
    private let lock = NSLock()

    /// Create a frame cache with a maximum number of entries
    public init(maxEntries: Int = 60) {
        self.maxEntries = maxEntries
    }

    /// Cache a pixel buffer for a given time on a given track
    public func set(_ buffer: CVPixelBuffer, forTrack trackId: UUID, at time: Double) {
        let key = cacheKey(trackId: trackId, time: time)
        lock.lock()
        defer { lock.unlock() }

        cache[key] = CacheEntry(buffer: buffer, accessTime: Date())

        // Evict oldest entries if over limit
        if cache.count > maxEntries {
            let sorted = cache.sorted { $0.value.accessTime < $1.value.accessTime }
            let toRemove = cache.count - maxEntries
            for (key, _) in sorted.prefix(toRemove) {
                cache.removeValue(forKey: key)
            }
        }
    }

    /// Get a cached pixel buffer
    public func get(forTrack trackId: UUID, at time: Double) -> CVPixelBuffer? {
        let key = cacheKey(trackId: trackId, time: time)
        lock.lock()
        defer { lock.unlock() }

        guard var entry = cache[key] else { return nil }
        entry = CacheEntry(buffer: entry.buffer, accessTime: Date())
        cache[key] = entry
        return entry.buffer
    }

    /// Clear all cached frames
    public func clear() {
        lock.lock()
        defer { lock.unlock() }
        cache.removeAll()
    }

    /// Clear cached frames for a specific track
    public func clear(forTrack trackId: UUID) {
        let prefix = trackId.uuidString
        lock.lock()
        defer { lock.unlock() }
        cache = cache.filter { !$0.key.hasPrefix(prefix) }
    }

    private func cacheKey(trackId: UUID, time: Double) -> String {
        // Round to nearest frame at 30fps for cache coherency
        let roundedTime = (time * 30).rounded() / 30
        return "\(trackId.uuidString)_\(roundedTime)"
    }
}
