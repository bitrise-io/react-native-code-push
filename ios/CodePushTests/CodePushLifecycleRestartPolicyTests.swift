import XCTest

final class CodePushLifecycleRestartPolicyTests: XCTestCase {

    private var now: TimeInterval = 0
    private var policy: CodePushLifecycleRestartPolicy!

    override func setUp() {
        super.setUp()
        now = 0
        policy = CodePushLifecycleRestartPolicy(clock: { self.now })
    }

    /// A full background: resign, enter the background, wait, then return to the foreground.
    @discardableResult
    private func background(for seconds: TimeInterval) -> Bool {
        _ = policy.onResignActive()
        policy.onEnterBackground()
        now += seconds
        return policy.onWillEnterForeground()
    }

    func testWillEnterForeground_onNextRestart_neverRestarts() {
        _ = policy.onInstall(with: .onNextRestart, minimumBackgroundDuration: 0)

        XCTAssertFalse(background(for: 600))
    }

    func testWillEnterForeground_onNextResume_restartsOnlyAfterTheMinimum() {
        _ = policy.onInstall(with: .onNextResume, minimumBackgroundDuration: 10)

        XCTAssertFalse(background(for: 9))
        XCTAssertTrue(background(for: 10))
    }

    func testWillEnterForeground_onNextResume_withZeroMinimum_restartsAtAnyResume() {
        _ = policy.onInstall(with: .onNextResume, minimumBackgroundDuration: 0)

        XCTAssertTrue(background(for: 0))
    }

    func testWillEnterForeground_usesTheLatestInstall() {
        _ = policy.onInstall(with: .onNextResume, minimumBackgroundDuration: 0)
        _ = policy.onInstall(with: .onNextRestart, minimumBackgroundDuration: 0)

        XCTAssertFalse(background(for: 600))
    }

    func testResignActive_returnsTheSuspendDelayOnlyForOnNextSuspend() {
        _ = policy.onInstall(with: .onNextSuspend, minimumBackgroundDuration: 30)
        XCTAssertEqual(policy.onResignActive(), 30)

        _ = policy.onInstall(with: .onNextResume, minimumBackgroundDuration: 30)
        XCTAssertNil(policy.onResignActive())
    }

    func testBecomeActive_cancelsTheSuspendRestartWhenTheAppReturnedTooEarly() {
        _ = policy.onInstall(with: .onNextSuspend, minimumBackgroundDuration: 10)
        _ = policy.onResignActive()
        now += 3

        XCTAssertTrue(policy.shouldCancelSuspendRestartOnBecomeActive())

        now += 7

        XCTAssertFalse(policy.shouldCancelSuspendRestartOnBecomeActive())
    }

    func testInstall_onNextResume_appliesNowAfterALongEnoughBackground() {
        background(for: 12)

        XCTAssertTrue(policy.onInstall(with: .onNextResume, minimumBackgroundDuration: 10))
    }

    func testInstall_onNextResume_waitsAfterAShortBackground() {
        background(for: 3)

        XCTAssertFalse(policy.onInstall(with: .onNextResume, minimumBackgroundDuration: 10))
    }

    func testInstall_onNextResume_withZeroMinimum_waitsForTheNextResume() {
        background(for: 600)

        XCTAssertFalse(policy.onInstall(with: .onNextResume, minimumBackgroundDuration: 0))
    }

    func testInstall_beforeAnyBackground_neverAppliesNow() {
        XCTAssertFalse(policy.onInstall(with: .onNextResume, minimumBackgroundDuration: 10))
    }

    func testInstall_whileInTheBackground_neverAppliesNow() {
        background(for: 600)
        _ = policy.onResignActive()
        policy.onEnterBackground()

        XCTAssertFalse(policy.onInstall(with: .onNextResume, minimumBackgroundDuration: 10))
    }

    func testInstall_otherModes_neverApplyNow() {
        background(for: 600)

        XCTAssertFalse(policy.onInstall(with: .onNextRestart, minimumBackgroundDuration: 10))
        XCTAssertFalse(policy.onInstall(with: .onNextSuspend, minimumBackgroundDuration: 10))
        XCTAssertFalse(policy.onInstall(with: .immediate, minimumBackgroundDuration: 10))
    }
}
