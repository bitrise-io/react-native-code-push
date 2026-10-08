# AGENTS.md

## Project Overview

React Native CodePush is a native module that enables over-the-air updates for React Native apps. It consists of native implementations for iOS (Objective-C) and Android (Java), unified through a JavaScript bridge layer.

## Development Commands

### Testing

#### Unit tests

- `npm run test:unit:android`
- `npm run test:unit:ios`

Prefer unit testing what's possible (even though, on iOS, this involves a simulator). Legacy code used E2E tests for everything, which is complex, error-prone, and slow. The existing E2E tests are still useful, but this is not a pattern to follow.

#### Lint
- `npm run lint` (`lint:fix` to autofix)

#### E2E Tests
- `npm run typecheck:tests` - Type-checks `test/`. Mocha runs the `.mts` test sources directly via Node's native TypeScript type-stripping, so this is the only place type errors in `test/` get caught.

Use the `verify-codepush` skill (`.agents/skills/verify-codepush/`) to run iOS and Android E2E tests and to prove a behavior end to end. It explains how the harness works, and how to drive and verify one CodePush behavior. Do not duplicate E2E details in this file.

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

## Architecture

### Core Components
- **JavaScript Bridge** (`CodePush.js`): Main API layer exposing update methods
- **Native Modules**: Platform-specific implementations handling file operations, bundle management
- **Update Manager**: Handles download, installation, and rollback logic
- **Acquisition SDK** (`src/acquisition-sdk/`): Manages server communication and update metadata

### Platform Structure
- **iOS**: `ios/` - Objective-C implementation with CocoaPods integration
- **Android**: `android/` - Java/Kotlin implementation with Gradle plugin
- **JavaScript**: Root level - TypeScript definitions and bridge code

### Key Patterns
- **Higher-Order Component**: `codePush()` wrapper for automatic update management
- **Promise-based Native Bridge**: All native operations return promises
- **Platform Abstraction**: Unified JavaScript API with platform-specific implementations
- **Error Handling**: Automatic rollback on failed updates with telemetry

### Testing Notes
- **No unit test infra for JS yet**: `src/acquisition-sdk/__tests__/` contains tests ported from upstream `microsoft/code-push`, kept for future reference - they are deliberately not wired into `npm test` or any runner. Don't assume they're dead/forgotten code, and don't wire them in without setting up real unit test infra first.

### Build Integration
- **Android Gradle Plugin**: Automatically generates bundle hashes and processes assets
- **iOS CocoaPods**: Manages native dependencies and build configuration
- **Bundle Processing**: Automated zip creation and hash calculation for OTA updates
- **`.npmignore` is a blocklist, not an allowlist**: `package.json` has no `files` field, so any new top-level file/dir ships to npm by default unless explicitly excluded. When adding new repo tooling/config, check whether it needs a `.npmignore` entry. Verify with `npm pack --dry-run`.

## Troubleshooting

- When debugging a CI failure, don't trust the first plausible-looking theory from log noise. Reproduce the exact failing command locally on matching hardware/toolchain before writing up a root cause. This is faster than iterating against multi-hour CI runs and catches wrong hypotheses early.
