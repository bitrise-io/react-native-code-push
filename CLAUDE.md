# CLAUDE.md

## Project Overview

React Native CodePush is a native module that enables over-the-air updates for React Native apps. It consists of native implementations for iOS (Objective-C), Android (Java), and Windows (C++), unified through a JavaScript bridge layer.

## Development Commands

### Testing
- `npm test` - Run all tests with TypeScript compilation
- `npm run test:android` - Run Android-specific tests
- `npm run test:ios` - Run iOS-specific tests  
- `npm run test:setup-android` - Set up Android emulator for testing
- `npm run test:setup-ios` - Set up iOS simulator for testing

### Build
- `npm run build` - Build TypeScript tests to bin/ directory
- `npm run tsc` - TypeScript compilation

### Platform Testing
- Tests run on actual emulators/simulators with real React Native apps
- Test apps are created dynamically in `test/` directory
- Both old and new React Native architecture testing supported

## Architecture

### Core Components
- **JavaScript Bridge** (`CodePush.js`): Main API layer exposing update methods
- **Native Modules**: Platform-specific implementations handling file operations, bundle management
- **Update Manager**: Handles download, installation, and rollback logic
- **Acquisition SDK**: Manages server communication and update metadata

### Platform Structure
- **iOS**: `ios/` - Objective-C implementation with CocoaPods integration
- **Android**: `android/` - Java implementation with Gradle plugin
- **Windows**: `windows/` - C++ implementation for Windows React Native
- **JavaScript**: Root level - TypeScript definitions and bridge code

### Key Patterns
- **Higher-Order Component**: `codePush()` wrapper for automatic update management
- **Promise-based Native Bridge**: All native operations return promises
- **Platform Abstraction**: Unified JavaScript API with platform-specific implementations
- **Error Handling**: Automatic rollback on failed updates with telemetry

### Testing Framework
- **Custom Test Runner**: TypeScript-based test framework in `test/`
- **Real App Testing**: Creates actual React Native apps for integration testing
- **Scenario Testing**: Update, rollback, and error scenarios
- **Templates**: `test/template/` holds native files (Podfile, AppDelegate, Android app files) and JS scenarios copied over top of a freshly generated RN/Expo app during test setup, overwriting its defaults — edit files here, not the generated project, for changes to persist
- **`test:ios` vs `test:setup:ios` vs `test:fast:ios`**: `test:ios` is just `test:setup:ios` followed by `test:fast:ios` — the two are meant to be split apart for local iteration.
  - `test:setup:ios` (mocha `--ios --setup`) boots the simulator and provisions the test app once: copies templates, runs `pod install`, patches Info.plist/AppDelegate. It never builds or runs any test scenario.
  - `test:fast:ios` (mocha `--ios`) skips provisioning and goes straight to the actual test scenarios: its `before()` hook calls `RNIOS.buildApp` (`xcodebuild` against the already-provisioned `.xcworkspace`) and installs the binary, then runs the update/rollback/error scenarios.
  - For the fast local loop: run `test:setup:ios` once per template/dependency change, then re-run `test:fast:ios` repeatedly while iterating on test/scenario code — this skips `pod install` and re-provisioning on every iteration.
  - There's still no "just build, no tests" npm script — for a raw build only, lift the `xcodebuild` invocation out of `RNIOS.buildApp` in `test/test.ts` and run it by hand against the provisioned `TestCodePush.xcworkspace`.
- When debugging a CI failure, don't trust the first plausible-looking theory from log noise — reproduce the exact failing command locally on matching hardware/toolchain before writing up a root cause. This is faster than iterating against multi-hour CI runs and catches wrong hypotheses early.
- Before running `npm run test:setup:ios`, shut down all booted simulators (`xcrun simctl shutdown all`) — the test framework's simulator picker hangs silently (no error) if simulators are already booted outside it.
- `npm run test:setup:ios` provisions a full test app outside the repo (under a system temp/`test-run` dir), not inside `test/` — expect to search for it rather than finding it checked into the repo tree.
- The provisioned test app's `node_modules/@bitrise/code-push-sdk` is a real copy, not a symlink — editing `ios/` (or `android/`) native source in the repo has zero effect on `test:fast:ios` runs until you re-copy those files into that `node_modules` path (or rerun `test:setup:ios`).

### Build Integration
- **Android Gradle Plugin**: Automatically generates bundle hashes and processes assets
- **iOS CocoaPods**: Manages native dependencies and build configuration
- **Bundle Processing**: Automated zip creation and hash calculation for OTA updates
