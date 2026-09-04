#!/usr/bin/env bash
set -euo pipefail

variant="$1"
test_command="$2"

if [ "$variant" = "bare" ]; then
  # These tests are independent of the bare/expo distinction. Bare tests are slightly faster.
  echo "::group::Instrumented tests"
  (cd android && ./gradlew :app:connectedAndroidTest)
  echo "::endgroup::"
fi

echo "::group::E2E tests"
npm run "$test_command"
echo "::endgroup::"
