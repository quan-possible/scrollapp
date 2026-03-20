# Realistic No-Cursor Verification

Started: 2026-03-19
Status: completed

## Objective
- Add the strongest practical autoscroll verification path that exercises real runtime behavior without taking control of the system cursor.

## Scope
- Inspect current focused tests and helper scripts.
- Improve the no-cursor verification lane toward the real app/runtime path.
- Update README guidance if the verification contract changes.

## Constraints
- Do not move or warp the OS cursor.
- Leave unrelated working tree changes untouched.
- Prefer built-app or cross-process behavior checks over purely internal logic when feasible.

## Progress
- Investigation context from the prior autoscroll-up freeze audit is already loaded.
- Current candidate baseline is the AppKit observable-output lane in `ScrollappTests/AutoscrollCoreTests.swift` plus `scripts/verify_autoscroll_delivery.sh`.
- Added a verification-only command mode to `Scrollapp/ScrollappApp.swift` so the built app can be driven without taking over the real system cursor.
- Added `scripts/external_scroll_fixture.swift` to launch a temporary external AppKit fixture with a real `NSScrollView`.
- Added `scripts/send_scrollapp_verification_command.swift` and `scripts/verify_autoscroll_external_no_cursor.sh` to drive the built app against that external fixture.
- Hardened `scripts/verify_autoscroll_delivery.sh` to use `/private/tmp` derived data so Google Drive extended attributes do not poison the test bundle.

## Root Cause
- The first external-fixture attempt reported AppKit-flavored screen coordinates from `window.convertPoint(toScreen:)`.
- The runtime latches owners and windows using Quartz/AX coordinates, so activation looked plausible but hit-tested the wrong process.
- The verification path also needed the same split the production path uses:
  - physical pointer coordinates for velocity math
  - Quartz delivery coordinates for AX hit-testing and owner/window latching

## Final Changes
- `Scrollapp/ScrollappApp.swift`
  - verification mode now activates using separate physical and delivery coordinates so it matches the real runtime path instead of collapsing both into one point
- `scripts/external_scroll_fixture.swift`
  - now reports Quartz-global target coordinates and window frame data
  - now also reports the physical pointer coordinates needed for realistic velocity input
- `scripts/verify_autoscroll_external_no_cursor.sh`
  - now drives activation and pointer motion with both coordinate sets
  - fails fast if any verification command is rejected
  - no longer references the unused Scrollapp log path
- README updates
  - documented the new strongest no-cursor runtime lane and clarified the role of the in-process AppKit harness

## Verification
- `swiftc -typecheck scripts/external_scroll_fixture.swift`
- `xcodebuild build -project Scrollapp.xcodeproj -scheme Scrollapp -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO`
- `./scripts/verify_autoscroll_external_no_cursor.sh`
  - passed twice after the coordinate split fix
  - latest pass:
    - initial vertical offset: `420`
    - current vertical offset: `1701`
    - delivery status: `Scroll Delivery: armed session tap live-pointer delivery (pid=52896, window=2449)`
- `./scripts/verify_autoscroll_delivery.sh`
  - passed with 39 focused tests

## Outcome
- The repo now has two useful no-cursor lanes:
  - an in-process AppKit observable-output lane for fast focused regression checks
  - a stronger built-app cross-process lane that verifies real external scrolling without taking the cursor from the system
