import XCTest
@testable import CodePushCore

final class ProgressThrottleTests: XCTestCase {
    private var time: TimeInterval = 1000
    private var throttle: ProgressThrottle!

    override func setUp() {
        super.setUp()
        throttle = ProgressThrottle(interval: 0.1, now: { [unowned self] in self.time })
    }

    func testSendsFirstChunkImmediately() {
        XCTAssertTrue(throttle.shouldSend(expectedBytes: 300, receivedBytes: 100))
    }

    func testDoesNotSendWithinInterval() {
        XCTAssertTrue(throttle.shouldSend(expectedBytes: 300, receivedBytes: 100))
        time += 0.05
        XCTAssertFalse(throttle.shouldSend(expectedBytes: 300, receivedBytes: 200))
        time += 0.049
        XCTAssertFalse(throttle.shouldSend(expectedBytes: 300, receivedBytes: 250))
    }

    func testSendsAfterInterval() {
        XCTAssertTrue(throttle.shouldSend(expectedBytes: 300, receivedBytes: 100))
        time += 0.1
        XCTAssertTrue(throttle.shouldSend(expectedBytes: 300, receivedBytes: 200))
    }

    func testIntervalCountsFromLastSendNotLastChunk() {
        XCTAssertTrue(throttle.shouldSend(expectedBytes: 300, receivedBytes: 100))
        time += 0.06
        XCTAssertFalse(throttle.shouldSend(expectedBytes: 300, receivedBytes: 150))
        time += 0.06
        XCTAssertTrue(throttle.shouldSend(expectedBytes: 300, receivedBytes: 200))
    }

    func testSendsWhenClockJumpsBackwards() {
        XCTAssertTrue(throttle.shouldSend(expectedBytes: 300, receivedBytes: 100))
        time -= 60
        XCTAssertTrue(throttle.shouldSend(expectedBytes: 300, receivedBytes: 150))
        time += 0.05
        XCTAssertFalse(throttle.shouldSend(expectedBytes: 300, receivedBytes: 200))
    }

    func testSendsCompletedProgressWithinInterval() {
        XCTAssertTrue(throttle.shouldSend(expectedBytes: 300, receivedBytes: 100))
        time += 0.01
        XCTAssertTrue(throttle.shouldSend(expectedBytes: 300, receivedBytes: 300))
    }

    func testThrottlesUnknownSizeUntilCompleted() {
        XCTAssertTrue(throttle.shouldSend(expectedBytes: -1, receivedBytes: 100))
        time += 0.01
        XCTAssertFalse(throttle.shouldSend(expectedBytes: -1, receivedBytes: 300))
        // The downloader reports the final size once the response ends.
        XCTAssertTrue(throttle.shouldSend(expectedBytes: 300, receivedBytes: 300))
    }

    func testBoundsEventRateForManySmallChunks() {
        // 1 MB in 1 KB chunks, one every millisecond: one second of downloading.
        let total: Int64 = 1024 * 1024
        var sent: [Int64] = []
        for chunk in 1...1024 {
            time += 0.001
            let received = Int64(chunk) * 1024
            if throttle.shouldSend(expectedBytes: total, receivedBytes: received) {
                sent.append(received)
            }
        }

        XCTAssertLessThanOrEqual(sent.count, 12)
        XCTAssertGreaterThanOrEqual(sent.count, 10)
        XCTAssertEqual(sent.last, total)
    }
}
