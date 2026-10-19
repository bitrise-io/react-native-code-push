---
name: verify-codepush
description: "Drive react-native-code-push's real behavior (check/download/install/rollback/sync) inside a real RN app on an iOS simulator or Android emulator, and prove it end to end. Use when asked to verify a CodePush change actually works end-to-end, not just that unit/type checks pass."
---

# Verify react-native-code-push

`@bitrise/code-push-sdk` is a native module with no user interface. You must prove that the **JS CodePush API** operates correctly in a real RN app. The app runs natively on a simulator or emulator and connects to a local server. The E2E harness (`test/test.mts` + `code-push-plugin-testing-framework/`) does this. This skill tells you how to drive the harness for one behavior and how to read the proof.

The harness does not look at the screen. On each CodePush lifecycle callback (`checkUpdateSuccess`, `downloadSuccess`, `installSuccess`, `onSyncStatus`, `readyAfterUpdate`, ...), the scenario app sends `POST /reportTestMessage` to the local server. The proof is the ordered sequence of these messages. Some tests also relaunch, resume, or suspend the app and read a second sequence.

This skill covers bare RN only. The Expo variants (`test:setup:expo:*`, `test:fast:expo:*`) use `create-expo-app` and `expo prebuild`, so their setup is different.

## Launch

**Sandboxed shells (e.g. Claude Code's default Bash sandbox) cannot drive this harness.** `xcrun simctl` and `adb` need an IPC/XPC connection to CoreSimulatorService. A sandboxed *nested* process loses this connection, even when the user allowlists `xcrun` and `adb`. `npm run test:setup:*`, `npm run test:fast:*`, and `doctor.sh` all use `simctl`/`adb`, so they always fail in the sandbox.

1. **Install dependencies once**:
   ```
   npm run setup          # npm install + build:ts -> lib/
   ```
   Run this again after every rebase or pull. Stale `node_modules` (for example an old TypeScript) makes `npm pack` fail in `build:ts` during `test:setup:*`, and the doctor does not detect it.
   Mocha runs the `.mts` test sources directly (Node type-stripping), so tests need no build step. An edit to `test/*.mts` takes effect on the next run. `npm run typecheck:tests` (`tsc --noEmit`) is the only place type errors in `test/` get caught. The harness does not need the local `lib/`, because `npm pack` runs `prepare`, which builds `lib/` again.

2. **Provision the test app.** Run one of these commands:
   ```
   npm run test:setup           # iOS and Android
   npm run test:setup:ios
   npm run test:setup:android
   ```
   Setup does these steps:
   - It boots the simulator/emulator of each selected platform. Only this step depends on the platform. With `CLEAN=true`, it stops the device first and then boots it again. On iOS, this runs `xcrun simctl shutdown all`, which shuts down **all** booted simulators. On Android, it runs `adb emu kill`. Boolean variables (`CLEAN`, `CORE`, `NPM`) are true only for the exact value `true` (any case). `CLEAN=1` is silently ignored.
   - It deletes the existing projects. Then it creates the test app at `$TMPDIR/@bitrise/code-push-sdk/test-run/TestCodePush`, and a mirror under `.../updates/TestCodePush` that builds update packages.
   - For each project, it runs `npx @react-native-community/cli init ... --install-pods`. This runs `pod install` with the default RN Podfile.
   - It copies all of `test/template/` over each project and installs the plugin with `npm pack`.

   Setup does not patch native files, build, or run the app. It exits 0 when it is ready.

   Setup creates the same project for iOS and Android. Thus one setup is sufficient for both platforms. Run setup again only after you change SDK sources, `test/template/`, or dependencies (see **Drive**).

3. **Drive scenarios (fast loop).** `test:fast:*` does not provision. The first `test:fast:*` run for a platform after a setup also prepares that platform:
   - iOS: it copies `test/template/ios/Podfile` over the default Podfile and runs `pod install` again. Then it sets the Info.plist keys, patches `project.pbxproj`, and copies the AppDelegate.
   - Android: it patches `app/build.gradle`, `AndroidManifest.xml`, and `strings.xml` (server URL, deployment key, public key).

   The harness records the platform in `platforms.json` **before** it prepares the platform. Later runs skip the preparation. Thus, if the first `test:fast:*` run fails during preparation, all later runs use a half-prepared app. To recover, run `npm run test:setup` again. Do not only delete `platforms.json`, because the Android `build.gradle` patch then applies two times.

   Pod problems can come from setup (default Podfile) or from the first `test:fast:ios` run (template Podfile). Plist and manifest problems come only from the first `test:fast:*` run.

   Build cost: a `test:fast:*` run builds the app again when it starts a new scenario. On iOS, only the first build in a run is a full `xcodebuild`. Later scenarios only bundle the JS again. On Android, each scenario runs `gradlew assembleRelease`. Each test case installs and launches the app again:
   ```
   npm run test:fast:ios
   npm run test:fast:android
   ```
   To run one test case or scenario, add `-- --grep '<pattern>'` (see **Drive**). `--grep` is a standard mocha CLI flag. `CORE=true` runs only the core tests.

**Teardown**: `test:fast:*` uninstalls the app before each test case. A `beforeEach` also terminates the app (iOS) or force-stops it and clears its data with `pm clear` (Android). It does not stop the simulator/emulator, so the next run can use it again. There is no teardown script. See **Cleanup** for what to remove.

**Isolation warning**: run only one verification pass per platform on a machine at a time. The harness targets the device with `xcrun simctl ... booted` and with `adb` without `-s`. Thus two passes install, launch, and uninstall on the same device. `IOS_EMU` / `ANDROID_EMU` select only the device that setup boots, and the iOS `xcodebuild` destination. They do not select the device that the tests drive. For the same reason, keep exactly one simulator booted and one Android device attached.

An iOS pass and an Android pass can run at the same time only with different `RUN_DIR` / `UPDATE_DIR` values. By default, both platforms use the same project directories, and each pass writes its scenario files and bundles there. The acquisition servers do not collide. `IOS_SERVER` / `ANDROID_SERVER` have different default ports (`http://127.0.0.1:3000` and `http://10.0.2.2:3001`). The server listens on the port in this URL, so an override must include a port.

## Doctor

The doctor is a read-only check. It tells you if the machine is safe to drive `test:fast:<platform>` now. Run it before each pass, outside the sandbox:
```
.agents/skills/verify-codepush/scripts/doctor.sh ios       # or: android, or no arg for both
```
It works from any cwd. It checks these items for the selected platforms, and exits 1 if one check fails:
- `node_modules/` exists.
- The platform tools are on `PATH`.
- The test app and the update app exist at the paths the harness uses (including `RUN_DIR`/`UPDATE_DIR` overrides).
- The test app has the current SDK sources and `test/template/`. The doctor compares the files that `npm pack` ships with the SDK copy in the app. For `src/` and `test/template/`, it compares mtimes with the last setup. If there is a difference, the app does not contain your change. With `NPM=true`, the app uses the published SDK, so the doctor skips this check.
- Exactly one simulator is booted, or exactly one adb entry exists. `test:fast:*` does not boot a device.
- The doctor can bind the acquisition server port. If the port is in use, another run is probably active.

If `simctl`/`adb` fail, the doctor shows the error as a FAIL. Usually, the cause is a sandboxed shell. The doctor always shows the `RUN_DIR` it uses, because a sandboxed shell has a different `TMPDIR` than the harness.

## Drive

Select a behavior of the SDK. Run its test with mocha's `--grep`, for example:

```
npm run test:fast:ios -- --grep 'checkForUpdate.noUpdate$'
```

The `$` anchor is necessary because mocha's `--grep` is an unanchored regex. Without it, the pattern also matches `checkForUpdate.noUpdate.updateAppVersion`. Use single quotes, because fish rejects a `$` at the end of a double-quoted string.

This runs only the matching `it()` cases. You do not have to set up the scenario manually. `test/test.mts` sets up scenarios in one of two ways:
- Most `describe()` blocks pass a `scenarioPath` (a file under `test/template/scenarios/`). A `before()` hook calls `setupScenario(...)` with it. Mocha runs this hook one time for each `describe()` block, not for each test. Also, `setupScenario` does nothing if the scenario is already the current one. Thus all tests in a block use the same app build, and a test must not depend on state from an earlier test.
- Some blocks have no `scenarioPath`. There, each `it()` calls `setupTestRunScenario(...)` with its own scenario. Examples: `#window.codePush.sync mandatory install mode tests`, `#window.codePush.sync minimum background duration tests`, and `#codePush.disallowRestart`. When you add or change a case in such a block, set up the scenario in the `it()`.

For each test case:
- The test body sets the server response and the expected message sequence, with `ServerUtil.updateResponse` / `updateCheckCallback` / `testMessageCallback`.
- `projectManager.runApplication(TestConfig.testRunDirectory, targetPlatform)` uninstalls, installs, and launches the app.
- The app's `index.js` calls the scenario module, which sends messages with `POST /reportTestMessage`. The test passes if `ServerUtil.expectTestMessages([...])` (or the `testMessageCallback` assertion) matches the sequence.
- Resume, suspend, and restart use `targetPlatform.getEmulatorManager()` (`code-push-plugin-testing-framework/script/platform.js`), for example `.restartApplication(...)` or `.resumeApplication(...)`. These run `xcrun simctl`/`adb shell` directly. There is no UI automation.

The harness streams native device logs into the console: `xcrun simctl spawn booted log stream --style ndjson --level info --predicate 'eventMessage CONTAINS "[CodePush]"'` for iOS, and `adb logcat -v brief -T 1 ReactNative:D ReactNativeJS:D *:S` for Android. The console shows the forwarded lines with a `[DEVICE]` prefix. Use them for diagnostics only. The tests do not assert on them.

**SDK source changes require a new setup.** Setup installs the plugin with `npm pack`, so the app's `node_modules/@bitrise/code-push-sdk` is a copy. Edits to shipped files (`ios/`, `android/`, `CodePush.js`, `src/`, ...) have no effect on `test:fast:*` until you run `test:setup` again.

**Make test app changes in `test/template/`.** Setup copies `test/template/` (native files and JS scenarios) over a new app. The next setup deletes all edits that you make in `$TMPDIR/.../TestCodePush`.

## Evidence

- **Primary proof**: the ordered `reportTestMessage` sequence that the mocha assertion checked. A green mocha run for the `--grep` pattern is the proof. Keep the console output as the artifact: the mocha summary, and the `[TIMING]` and message lines. The messages are the `ServerUtil.TestMessage.*` constants: `CHECK_UP_TO_DATE`, `CHECK_UPDATE_AVAILABLE`, `DOWNLOAD_SUCCEEDED`, `DOWNLOAD_ERROR`, `UPDATE_INSTALLED`, `UPDATE_FAILED_PREVIOUSLY`, `DEVICE_READY_AFTER_UPDATE`, `SYNC_STATUS`, and more.
- **Rollback/persistence proof.** One successful install does not prove rollback behavior. For "an update stays" or "an update reverts", the test relaunches, resumes, suspends, or restarts the app. Then it asserts a *second* message sequence. Read the test body in `test/test.mts`, and make sure that the console output shows the second sequence.
- **Read the passing count.** "0 passing" means that the `--grep` pattern matched no test. This is not proof.
- **On failure (iOS)**: a root `before()` records the contents of `~/Library/Logs/DiagnosticReports` one time at the start of the run. After each failed test, `afterEach` copies all reports that are new since then to `test/crash-logs/`. If an iOS run fails with no clear assertion error, look there first. A report can come from an earlier test that passed, or from a different macOS app, so read the process name and the time in the report.
- **On failure (Android)**: the harness collects no Android crash reports. Find the crash in the `adb logcat` output in the console. The `afterEach` hook also runs on Android, so `.ips` files in `test/crash-logs/` from an Android run are macOS crashes, not app crashes.
- There are no screenshots and no JSON report. The mocha console output is the artifact. To keep it after the terminal closes, write it to a file in a scratch directory.

## Cleanup

- The harness uses the same simulator/emulator for many runs. Do not shut it down, unless you booted it for this run.
- **Remove only what you created.** If you set `RUN_DIR`/`UPDATE_DIR` overrides for this run, remove only those directories. Do not remove the default `RUN_DIR`/`UPDATE_DIR` or the simulator that was booted when you started. Another run can use them.
- Do not delete `test/crash-logs/*.ips`. They are the evidence for earlier failed runs.

## Helpers

- `.agents/skills/verify-codepush/scripts/doctor.sh [ios|android]`: see **Doctor**.
