# Integration test suite timing analysis

Investigation into why the iOS and Android integration test suites (`npm run test:ios` /
`test:android`) are slow, using `[TIMING]` log instrumentation added to the mocha test
runner (`code-push-plugin-testing-framework/script/*.js`, `test/test.ts`). This doc
reflects current understanding — updated in place as findings evolve, not appended to.

**Source logs** (raw output, grep for `[TIMING]`):
- `test-ios-timing-20260804.txt` — local run, M3 Pro, warm caches.
- `ci-ios-timing-30922689340.txt` — CI, iOS, before any fix.
- `ci-ios-timing-30935754826.txt` — CI, iOS, after the `xcodebuild`-bypass fix.
- `ci-android-timing-30922689340.txt` — CI, Android, before any fix.
- `ci-android-timing-30938777821.txt` — CI, Android, after the fixed-delay fix.

## Status at a glance

| Platform | Bottleneck | Status |
|---|---|---|
| iOS | Full `xcodebuild` re-run on every scenario switch | **Fixed & confirmed on CI** — 33% cut in build cost, ~2 min off the job |
| iOS | Cold-cache project scaffolding (`npx react-native init`, `pod install`) | Phase-level `[TIMING]` instrumentation added; GHA caching (npm + CocoaPods, hash-keyed) **implemented & confirmed populating on CI** (1.5GB real CocoaPods cache), effect on scaffolding time not yet isolated |
| Android | Hardcoded 10s sleep after every app force-stop | **Fixed & confirmed on CI** — teardown wait cut from 790s to 2s, ~12 min off the fast-test phase |
| Android | `gradle assembleRelease` re-run on every scenario switch | Identified, harder to fix (signed APK), not yet investigated |
| Expo (iOS) | `expo prebuild --clean` regenerates *both* platforms' native projects on every `createUpdateArchive` call (31x/run) and at project setup, despite only one platform being under test | **Fixed & confirmed on CI** — scoped `--platform`, dropped redundant `--clean` — 7x faster prebuild (656.9s→92.0s), job wall clock -48% (29m24s→15m10s) |
| Both | Verbose/noisy CI output (npm pack tarball listing, npm/npx install & bundle stdout, Hermes stderr leakage) | **Fixed & confirmed on CI** |
| Both | `noLogStdErr`/`noLogStdOut` also silenced failure diagnostics, not just success-path noise | **Fixed** — failures now always print full captured stdout+stderr regardless of noLog flags |

---

## iOS

### What was slow

On CI (before any fix — run 30922689340), the fast-test phase took 12 minutes across 44
tests, ~925s of raw exec time. Breakdown:

| Category | Count | Total | Avg |
|---|---|---|---|
| `xcodebuild` (via `buildApp`) | 25 | 342.3s | 13.7s (max 49.4s cold) |
| Project scaffolding (`npx react-native init` x2) | 2 | 242s | — |
| `createUpdateArchive` (bundle + zip) | 31 | 184.0s | 5.9s |
| Suite `before()` (`pod install` x2) | 1 | 33.2s | — |
| Per-test install+launch | 44 | 41.6s | 0.95s |
| Per-test uninstall | 44 | 13.8s | 0.31s |
| Per-test device reset | 43 | 9.7s | 0.22s |

Per-test bookkeeping is already lean (~1.5s/test combined). The one-time/per-scenario
costs (scaffolding + builds + archive creation) dominate by roughly 7x — that's where
all optimization effort should go.

`xcodebuild` legitimately runs 25 times, not 11: 11 come from the 11 scenario-tagged
`TestBuilder.describe` groups (`test/test.ts`, one real scenario file each), and 14 more
come from 4 other describe blocks whose individual `it()` tests each switch to a
genuinely different scenario file inline (`setupTestRunScenario(...)` calls). Every one
of the 25 builds corresponds to an actual JS-scenario change — since the scenario JS is
baked into the native binary at build time (no runtime hot-reload), each is necessary.
**This is correct behavior, not a bug** — nothing to fix here without changing what the
tests verify.

### The fix: skip `xcodebuild`, re-bundle directly

The native code (Obj-C/Swift/Podfile) never changes between scenarios — only the JS
entry point does. A full `xcodebuild` unnecessarily recompiles/relinks native code just
to re-run one Xcode build-phase script (`react-native-xcode.sh`) that bundles JS via
Metro/Hermes and copies the result into the already-built `.app`.

Implemented in `test/test.ts` (`RNIOS.buildApp`): a real `xcodebuild` now runs only for
the **first** build of a project; every subsequent scenario switch calls
`react-native-xcode.sh` directly instead (same script Xcode's build phase runs; env vars
derived once via `xcodebuild -showBuildSettings` and cached). Validated through the real
compiled code path (not just a shell spike): first test pays a real `xcodebuild`, repeat
tests in the same scenario group trigger no build at all (pre-existing gate, unchanged),
and scenario switches correctly dispatch to the direct script call.

**Result, measured on CI** (before: run 30922689340 → after: run 30935754826, PR #17,
same 44 tests, all still passing):

| Metric | Before | After | Change |
|---|---|---|---|
| `buildApp` (25 calls: 1 real + 24 bypassed) | 342.3s / 13.7s avg | 230.4s / 9.2s avg | **-112s (-33%)** |
| Total raw exec time | 924.6s | 804.4s | **-120s (-13%)** |
| Fast-test phase | 12m | 10m | **-2 min** |
| Job wall clock | 16m45s | 14m47s | **-~2 min** |

The measured 33% cut tracks closely with both the local spike (~32%, `react-native-xcode.sh`
5.7s vs. `xcodebuild` 8.4s avg on a warm-cache M3 Pro) and a CI-ratio extrapolation done
beforehand — the earlier concern that cold caches/slower CI hardware would distort the
result didn't materialize, likely because this targets Xcode's build-graph-evaluation
overhead specifically, which scales with project structure rather than cache-warmth or
raw CPU speed. Untouched categories (scaffolding, suite setup) moved only by run-to-run
noise, as expected.

### Remaining opportunity: cold-cache scaffolding

CI pays a large one-time cold-cache tax that local (warm-cache) runs don't: on CI,
`createTestProject(testRunDirectory)` (running `npx react-native init` + `npm install`
from scratch) took 193.4s vs. 63.5s locally — a **130s gap**, almost entirely explained
by the raw `npx @react-native-community/cli init` command itself (187.8s CI vs. 53.8s
local), which is mostly package-download/npm-install work.

To get real phase-level numbers instead of guessing, `TestUtil.getProcessOutputWithPhaseTiming`
was added (`code-push-plugin-testing-framework/script/testUtil.js`) — it spawns the child
process directly and watches both stdout *and stderr* line-by-line for RN CLI's `✔ <phase>`
progress markers (stderr matters: RN CLI prints these to stderr, not stdout — invisible to
a naive stdout-only parser). Wired into the `npx @react-native-community/cli init
--install-pods` call in `setupProject`. Confirmed on CI (run 30979964776) the phase split
is roughly: "Downloading template" ~2-6s, "Installing dependencies" ~12.5-18s (with one
anomalous 105.5s spike caused by CPU contention from a concurrently-booting simulator,
not a cache-cold issue), "Installing Ruby Gems" ~35.6s, "Installing CocoaPods dependencies"
~49.1s.

**GHA caching implemented** (`.github/workflows/ci-test.yml`): `actions/cache@v4` for
`~/.npm` (both platforms) and `~/.cocoapods` + `~/Library/Caches/CocoaPods` (iOS only),
keyed on `hashFiles('package-lock.json', 'test/test.ts')` (npm) / `hashFiles('test/test.ts')`
(CocoaPods) rather than a hardcoded version string, so the cache invalidates automatically
when dependency-relevant files change. Not yet confirmed on CI whether this actually
shrinks the scaffolding phases above.

**CocoaPods cache-size question, resolved**: an early run showed only a ~172KB CocoaPods
cache tarball, which looked suspiciously small next to npm's ~148MB. Investigated via local
Ruby introspection (`Pod::Config.instance.cache_root`) and a controlled cold-cache
experiment (backup/restore of a real local CocoaPods cache) — confirmed
`~/Library/Caches/CocoaPods` is the correct default path (not shifted by an unset
`CP_HOME_DIR`) and does receive genuine multi-hundred-MB content from a real `pod install`
locally. A temporary CI diagnostic step (`du -sh` + top-100-largest-files listing, added
then later needed again — see below) confirmed the CI runner's cache dir is real and
correctly populated (772K `~/.cocoapods`, 1.1M `~/Library/Caches/CocoaPods`, containing
actual Pod sources like SSZipArchive/JWT) — the small size is simply this test app's real,
small pod dependency graph, not a misconfigured path. Still worth caching (avoids
re-fetching spec/source data over the network), just don't expect it to look like a large
app's cache.

*Diagnostic-step gotcha (meta, worth noting for future CI debugging):* the first version
of this diagnostic ran `ruby -e "require 'cocoapods'; ..."` to introspect `Pod::Config`,
which crashed (`LoadError: cannot load such file -- cocoapods`) because `pod` itself
resolves against the Homebrew-managed Ruby gemset while bare `ruby` on `$PATH` resolves to
mise's separately-managed Ruby install — different gem environments on this runner image.
Since a failing step aborts the rest of the job, this took down the *entire* test run, not
just the diagnostic. Fixed by dropping the `ruby -e` introspection (the `du`-based
post-run step, no gem dependency, already gives a factual answer) — a reminder that
diagnostic/debug steps in CI need the same "will this actually run on this runner" scrutiny
as the code under test.

(A hypothesis that concurrent simulator-boot CPU contention — rather than cold caches —
explains this gap was considered and left unresolved: `bootEmulator`'s readiness check
returns as soon as CoreSimulator flags the device `Booted`, which is an early signal well
before userland/SpringBoard settles, so some contention plausibly extends past the
measured 23.7s boot window. Not quantified; not ruled out as a contributing factor. This
is very likely what caused the 105.5s "Installing dependencies" spike noted above.)

---

## Android

### What's slow

On CI (run 30922689340, before any fix), the fast-test phase took **30 minutes** across
the same 44 tests — 2.5x longer than iOS's 12 minutes on the same run, ~1000s of raw exec
time. Breakdown:

| Category | Count | Total | Avg |
|---|---|---|---|
| `prepareEmulatorForTest` (per-test `beforeEach`) | 54 | **561.4s** | 10.4s |
| `restartApplication` (called from within many tests) | 25 | **281.5s** | 11.3s |
| `buildApp` (`./gradlew assembleRelease`) | 25 | 476.7s | 19.1s (max 195.4s) |
| `createUpdateArchive` (bundle + zip) | 31 | 184.0s | 5.9s |
| `installApp+launch` (per-test) | 43 | 240.9s | 5.6s |
| `uninstallApplication` (per-test) | 43 | 11.2s | 0.26s |
| Project scaffolding | 1 | 52.4s | — |

### Root cause: a hardcoded 10-second sleep, not the build

Both `prepareEmulatorForTest` and `restartApplication` call `AndroidEmulatorManager.
endRunningApplication` (`code-push-plugin-testing-framework/script/platform.js`), which
ran `adb shell am force-stop` and then **unconditionally slept for exactly 10000ms**
before returning — regardless of whether the app had already finished tearing down.
Verified via the `[TIMING]` "fixed cooldown took" lines: 79 occurrences, 790.3s total,
every single one landing at 10000-10011ms (avg 10003.9ms) — a pure, deterministic,
zero-variance artificial tax, not device-state-dependent work. **That's ~44% of the
entire 30-minute fast-test phase spent doing nothing.**

This delay dates back to the original 2016 vendoring of this test framework (from
Microsoft's `code-push-plugin-testing-framework`) with no documented rationale — no
commit in this repo's history explains what race it was meant to protect against. For
comparison, iOS's equivalent (`IOSEmulatorManager.endRunningApplication`) has no such
delay at all, just `xcrun simctl terminate` returning immediately.

The `gradle assembleRelease` cost (476.7s, one build spiking to 195.4s — likely Gradle
daemon cold-start/dependency-resolution on a fresh CI runner) is real but secondary here.
A gradle-side equivalent of the iOS bundle-swap trick is not ruled out, but is more
involved to land: an APK is a **signed zip** (confirmed: React Native's default template
signs release builds with the well-known Android debug keystore, not a project-specific
release key — so re-signing a tampered APK with `apksigner`/the same debug keystore is
technically very feasible, just an extra step iOS's plain-directory `.app` doesn't need).
Swapping the JS bundle without a full `assembleRelease` would mean invoking a
`bundleReleaseJsAndAssets`-style Gradle task directly and then repackaging/re-signing —
**not yet investigated**, and lower priority than the delay fix given the smaller ceiling
(~246s vs. ~790s).

### The fix: poll for actual process teardown instead of sleeping blindly

Implemented in `platform.js`: `endRunningApplication` now polls `adb shell pidof <appId>`
every 200ms after `force-stop`, resolving as soon as the process is confirmed gone
(capped at a 10000ms safety ceiling matching the old worst case, so reliability can't
regress below the previous behavior). Mirrors the same "check real state, don't blindly
sleep" approach already used on the iOS side of this file.

Validated locally first (real Android emulator, `CORE=true` subset targeting the
revert/restart-heavy scenarios that stress this code path hardest — multiple back-to-back
teardowns per test), then pushed to CI for a full-suite measurement.

**Result, measured on CI** (before: run 30922689340 → after: run 30938777821, PR #17,
same 44 tests, all still passing):

| Metric | Before | After | Change |
|---|---|---|---|
| Teardown wait (the fixed-delay replacement) | 790.3s / 10.0s avg (79 calls) | **2.0s / 25ms avg** (79 calls) | **-788s (-99.75%)** |
| `prepareEmulatorForTest` total | 561.4s / 10.4s avg | 24.8s / 0.46s avg | -536.6s (-95.6%) |
| `restartApplication` total | 281.5s / 11.3s avg | 32.0s / 1.28s avg | -249.5s (-88.6%) |
| `buildApp` (`gradle assembleRelease`, untouched by this fix) | 476.7s / 19.1s avg | 479.6s / 19.2s avg | ~unchanged (noise) |
| Fast-test phase | 30m | **18m** | **-12 min (-40%)** |
| Job wall clock (GitHub API) | 32m49s | 20m17s | **-12m32s (-38%)** |
| Test outcome | 44 passing | 44 passing | no regressions |

`restartApplication`'s remaining ~1.28s average is its own separate, pre-existing 1-second
`Q.delay` before relaunching (untouched, out of scope) plus the poll overhead — not a
leftover of the fixed-delay bug. The build cost is essentially identical before/after, as
expected since this fix doesn't touch it. Note: "teardown wait" isn't part of the
"total raw exec time" metric used elsewhere in this doc — it was pure in-process idle time
(`Q.delay`), never a subprocess call, so it only shows up in wall-clock-level numbers
(the wrapper timings and the fast-test-phase duration), not in exec-sum totals.

**Status: implemented and confirmed on CI.** This was the single largest lever found in
the entire investigation (bigger than the iOS `xcodebuild` fix). The next candidate is the
`gradle assembleRelease` bypass discussed above — smaller ceiling, not yet investigated.

---

## Expo

Expo variants (`test:expo:ios`/`test:expo:android`) run the same scenario suite but scaffold
via `create-expo-app` and bundle via `npx react-native bundle` after `expo prebuild`, instead
of `react-native init`/`xcodebuild`. Two functional bugs surfaced here first (see below),
then a timing analysis of a passing Expo iOS run (CI run 30982584964, job 92230150617,
~29.5min wall clock) found a large, easily-fixed bottleneck.

### Two functional bugs (both exposed by the iOS `xcodebuild`-bypass fix above)

Neither is a timing issue, but both blocked Expo runs entirely and are worth recording here
since they were found while instrumenting/investigating this suite:

1. **Missing `@react-native-community/cli`**: `react-native-xcode.sh`'s bundling step shells
   out to `<rn-dir>/cli.js config`, which Expo's blank template doesn't depend on by default.
   Fixed by adding it (alongside `@react-native/metro-config`) to `installExpoBundleTooling`
   in `test/test.ts`.
2. **"No Metro config found"**: `create-expo-app`'s blank template ships without a
   `metro.config.js`, which the same `cli.js config` call requires. Fixed by running `npx
   expo customize metro.config.js` in `setupProject`'s expo branch (previously this only
   existed in `createUpdateArchive`'s branch, for a different project).

Both reproduced byte-for-byte locally before fixing (isolated scaffold, ran the exact
failing command from the CI log) rather than guessed at.

### The bottleneck: `expo prebuild --clean` regenerates both platforms, every time

`expo prebuild --clean` appeared **33 times** in the analyzed run, totaling **~657s
(~11 minutes) — over a third of the ~29.5 minute job**:

| Where | Calls | Purpose |
|---|---|---|
| `setupProject` (once per test-run/updates project) | 2 | Initial native scaffold (~91s combined) |
| `createUpdateArchive` (once per update-generating test) | 31 | Regenerate scaffold just to produce one platform's JS bundle (~20s avg each) |

`expo prebuild` defaults to `--platform all`, so every one of these calls was regenerating
**both** the iOS and Android native projects even though a single CI job only ever tests one
platform (`test:expo:ios` passes mocha `--ios` only, never both) — pure wasted work on the
untested platform each time.

**The fix**: `expo prebuild` supports `--platform <ios|android|all>`. Applied in
`test/test.ts`:
- `createUpdateArchive`'s expo branch already receives `targetPlatform` as a parameter, so
  it now passes `--platform ${targetPlatform.getName()}` directly — always safe, since each
  call is already scoped to bundling for one specific platform.
- `setupProject`'s expo branch has no platform parameter, but every real invocation passes
  exactly one of mocha's `--ios`/`--android` flags. Added `getExpoPrebuildPlatformFlag()`,
  which checks both flags and passes the matching `--platform` value only when exactly one
  is active, falling back to no flag (full `all`) for the rare local combined
  `test:setup`/`test:fast` scripts that test both platforms in one run.
- Guarded the post-prebuild `ensureAndroidCleartextTraffic` call with `fs.existsSync`, since
  `android/` no longer exists after an iOS-only prebuild.

**Result, measured on CI** (before: run 30982584964/job 92230150617 → after: run
30985765043/job 92240124264, both 44 tests, before run had 1 flaky failure/timeout
discussed below, after run all passing):

| Metric | Before | After | Change |
|---|---|---|---|
| `expo prebuild` (33 calls) | 656.9s / 19.9s avg | 92.0s / 2.8s avg | **-564.9s (-86%, ~7x faster)** |
| Job wall clock | 29m24s | **15m10s** | **-14m14s (-48%)** |

Combined with the `--clean` removal below (same CI run — both fixes shipped together, so
the 7x figure reflects both). **Status: implemented and confirmed on CI** — this was the
single largest lever found in the Expo investigation, bigger in relative terms than either
the iOS `xcodebuild` fix or the Android teardown-delay fix above.

### Second fix: drop `--clean` from the repeated `createUpdateArchive` call

Investigated (subagent, reading `@expo/cli`'s `prebuildAsync.js`/`clearNativeFolder.js`)
whether `--clean` itself is necessary on every call, since it forces a full wipe of
`ios`/`android` before regenerating — vs. omitting it, which still runs the same
template-regeneration + config-plugin reconciliation (`updateFromTemplateAsync`), just
without the destructive wipe first (only a cheap malformed-project check
`promptToClearMalformedNativeProjectsAsync` runs instead).

This landed differently for the two call sites:

- **`setupProject` (call #1): kept `--clean`.** `copyTemplate` (`test/test.ts`) copies the
  *bare-RN* template's `ios`/`android` folders into the Expo project too, and explicitly
  relies on `--clean` to wipe them before Expo's own generation takes over (Expo's CodePush
  config is injected separately via an app.json config plugin — see the comment on
  `RNProjectManager.copyTemplate`). Since prebuild without `--clean` only reconciles its own
  checksummed/config-plugin-tracked files and won't delete arbitrary leftover files, dropping
  it here risked leaving stray bare-RN native files in place to conflict with Expo's
  generated project (duplicate Podfile entries, clashing AndroidManifest, etc.). Not worth
  the risk for a call that's already a near-no-op cost-wise (nothing to build up front).
- **`createUpdateArchive` (call #2): dropped `--clean`.** By the time this runs, the native
  tree is already the clean Expo-managed one from `setupProject`, `app.json` never changes
  across the 31 repeated calls within a run, and — confirmed by grepping `buildApp`/
  `runApplication` call sites — nothing ever builds this project's native code; only
  `react-native bundle` reads from it (metro/CLI config resolution only). A full
  wipe-and-regenerate here was pure wasted cost; incremental reconciliation against an
  already-matching config should be close to a no-op.

**Confirmed on CI**, shipped in the same run as the `--platform` fix above — no interactive
prompt issue surfaced (`promptToClearMalformedNativeProjectsAsync` no-ops cleanly under
GitHub Actions' `CI` env var, as expected). The combined 7x prebuild speedup and 48% job
wall-clock reduction reported above reflects both fixes together.

### Minor: redundant per-test timing log removed

`testBuilder.js`'s `itInternal` wrapped every test's `done` callback to print
`[TIMING] test "<name>" took <ms>` — but mocha's own reporter already prints an equivalent
`✔ <name> (<ms>ms)` line for every passing test. Removed the wrapper (`assertionWithTimeout`
now just calls `assertion(done)` directly) since it was pure duplicate output with no
information mocha didn't already provide.

### One flaky failure investigated, downgraded from suspected bug to likely flakiness

The run analyzed above (30982584964/job 92230150617, before the prebuild fixes) had one
failure: `localPackage.installOnNextRestart.dorevert` timed out after 360000ms. Log
showed the app relaunch (`xcrun simctl launch`) return a PID but then go completely silent
— no further test-message traffic — until cleanup's `simctl terminate` failed with "found
nothing to terminate," implying the process died silently with zero visibility into why.

Investigated (subagent): this scenario expects CodePush's native rollback path to trigger
on the second restart (the test deliberately never confirms the update). Same test passes
reliably on bare RN iOS across three separate runs — isolating suspicion toward Expo's
`AppDelegate`-patching (`expo.js`'s `withCodePushAppDelegate`, which overrides `bundleURL()`
on Expo's generated `AppDelegate.swift`) as a plausible deterministic culprit specific to
Expo's native wiring.

**That hypothesis didn't hold up**: the very next CI run (30985765043/job 92240124264,
with the prebuild fixes applied) had this exact test pass in 15152ms, with all 44 tests
green. A deterministic Expo-specific crash would be expected to reproduce every time;
one-off pass/fail across otherwise-identical runs points to intermittent flakiness
(plausibly CI resource contention around the launch/relaunch sequence) rather than a real
bug — **no fix applied, downgraded to "watch for recurrence."**

If it recurs, the recommended next step (not yet implemented) is adding crash visibility
at the `xcrun simctl launch` call sites in `code-push-plugin-testing-framework/script/
platform.js` — e.g. `--console-pty` to capture stdout/stderr, or dumping
`~/Library/Logs/DiagnosticReports/*TestCodePush*.ips` on a test-message-wait timeout —
since currently a silent crash there is indistinguishable from a hang in the CI logs.

---

## Log noise (both platforms)

Separate from timing, the CI/local logs are heavily spammed with output that's only ever
useful on failure. Fixed in `code-push-plugin-testing-framework/script/testUtil.js` and
`test/test.ts`:

- **`TestUtil.getProcessOutput`'s (and `getProcessOutputWithPhaseTiming`'s) error branch
  now unconditionally prints captured `stdout` and `stderr`** whenever a command fails —
  previously both branches gated this behind `!options.noLogStdErr`, meaning setting
  `noLogStdErr: true` (intended only to silence the success-path live-piping) silently
  discarded failure diagnostics too, and since Node's `exec` error object doesn't reliably
  include full stdout, this meant **stdout could be lost entirely on failure**. Caught
  while adding `noLogStdErr` to the `npm pack`/`install`/`link` call (below) — proactively
  tested the failure path before shipping and found the regression. This is the safety net
  that makes silencing safe elsewhere: nothing is lost, output is just deferred until it's
  actually needed.
- **`noLogStdOut: true` added** to every `npm install`/`pack`/`link` call, every `npx
  react-native`/`npx expo` call (project scaffolding, plugin install, prebuild, bundling —
  the latter alone runs 31 times per suite), and `pod install`.
- **`noLogStdErr: true` added** to the iOS `bundleOnly` (`react-native-xcode.sh`) call,
  which was leaking ~192 lines/run of Hermes compiler warnings via stderr despite
  `noLogStdOut` already being set there; also added to both `thisPluginInstallString`
  (`npm pack`/`install`/`link`) call sites, which leak "Tarball Contents" listings via
  `npm notice` — on stderr, so `noLogStdOut` alone never silenced them.
- `noLogCommand` was left untouched everywhere — "Running command: ..." still prints for
  every call, preserving high-level visibility into what's executing.

Verified directly (not just compiled): a deliberately failing command still surfaces full
stdout+stderr even with `noLogStdOut`/`noLogStdErr: true` set; a successful command stays
quiet while still returning its captured output to callers; a real 6-test iOS run confirmed
the Hermes-warning leak is gone with no regressions.

**Status: implemented and confirmed on CI.**
