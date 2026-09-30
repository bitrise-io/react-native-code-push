# AGENTS.md

## Project Overview

React Native CodePush is a native module that enables over-the-air updates for React Native apps. It consists of native implementations for iOS (Objective-C), Android (Java), and Windows (C++), unified through a JavaScript bridge layer.

## Development Commands

### Testing

#### Unit tests

- `npm run test:unit:android`
- `npm run test:unit:ios`

Prefer unit testing what's possible (even though, on iOS, this involves a simulator). Legacy code used E2E tests for everything, which is complex, error-prone, and slow. The existing E2E tests are still useful, but this is not a pattern to follow.

#### E2E Tests
- `npm run typecheck:tests` - Lints and type-checks `test/`. Mocha runs the `.mts` test sources directly via Node's native TypeScript type-stripping, so this is the only place type errors in `test/` get caught.
- `npm run test:android` - Run Android-specific tests
- `npm run test:ios` - Run iOS-specific tests  
- `npm run test:setup:android` - Set up Android emulator for testing
- `npm run test:setup:ios` - Set up iOS simulator for testing

### Build
- `npm run typecheck` - Type-checks the library sources in `src/`
- `npm run build:ts` - Runs `react-native-builder-bob`, which compiles `src/` to `lib/`. `lib/` is what ships to consumers.
  - Bob writes one folder per target: `lib/commonjs/` (JS, compiled by Babel with the React Native preset from `babel.config.js`) and `lib/typescript/` (`.d.ts` files from `tsc`). `CodePush.js` imports from `lib/commonjs/` today, but that file should be broken up and refactored to TS over time.
  - Babel only strips types, so `tsc` (`npm run typecheck`) is the only thing that catches type errors in `src/`.
  - Only `commonjs` is emitted on purpose: it is the module format consumers already get, and this package must not ship breaking changes. Adding a `module` (ESM) target, and possibly an `exports` map, belongs in a future major release.
  - The public types stay hand-written in `typings/`. The `.d.ts` files bob generates in `lib/typescript/` are not used by consumers today, but we might want to automate this in the future.

### Conventions for writing new code

- Write new runtime code in TypeScript under `src/`, not in `CodePush.js` or other root-level `.js` files. The goal is to migrate the root JS to TypeScript over time, so avoid growing `CodePush.js`. Small changes to existing root JS are fine.
- Import compiled code from the root JS via `lib/commonjs/...` (for example `./lib/commonjs/acquisition-sdk/acquisition-sdk`).
- Write new Android-specific code in Kotlin with unit-testing in mind. Do not bloat existing Java files with large additions.

### Platform Testing
- Tests run on actual emulators/simulators with real React Native apps
- Test apps are created dynamically outside the repo, under a system temp `test-run` directory (not inside `test/`)
- Both old and new React Native architecture testing supported

## Architecture

### Core Components
- **JavaScript Bridge** (`CodePush.js`): Main API layer exposing update methods
- **Native Modules**: Platform-specific implementations handling file operations, bundle management
- **Update Manager**: Handles download, installation, and rollback logic
- **Acquisition SDK** (`src/acquisition-sdk/`): Manages server communication and update metadata

### Platform Structure
- **iOS**: `ios/` - Objective-C implementation with CocoaPods integration
- **Android**: `android/` - Java/Kotlin implementation with Gradle plugin
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
- **No unit test infra for JS yet**: JS only has the mocha-based integration suite above. `src/acquisition-sdk/__tests__/` contains tests ported from upstream `microsoft/code-push`, kept for future reference - they are deliberately not wired into `npm test` or any runner. Don't assume they're dead/forgotten code, and don't wire them in without setting up real unit test infra first.
- **Templates**: `test/template/` holds native files (Podfile, AppDelegate, Android app files) and JS scenarios copied over top of a freshly generated RN/Expo app during test setup, overwriting its defaults — edit files here, not the generated project, for changes to persist
- **`test:ios` vs `test:setup:ios` vs `test:fast:ios`**: `test:ios` is just `test:setup:ios` followed by `test:fast:ios` — the two are meant to be split apart for local iteration.
  - `test:setup:ios` (mocha `--ios --setup`) boots the simulator and provisions the test app once: copies templates, runs `pod install`, patches Info.plist/AppDelegate. It never builds or runs any test scenario.
  - `test:fast:ios` (mocha `--ios`) skips provisioning and goes straight to the actual test scenarios: its `before()` hook calls `RNIOS.buildApp` (`xcodebuild` against the already-provisioned `.xcworkspace`) and installs the binary, then runs the update/rollback/error scenarios.
  - For the fast local loop: run `test:setup:ios` once per template/dependency change, then re-run `test:fast:ios` repeatedly while iterating on test/scenario code — this skips `pod install` and re-provisioning on every iteration.
  - There's still no "just build, no tests" npm script — for a raw build only, lift the `xcodebuild` invocation out of `RNIOS.buildApp` in `test/test.mts` and run it by hand against the provisioned `TestCodePush.xcworkspace`.
- When debugging a CI failure, don't trust the first plausible-looking theory from log noise — reproduce the exact failing command locally on matching hardware/toolchain before writing up a root cause. This is faster than iterating against multi-hour CI runs and catches wrong hypotheses early.
- `npm run test:setup:ios` provisions a full test app outside the repo (under a system temp/`test-run` dir), not inside `test/` — expect to search for it rather than finding it checked into the repo tree.
- The provisioned test app's `node_modules/@bitrise/code-push-sdk` is a real copy, not a symlink — editing `ios/` (or `android/`) native source in the repo has zero effect on `test:fast:ios` runs until you re-copy those files into that `node_modules` path (or rerun `test:setup:ios`).

### Build Integration
- **Android Gradle Plugin**: Automatically generates bundle hashes and processes assets
- **iOS CocoaPods**: Manages native dependencies and build configuration
- **Bundle Processing**: Automated zip creation and hash calculation for OTA updates
- **`.npmignore` is a blocklist, not an allowlist**: `package.json` has no `files` field, so any new top-level file/dir ships to npm by default unless explicitly excluded. When adding new repo tooling/config, check whether it needs a `.npmignore` entry. Verify with `npm pack --dry-run`.
