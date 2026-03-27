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
PROJECT_PATH="$REPO_ROOT/Scrollapp.xcodeproj"

if [[ "$REPO_ROOT" == *"/Library/CloudStorage/"* || "$REPO_ROOT" == *"/GoogleDrive-"* ]]; then
  PROJECT_PATH=$(SCROLLAPP_XCODE_LOCAL_DIR=/private/tmp/scrollapp-xcode "$REPO_ROOT/scripts/open_local_xcode.sh" --check --no-open | tail -n 1)
fi

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

wait_for_meaningful_offset_delta() {
  local file_path="$1"
  local field_name="$2"
  local initial_value="$3"
  local minimum_delta="$4"

  /usr/bin/python3 - "$file_path" "$field_name" "$initial_value" "$minimum_delta" <<'PY'
import json
import pathlib
import sys
import time

path = pathlib.Path(sys.argv[1])
field_name = sys.argv[2]
initial_value = float(sys.argv[3])
minimum_delta = float(sys.argv[4])
deadline = time.time() + 15

while time.time() < deadline:
    if path.exists():
        try:
            payload = json.loads(path.read_text())
        except Exception:
            time.sleep(0.05)
            continue

        current_value = payload.get(field_name)
        if current_value is None:
            time.sleep(0.05)
            continue
        delta = abs(float(current_value) - initial_value)
        if delta >= minimum_delta:
            print(current_value)
            raise SystemExit(0)
    time.sleep(0.05)

raise SystemExit(1)
PY
}

offset_delta() {
  local initial_value="$1"
  local current_value="$2"

  /usr/bin/python3 - "$initial_value" "$current_value" <<'PY'
import sys

initial_value = float(sys.argv[1])
current_value = float(sys.argv[2])
print(current_value - initial_value)
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
  -project "$PROJECT_PATH" \
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

echo "Waiting for the real timer-driven autoscroll path against the external fixture..."
wait_for_meaningful_offset_delta "$FIXTURE_STATE_FILE" currentVerticalOffset "$initial_offset" "40" >/dev/null

send_command snapshot 3

current_offset=$(json_value "$FIXTURE_STATE_FILE" currentVerticalOffset)
offset_change=$(offset_delta "$initial_offset" "$current_offset")
delivery_status=$(json_value "$SCROLLAPP_STATUS_FILE" scrollDelivery)
emission_status=$(json_value "$SCROLLAPP_STATUS_FILE" scrollEmission)

if [[ "$current_offset" == "$initial_offset" ]]; then
  echo "External fixture did not scroll." >&2
  echo "Scroll delivery: $delivery_status" >&2
  echo "Scroll emission: $emission_status" >&2
  echo "Fixture log: $FIXTURE_LOG" >&2
  exit 1
fi

if ! /usr/bin/python3 - "$offset_change" <<'PY'
import sys

offset_change = abs(float(sys.argv[1]))
raise SystemExit(0 if offset_change >= 40 else 1)
PY
then
  echo "External fixture moved too little to trust the verification result." >&2
  echo "Initial vertical offset: $initial_offset" >&2
  echo "Current vertical offset: $current_offset" >&2
  echo "Offset delta: $offset_change" >&2
  echo "Scroll delivery: $delivery_status" >&2
  echo "Scroll emission: $emission_status" >&2
  echo "Fixture log: $FIXTURE_LOG" >&2
  exit 1
fi

echo "External no-cursor verification passed."
echo "Initial vertical offset: $initial_offset"
echo "Current vertical offset: $current_offset"
echo "Offset delta: $offset_change"
echo "Scroll delivery: $delivery_status"
echo "Scroll emission: $emission_status"
