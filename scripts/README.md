# Build Scripts

This directory contains the build automation scripts for Scrollapp.

## Scripts

### `open_local_xcode.sh`
Creates a local Xcode project wrapper outside Google Drive / File Provider and opens it in Xcode.

This is useful when the real repository lives under `Library/CloudStorage/...` and Xcode freezes while opening the cloud-backed `.xcodeproj`. The wrapper keeps edits flowing back to the original repository by symlinking the maintained source directories to the real files.

If `xcodegen` is installed, the wrapper regenerates the local `Scrollapp.xcodeproj` from the real `project.yml` so project structure stays aligned with the checked-in spec. If not, it falls back to copying the checked-in `Scrollapp.xcodeproj`.

**Usage:**
```bash
./scripts/open_local_xcode.sh
./scripts/open_local_xcode.sh --check
./scripts/open_local_xcode.sh --no-open
```

**Default local wrapper path:** `~/tmp/scrollapp-xcode/Scrollapp.xcodeproj`

**Safest Drive-backed workflow:**
```bash
SCROLLAPP_XCODE_LOCAL_DIR=/private/tmp/scrollapp-xcode ./scripts/open_local_xcode.sh --check --no-open
```

Then launch Xcode yourself and open the generated local project from `File > Open...`.
If the script's auto-open step fails on your machine, it now prints the same manual fallback path.

**Source-of-truth rule:** app and test source edits made in the local wrapper write straight back to the real repo because the folders are symlinked. If you need to change targets, schemes, or project structure, update `project.yml` in the real repository and rerun the script.

### `open_autoscroll_fixture.sh`
Opens the persistent manual-validation fixture for real browser autoscroll checks.

The fixture is a static HTML page at `manual/autoscroll-fixture.html` with:
- plain body scroll
- nested scroll container
- horizontal overflow strip
- link, button, and text-field targets
- a short recommended manual test matrix

**Usage:**
```bash
./scripts/open_autoscroll_fixture.sh
./scripts/open_autoscroll_fixture.sh --no-open
```

If browser auto-open fails, the script prints both the file path and `file://` URL for manual use.

### `verify_autoscroll_delivery.sh`
Runs the focused macOS test lane that now includes observable autoscroll delivery checks.

This is the strongest practical verification path that stays inside the test host. It checks that:
- a synthetic wheel event still changes a real `NSScrollView` offset
- `AppDelegate.deliverScrollEvent(...)` emits an observable synthetic wheel event on the current delivery path
- the emitted event still moves a real scrollable AppKit view

The script runs `xcodebuild` with `COPYFILE_DISABLE=1` and a `/private/tmp` derived-data path so Google Drive / File Provider extended attributes do not poison the `.xctest` bundle during codesign.
If the repo lives under Google Drive / `Library/CloudStorage`, it automatically routes the build through the local wrapper project from `open_local_xcode.sh`.

**Usage:**
```bash
./scripts/verify_autoscroll_delivery.sh
```

**Current limitation:** this lane proves real observable AppKit scroll output for the emitted event path, but it does not prove cross-app routing in the live menu bar app.

### `verify_launch_smoke.sh`
Runs the simplest reliable launch-smoke check for the built menu bar app.

This script builds the app into a temporary derived-data path, launches the built binary in automated test mode, and verifies that the process stays alive long enough to prove the app can boot cleanly without crashing on startup.
If the repo lives under Google Drive / `Library/CloudStorage`, it automatically routes the build through the local wrapper project from `open_local_xcode.sh`.

**Usage:**
```bash
./scripts/verify_launch_smoke.sh
```

**Current limitation:** this is a direct process-level smoke check, not a full XCTest UI automation lane.

### `verify_autoscroll_external_no_cursor.sh`
Runs the strongest realistic no-cursor verification lane for autoscroll delivery.

This script builds the app, refreshes `/Applications/Scrollapp.app`, launches the built menu bar app in a verification-only command mode, opens a separate temporary AppKit fixture window with a real `NSScrollView`, and waits for the live timer-driven autoscroll session to move that external target without warping or stealing the system cursor.
If the repo lives under Google Drive / `Library/CloudStorage`, it automatically routes the build through the local wrapper project from `open_local_xcode.sh`.

It verifies that:
- the built app can latch a real external scroll target
- the runtime session-tap delivery path emits observable scrolling into another process
- the external fixture's vertical offset increases in the expected direction by a meaningful amount
- the reported `scrollDelivery` and `scrollEmission` diagnostics are refreshed after motion is observed

**Usage:**
```bash
./scripts/verify_autoscroll_external_no_cursor.sh
```

**Notes:**
- This is the strongest practical verification lane in the repo when cursor takeover is not allowed.
- It refreshes the installed app at `/Applications/Scrollapp.app` before launching the verification-only run, so treat it as an integration check against the installed-path bundle rather than a harmless scratch-only test.
- The helper fixture reports both physical pointer coordinates and Quartz delivery coordinates because the runtime uses both during activation and delivery.

### `build_universal.sh`
Builds a universal binary that works on both Intel and Apple Silicon Macs.

**Usage:**
```bash
./scripts/build_universal.sh
```

**Output:** `build/universal/Scrollapp.app`

### `create_dmg_from_app.sh`
Creates a distributable DMG file from a built Scrollapp.app.

**Usage:**
```bash
./scripts/create_dmg_from_app.sh /path/to/Scrollapp.app
```

**Output:** `Scrollapp-v1.0-Xcode.dmg`

## Quick Start

```bash
# Regenerate the project if needed
xcodegen generate --spec project.yml

# Run the quickest reliable verification lanes
./scripts/verify_launch_smoke.sh
./scripts/verify_autoscroll_delivery.sh

# Build universal app
./scripts/build_universal.sh

# Create DMG for distribution
./scripts/create_dmg_from_app.sh build/universal/Scrollapp.app
```

See the main [README.md](../README.md) for detailed build and test instructions.
