import Foundation

/// Limits how often download progress reaches JS.
///
/// One instance tracks one download. It isn't thread-safe: call it from one serial queue.
@objc(CPProgressThrottle)
public final class ProgressThrottle: NSObject {
    private let interval: TimeInterval
    private let now: () -> TimeInterval
    private var lastSendTime: TimeInterval?

    init(interval: TimeInterval, now: @escaping () -> TimeInterval) {
        self.interval = interval
        self.now = now
    }

    @objc public override convenience init() {
        // Not systemUptime: that's a required-reason API, and the throttle doesn't need a monotonic clock.
        self.init(interval: 0.1, now: { Date().timeIntervalSinceReferenceDate })
    }

    /// The downloader's last event always has `receivedBytes == expectedBytes`, so it's never held
    /// back. The download's done callback only runs after unzipping and verifying the update.
    @objc(shouldSendExpectedBytes:receivedBytes:)
    public func shouldSend(expectedBytes: Int64, receivedBytes: Int64) -> Bool {
        let time = now()
        // The wall clock can jump backwards. Sending restarts the interval instead of stalling.
        if receivedBytes != expectedBytes, let lastSendTime, (0..<interval).contains(time - lastSendTime) {
            return false
        }
        lastSendTime = time
        return true
    }
}
