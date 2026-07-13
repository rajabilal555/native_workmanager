import Foundation

/// Shared progress reporter for native workers.
///
/// Workers call `ProgressReporter.shared.report(...)` to emit progress updates.
/// The plugin sets `onProgress` to forward updates to Flutter's progress EventChannel.
///
/// Mirrors Android's `ProgressReporter` object to ensure consistent behaviour
/// on both platforms.
///
/// Usage from a worker:
/// ```swift
/// ProgressReporter.shared.report(
///     taskId: taskId,
///     progress: 50,
///     message: "Processing…",
///     bytesDownloaded: 512_000,
///     totalBytes: 1_024_000
/// )
/// ```
final class ProgressReporter {

    static let shared = ProgressReporter()
    private init() {}

    // MARK: - Plugin hook

    /// Set by the plugin to forward updates to Flutter's progress EventChannel.
    var onProgress: ((_ dict: [String: Any]) -> Void)?

    // MARK: - Throttle state

    /// Last reported update per task — used to suppress updates < 1% apart and support re-attaching.
    private var lastEmittedUpdates: [String: [String: Any]] = [:]
    
    /// Last progress percentage persisted to SQLite per task (5% throttle).
    private var lastPersistedProgress: [String: Int] = [:]
    
    private let lock = NSLock()

    // MARK: - Public API

    /// Get all current progress updates for running tasks.
    func getRunningProgress() -> [String: [String: Any]] {
        lock.lock()
        defer { lock.unlock() }
        var result = lastEmittedUpdates

        if #available(iOS 13.0, *) {
            for task in TaskStore.shared.allTasks() {
                guard task.status == "pending" || task.status == "running" else { continue }
                if result[task.taskId] != nil { continue }
                guard let json = task.lastProgressJson,
                      let data = json.data(using: .utf8),
                      let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                else { continue }
                var enriched = dict
                if enriched["timestamp"] == nil {
                    enriched["timestamp"] = task.updatedAt * 1000
                }
                result[task.taskId] = enriched
            }
        }
        return result
    }

    /// Report a rich progress update.
    ///
    /// - Parameters:
    ///   - taskId:          Task identifier (injected as `__taskId` by the plugin).
    ///   - progress:        Progress percentage 0–100.
    ///   - message:         Optional human-readable status line.
    ///   - bytesDownloaded: Bytes transferred so far.
    ///   - totalBytes:      Expected total bytes (-1 if unknown).
    ///   - networkSpeed:    Smoothed bytes-per-second (omit if unknown).
    ///   - timeRemainingMs: Estimated milliseconds until completion (omit if unknown).
    func report(
        taskId: String,
        progress: Int,
        message: String? = nil,
        bytesDownloaded: Int64? = nil,
        totalBytes: Int64? = nil,
        networkSpeed: Double? = nil,
        timeRemainingMs: Int64? = nil
    ) {
        let clamped = max(0, min(100, progress))

        // 1 % throttle — same filter as Android's ProgressReporter to prevent
        // flooding the Flutter bridge on large-file downloads.
        lock.lock()
        let lastUpdate = lastEmittedUpdates[taskId]
        let lastProgress = lastUpdate?["progress"] as? Int
        if let last = lastProgress, clamped != 100, abs(clamped - last) < 1 {
            lock.unlock()
            return
        }

        var dict: [String: Any] = [
            "taskId": taskId,
            "progress": clamped,
            "timestamp": Int(Date().timeIntervalSince1970 * 1000),
        ]
        if let m = message            { dict["message"]         = m }
        if let b = bytesDownloaded    { dict["bytesDownloaded"] = b }
        if let t = totalBytes         { dict["totalBytes"]      = t }
        if let s = networkSpeed       { dict["networkSpeed"]    = s }
        if let e = timeRemainingMs    { dict["timeRemainingMs"] = e }

        lastEmittedUpdates[taskId] = dict
        
        // 5% Persistence throttle
        let lastPersisted = lastPersistedProgress[taskId]
        if lastPersisted == nil || clamped == 100 || abs(clamped - (lastPersisted ?? 0)) >= 5 {
            lastPersistedProgress[taskId] = clamped
            if let data = try? JSONSerialization.data(withJSONObject: dict),
               let json = String(data: data, encoding: .utf8) {
                TaskStore.shared.updateProgress(taskId: taskId, progressJson: json)
            }
        }
        
        lock.unlock()

        onProgress?(dict)
    }

    /// Clear throttle state for a finished task (avoids stale entries accumulating).
    func clearTask(_ taskId: String) {
        lock.lock()
        lastEmittedUpdates.removeValue(forKey: taskId)
        lastPersistedProgress.removeValue(forKey: taskId)
        lock.unlock()
    }
}
