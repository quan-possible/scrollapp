# Build Scripts

This directory contains the build automation scripts for Scrollapp.

## Scripts

### `open_local_xcode.sh`
Creates a local Xcode project wrapper outside Google Drive / File Provider and opens it in Xcode.

This is useful when the real repository lives under `Library/CloudStorage/...` and Xcode freezes while opening the cloud-backed `.xcodeproj`. The wrapper keeps edits flowing back to the original repository by symlinking the source directories to the real files.

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

This is the strongest practical verification path when browser-driving and OS-cursor automation are off-limits. It stays inside the test host and checks that:
- a synthetic wheel event still changes a real `NSScrollView` offset
- `AppDelegate.deliverScrollEvent(...)` emits an observable synthetic wheel event on the current delivery path
- the emitted event still moves a real scrollable AppKit view

The script runs `xcodebuild` with `COPYFILE_DISABLE=1` so Google Drive / File Provider extended attributes do not poison the `.xctest` bundle during codesign.

**Usage:**
```bash
./scripts/verify_autoscroll_delivery.sh
```

**Current limitation:** this lane proves real observable AppKit scroll output for the emitted event path, but it does not prove cross-app routing in the live menu bar app.

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

# Build universal app
./scripts/build_universal.sh

# Create DMG for distribution
./scripts/create_dmg_from_app.sh build/universal/Scrollapp.app
```

See the main [README.md](../README.md) for detailed build and test instructions.
