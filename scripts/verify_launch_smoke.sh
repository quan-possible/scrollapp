#!/bin/zsh

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
DERIVED_DATA_PATH="/private/tmp/scrollapp-dd-launch-smoke"
LOG_PATH="/private/tmp/scrollapp-launch-smoke.log"
APP_PID=""
PROJECT_PATH="$REPO_ROOT/Scrollapp.xcodeproj"

if [[ "$REPO_ROOT" == *"/Library/CloudStorage/"* || "$REPO_ROOT" == *"/GoogleDrive-"* ]]; then
  PROJECT_PATH=$(SCROLLAPP_XCODE_LOCAL_DIR=/private/tmp/scrollapp-xcode "$REPO_ROOT/scripts/open_local_xcode.sh" --check --no-open | tail -n 1)
fi

cleanup() {
  if [[ -n "${APP_PID}" ]] && kill -0 "${APP_PID}" 2>/dev/null; then
    kill "${APP_PID}" 2>/dev/null || true
    wait "${APP_PID}" 2>/dev/null || true
  fi
}

trap cleanup EXIT INT TERM

cd "$REPO_ROOT"

COPYFILE_DISABLE=1 xcodebuild build \
  -project "$PROJECT_PATH" \
  -scheme Scrollapp \
  -destination 'platform=macOS' \
  -derivedDataPath "$DERIVED_DATA_PATH"

APP_BINARY="$DERIVED_DATA_PATH/Build/Products/Debug/Scrollapp.app/Contents/MacOS/Scrollapp"
if [[ ! -x "$APP_BINARY" ]]; then
  echo "Launch smoke failed: built app binary not found at $APP_BINARY" >&2
  exit 1
fi

SCROLLAPP_TEST_MODE=ui-testing \
"$APP_BINARY" --scrollapp-test-mode >"$LOG_PATH" 2>&1 &
APP_PID=$!

sleep 0.5
if ! kill -0 "$APP_PID" 2>/dev/null; then
  echo "Launch smoke failed: Scrollapp exited immediately." >&2
  [[ -s "$LOG_PATH" ]] && cat "$LOG_PATH" >&2
  exit 1
fi

end_time=$((SECONDS + 3))
while (( SECONDS < end_time )); do
  if ! kill -0 "$APP_PID" 2>/dev/null; then
    echo "Launch smoke failed: Scrollapp did not stay alive in automated test mode." >&2
    [[ -s "$LOG_PATH" ]] && cat "$LOG_PATH" >&2
    exit 1
  fi
  sleep 0.1
done

echo "Launch smoke passed: Scrollapp stayed alive in automated test mode (pid $APP_PID)."
