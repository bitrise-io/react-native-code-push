#!/usr/bin/env bash
# Read-only check that answers "is this machine safe to drive test:fast:<platform> now?".
# Usage: .agents/skills/verify-codepush/scripts/doctor.sh [ios|android]   (default: both)
# Exits 1 if any check FAILs.
set -uo pipefail

cd "$(dirname "$0")/../../../.." || exit 1

case "${1:-both}" in
  ios) PLATFORMS=(ios) ;;
  android) PLATFORMS=(android) ;;
  both) PLATFORMS=(ios android) ;;
  *) echo "Usage: $0 [ios|android]"; exit 2 ;;
esac

ok=1
pass() { echo "OK    $1"; }
fail() { echo "FAIL  $1"; ok=0; }
info() { echo "INFO  $1"; }
check() {
  local desc="$1"; shift
  if "$@" >/dev/null 2>&1; then pass "$desc"; else fail "$desc"; fi
}

# Prints the first difference between the repo and the SDK copy in the test app, or nothing.
# Returns 1 if npm cannot list the packed files.
sdk_diff() {
  local copy="$1" packed installed d f
  # The files that npm pack ships, without lib/ (built output, checked through src/ below) and
  # .jj/ (Jujutsu state that .npmignore does not exclude; it changes on every jj command).
  # --ignore-scripts keeps prepare from building lib/, so the doctor stays read-only.
  packed=$(npm pack --dry-run --json --ignore-scripts 2>/dev/null \
    | node -e 'let s = ""; process.stdin.on("data", (d) => s += d).on("end", () => JSON.parse(s)[0].files.forEach((f) => f.path.startsWith("lib/") || f.path.startsWith(".jj/") || console.log(f.path)))' \
    | sort)
  [ -n "$packed" ] || return 1
  # The Android build of the test app writes build/, .cxx/ and .gradle/ into the SDK copy.
  installed=$(cd "$copy" && find . \( -name build -o -name .cxx -o -name .gradle -o -name node_modules -o -path ./lib \) -prune \
    -o -type f -print | sed 's|^\./||' | grep -v '^\.jj/' | sort)
  d=$(comm -3 <(echo "$packed") <(echo "$installed") | sed 's/^[[:space:]]*//' | head -1)
  if [ -n "$d" ]; then echo "$d was added or removed"; return 0; fi
  while IFS= read -r f; do
    if ! cmp -s "$f" "$copy/$f"; then echo "$f changed"; return 0; fi
  done <<<"$packed"
  # lib/ is built from src/, and the harness patches some test/template/ files after it copies
  # them. For both, compare mtimes with the SDK copy, which setup creates after the template copy.
  # Every scenario copies test/template/index.js again, so it is excluded.
  d=$(find src test/template -name __tests__ -prune -o -type f ! -path test/template/index.js -newer "$copy" -print 2>/dev/null | head -1)
  if [ -n "$d" ]; then echo "$d changed"; fi
  return 0
}

echo "== Repo build state =="
check "node_modules/ installed (npm run setup)" test -d node_modules
echo
echo "== Toolchain =="
check "node" command -v node
for p in "${PLATFORMS[@]}"; do
  case "$p" in
    ios)
      check "xcodebuild" command -v xcodebuild
      check "xcrun" command -v xcrun
      check "pod (CocoaPods)" command -v pod
      ;;
    android)
      check "adb" command -v adb
      # Only test:setup:android needs it (emulator -list-avds), so a missing binary is not a FAIL.
      if command -v emulator >/dev/null 2>&1; then
        pass "emulator (Android SDK)"
      else
        info "emulator (Android SDK) not on PATH: test:setup:android needs it"
      fi
      ;;
  esac
done

echo
echo "== Provisioned test app =="
# Resolve the same paths the harness uses, including RUN_DIR/UPDATE_DIR overrides.
if ! DIRS=$(node -e "const c = require('./code-push-plugin-testing-framework/script/testConfig.js'); console.log(c.testRunDirectory); console.log(c.updatesDirectory); console.log(c.thisPluginInstallString.startsWith('npm pack') ? 'local' : 'registry')" 2>&1); then
  fail "could not resolve RUN_DIR from testConfig.js: $(grep -m1 'Error' <<<"$DIRS" || grep -m1 . <<<"$DIRS" || echo "no output")"
else
  RUN_DIR=$(sed -n 1p <<<"$DIRS")
  UPDATE_DIR=$(sed -n 2p <<<"$DIRS")
  PLUGIN_SOURCE=$(sed -n 3p <<<"$DIRS")
  # A sandboxed shell has a different TMPDIR than the unsandboxed harness, so always show the path.
  info "RUN_DIR=$RUN_DIR"
  info "UPDATE_DIR=$UPDATE_DIR"
  check "test app provisioned (npm run test:setup*)" test -d "$RUN_DIR/TestCodePush"
  check "update app provisioned (npm run test:setup*)" test -d "$UPDATE_DIR/TestCodePush"
  # Setup installs the SDK with npm pack and copies test/template/ into the app. Later edits
  # reach the app only after a new setup.
  PLUGIN_NAME=$(node -p "require('./package.json').name")
  SDK_COPY="$RUN_DIR/TestCodePush/node_modules/$PLUGIN_NAME"
  if [ "$PLUGIN_SOURCE" = "registry" ]; then
    info "NPM is set: the test app uses the published SDK, so it does not contain local SDK edits"
  elif [ -d "$SDK_COPY" ]; then
    if ! stale=$(sdk_diff "$SDK_COPY"); then
      fail "could not list the packed files (npm pack --dry-run failed)"
    elif [ -n "$stale" ]; then
      fail "test app is stale: $stale after the last setup (npm run test:setup)"
    else
      pass "test app has the current SDK sources and test/template/"
    fi
  elif [ -d "$RUN_DIR/TestCodePush" ]; then
    fail "SDK is not installed in the test app ($SDK_COPY missing; npm run test:setup)"
  fi
  if [ -f "$RUN_DIR/platforms.json" ]; then
    info "platforms.json: $(cat "$RUN_DIR/platforms.json") (if the first test:fast:* run for a listed platform failed, run npm run test:setup again)"
  else
    info "no platforms.json: the next test:fast:* run prepares the platform first (pod install / plist and manifest patches)"
  fi
fi

echo
echo "== Devices =="
# test:fast:* never boots a device. It targets `xcrun simctl ... booted` and `adb` without -s,
# so exactly one booted device per platform is required.
for p in "${PLATFORMS[@]}"; do
  case "$p" in
    ios)
      if out=$(xcrun simctl list devices booted 2>&1); then
        n=$(grep -c "(Booted)" <<<"$out")
        if [ "$n" -eq 1 ]; then
          pass "iOS: 1 simulator booted: $(grep "(Booted)" <<<"$out" | sed 's/^ *//')"
        elif [ "$n" -eq 0 ]; then
          fail "iOS: no simulator booted (boot one, or run npm run test:setup:ios)"
        else
          fail "iOS: $n simulators booted; the harness targets 'booted', so shut down all but one"
        fi
      else
        fail "iOS: 'xcrun simctl list' failed (sandboxed shell?): $(head -1 <<<"$out")"
      fi
      ;;
    android)
      if out=$(adb devices 2>&1); then
        # Count every entry (device, offline, unauthorized, ...): adb without -s sees all of them.
        # Keep only "serial<TAB>state" lines. adb also prints a header and daemon/version messages.
        entries=$(grep -E $'^[^[:space:]]+\t' <<<"$out")
        n=$(grep -c . <<<"$entries")
        if [ "$n" -eq 1 ] && grep -q "device$" <<<"$entries"; then
          pass "Android: 1 device attached: $(cut -f1 <<<"$entries")"
        elif [ "$n" -eq 1 ]; then
          fail "Android: the only entry is not ready: $(tr '\t' ' ' <<<"$entries")"
        elif [ "$n" -eq 0 ]; then
          fail "Android: no device attached (boot one, or run npm run test:setup:android)"
        else
          fail "Android: $n adb entries ($(cut -f2 <<<"$entries" | sort | uniq -c | xargs)); the harness runs adb without -s, so remove all but one"
        fi
      else
        fail "Android: 'adb devices' failed (sandboxed shell?): $(head -1 <<<"$out")"
      fi
      ;;
  esac
done

echo
echo "== Acquisition server ports =="
for p in "${PLATFORMS[@]}"; do
  case "$p" in
    ios) url="${IOS_SERVER:-http://127.0.0.1:3000}" ;;
    android) url="${ANDROID_SERVER:-http://10.0.2.2:3001}" ;;
  esac
  # Same rule as serverUtil.js: the first ":<digits>" in the URL is the listen port.
  port=$(grep -oE ':[0-9]+' <<<"$url" | head -1 | tr -d ':')
  if [ -z "$port" ]; then
    fail "$p: server URL '$url' has no explicit port; the harness needs one"
    continue
  fi
  # Bind the port the same way serverUtil.js does (listen(port) on all interfaces).
  bind_err=$(node -e 'require("net").createServer().on("error", (e) => { console.log(e.code); process.exit(1); }).listen(+process.argv[1], function () { this.close(); })' "$port" 2>&1)
  if [ -z "$bind_err" ]; then
    pass "$p: port $port is free"
  elif [ "$bind_err" = "EADDRINUSE" ]; then
    fail "$p: port $port is in use (another run in progress?)"
  else
    fail "$p: cannot bind port $port: $(head -1 <<<"$bind_err")"
  fi
done

echo
if [ "$ok" -eq 1 ]; then
  echo "Doctor: safe to drive."
else
  echo "Doctor: one or more checks FAILED - fix these before driving a scenario."
fi
exit $((1 - ok))
