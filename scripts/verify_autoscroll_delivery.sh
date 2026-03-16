#!/bin/zsh

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
DERIVED_DATA_PATH="$REPO_ROOT/tmp/dd-autoscroll-delivery-verify"

cd "$REPO_ROOT"

# Avoid copying Drive/File Provider extended attributes into the test bundle.
COPYFILE_DISABLE=1 xcodebuild test \
  -project Scrollapp.xcodeproj \
  -scheme Scrollapp \
  -destination 'platform=macOS' \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  -only-testing:ScrollappTests/AutoscrollCoreTests
