#!/bin/zsh

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
DERIVED_DATA_PATH="/private/tmp/scrollapp-dd-external-no-cursor"
BUILT_APP_PATH="$DERIVED_DATA_PATH/Build/Products/Debug/Scrollapp.app"
APP_PATH="/Applications/Scrollapp.app"
APP_BINARY="$APP_PATH/Contents/MacOS/Scrollapp"
SESSION_ID="scrollapp-verify-$$-$(date +%s)"
RUNTIME_DIR=$(mktemp -d /private/tmp/scrollapp-external-no-cursor.XXXXXX)
SCROLLAPP_STATUS_FILE="$RUNTIME_DIR/scrollapp-status.json"
FIXTURE_STATE_FILE="$RUNTIME_DIR/fixture-state.json"
FIXTURE_LOG="$RUNTIME_DIR/fixture.log"

cleanup() {
  if [[ -n "${SCROLLAPP_PID:-}" ]] && kill -0 "$SCROLLAPP_PID" 2>/dev/null; then
    /usr/bin/swift "$REPO_ROOT/scripts/send_scrollapp_verification_command.swift" "$SESSION_ID" stop 999 >/dev/null 2>&1 || true
    kill "$SCROLLAPP_PID" 2>/dev/null || true
    wait "$SCROLLAPP_PID" 2>/dev/null || true
  fi

  if [[ -n "${FIXTURE_PID:-}" ]] && kill -0 "$FIXTURE_PID" 2>/dev/null; then
    kill "$FIXTURE_PID" 2>/dev/null || true
    wait "$FIXTURE_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT

wait_for_json_field() {
  local file_path="$1"
  local field_name="$2"
  local expected_value="$3"

  /usr/bin/python3 - "$file_path" "$field_name" "$expected_value" <<'PY'
import json
import pathlib
import sys
import time

path = pathlib.Path(sys.argv[1])
field_name = sys.argv[2]
expected = sys.argv[3]
deadline = time.time() + 15

while time.time() < deadline:
    if path.exists():
        try:
            payload = json.loads(path.read_text())
        except Exception:
            time.sleep(0.05)
            continue
        value = payload.get(field_name)
        if str(value).lower() == expected.lower():
            print(json.dumps(payload))
            raise SystemExit(0)
    time.sleep(0.05)

raise SystemExit(1)
PY
}

wait_for_sequence() {
  local file_path="$1"
  local sequence="$2"

  /usr/bin/python3 - "$file_path" "$sequence" <<'PY'
import json
import pathlib
import sys
import time

path = pathlib.Path(sys.argv[1])
sequence = int(sys.argv[2])
deadline = time.time() + 15

while time.time() < deadline:
    if path.exists():
        try:
            payload = json.loads(path.read_text())
        except Exception:
            time.sleep(0.05)
            continue
        if payload.get("sequence") == sequence:
            print(json.dumps(payload))
            raise SystemExit(0)
    time.sleep(0.05)

raise SystemExit(1)
PY
}

json_value() {
  local file_path="$1"
  local field_name="$2"
  /usr/bin/python3 - "$file_path" "$field_name" <<'PY'
import json
import pathlib
import sys

payload = json.loads(pathlib.Path(sys.argv[1]).read_text())
value = payload
for part in sys.argv[2].split('.'):
    value = value[part]
print(value)
PY
}

send_command() {
  local command="$1"
  local sequence="$2"
  shift 2
  /usr/bin/swift "$REPO_ROOT/scripts/send_scrollapp_verification_command.swift" "$SESSION_ID" "$command" "$sequence" "$@"
  wait_for_sequence "$SCROLLAPP_STATUS_FILE" "$sequence" >/dev/null
  local command_ok
  command_ok=$(json_value "$SCROLLAPP_STATUS_FILE" ok)
  if [[ "$command_ok" != "true" && "$command_ok" != "True" ]]; then
    local message
    message=$(json_value "$SCROLLAPP_STATUS_FILE" message)
    echo "Verification command failed: $command ($message)" >&2
    exit 1
  fi
}

cd "$REPO_ROOT"

echo "Building Scrollapp for external no-cursor verification..."
xcodebuild build \
  -project Scrollapp.xcodeproj \
  -scheme Scrollapp \
  -destination 'platform=macOS' \
  -derivedDataPath "$DERIVED_DATA_PATH" >/dev/null

if [[ ! -d "$BUILT_APP_PATH" ]]; then
  echo "Built app bundle not found: $BUILT_APP_PATH" >&2
  exit 1
fi

echo "Refreshing /Applications/Scrollapp.app for realistic permission-aware verification..."
/usr/bin/ditto "$BUILT_APP_PATH" "$APP_PATH"
/usr/bin/xattr -cr "$APP_PATH" || true

if [[ ! -x "$APP_BINARY" ]]; then
  echo "Installed app binary not found: $APP_BINARY" >&2
  exit 1
fi

echo "Launching external scroll fixture under the current cursor..."
/usr/bin/swift "$REPO_ROOT/scripts/external_scroll_fixture.swift" "$FIXTURE_STATE_FILE" >"$FIXTURE_LOG" 2>&1 &
FIXTURE_PID=$!
wait_for_json_field "$FIXTURE_STATE_FILE" ready true >/dev/null

echo "Launching Scrollapp in verification mode through the real app bundle path..."
pkill -f '/Applications/Scrollapp.app/Contents/MacOS/Scrollapp' 2>/dev/null || true
open -n "$APP_PATH" --args \
  --scrollapp-verification-mode \
  --scrollapp-verification-session "$SESSION_ID" \
  --scrollapp-verification-status-file "$SCROLLAPP_STATUS_FILE" >/dev/null 2>&1
wait_for_json_field "$SCROLLAPP_STATUS_FILE" ready true >/dev/null
SCROLLAPP_PID=$(json_value "$SCROLLAPP_STATUS_FILE" pid)

target_x=$(json_value "$FIXTURE_STATE_FILE" targetX)
target_y=$(json_value "$FIXTURE_STATE_FILE" targetY)
physical_target_x=$(json_value "$FIXTURE_STATE_FILE" physicalTargetX)
physical_target_y=$(json_value "$FIXTURE_STATE_FILE" physicalTargetY)
initial_offset=$(json_value "$FIXTURE_STATE_FILE" initialVerticalOffset)

echo "Activating a toggled autoscroll session over the external fixture..."
send_command activate_toggle 1 \
  "physicalX=$physical_target_x" \
  "physicalY=$physical_target_y" \
  "deliveryX=$target_x" \
  "deliveryY=$target_y"

echo "Feeding a virtual upward pointer sample inside the same external window..."
upward_physical_y=$(/usr/bin/python3 - "$physical_target_y" <<'PY'
import sys
print(float(sys.argv[1]) + 140.0)
PY
)
upward_delivery_y=$(/usr/bin/python3 - "$target_y" <<'PY'
import sys
print(float(sys.argv[1]) - 140.0)
PY
)
send_command set_pointer 2 \
  "physicalX=$physical_target_x" \
  "physicalY=$upward_physical_y" \
  "deliveryX=$target_x" \
  "deliveryY=$upward_delivery_y"

echo "Driving the real app-layer scroll path against the external fixture..."
send_command perform_scroll 3 "count=8"
/bin/sleep 0.3

current_offset=$(json_value "$FIXTURE_STATE_FILE" currentVerticalOffset)
delivery_status=$(json_value "$SCROLLAPP_STATUS_FILE" scrollDelivery)
emission_status=$(json_value "$SCROLLAPP_STATUS_FILE" scrollEmission)

if [[ "$current_offset" == "$initial_offset" ]]; then
  echo "External fixture did not scroll." >&2
  echo "Scroll delivery: $delivery_status" >&2
  echo "Scroll emission: $emission_status" >&2
  echo "Fixture log: $FIXTURE_LOG" >&2
  exit 1
fi

echo "External no-cursor verification passed."
echo "Initial vertical offset: $initial_offset"
echo "Current vertical offset: $current_offset"
echo "Scroll delivery: $delivery_status"
echo "Scroll emission: $emission_status"
