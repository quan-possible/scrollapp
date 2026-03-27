#!/bin/zsh

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
DERIVED_DATA_PATH="/private/tmp/scrollapp-dd-autoscroll-delivery-verify"
PROJECT_PATH="$REPO_ROOT/Scrollapp.xcodeproj"

if [[ "$REPO_ROOT" == *"/Library/CloudStorage/"* || "$REPO_ROOT" == *"/GoogleDrive-"* ]]; then
  PROJECT_PATH=$(SCROLLAPP_XCODE_LOCAL_DIR=/private/tmp/scrollapp-xcode "$REPO_ROOT/scripts/open_local_xcode.sh" --check --no-open | tail -n 1)
fi

cd "$REPO_ROOT"

# Avoid copying Drive/File Provider extended attributes into the test bundle.
COPYFILE_DISABLE=1 xcodebuild test \
  -project "$PROJECT_PATH" \
  -scheme Scrollapp \
  -destination 'platform=macOS' \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  -only-testing:ScrollappTests/AutoscrollCoreTests
