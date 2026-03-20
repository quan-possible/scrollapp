# Scrollapp Tests

This folder holds focused regression tests for the pure autoscroll logic.

## Read This First

- `AutoscrollCoreTests.swift`: behavior tests for `AutoscrollCore.swift`, especially target classification and fallback-axis decisions.
  - It also carries the lightweight AppKit delivery checks that verify observable scroll offset changes without moving the OS cursor.

## Key Rules

- Prefer small, behavior-based tests with Swift Testing.
- Keep global input-hook and AppKit integration checks out of this folder unless the behavior can be isolated safely.
- Add or update tests here whenever `AutoscrollCore.swift` changes behavior, thresholds, or target-resolution rules.
- When runtime delivery regresses, prefer observable-output harnesses such as the `NSScrollView` checks here over diagnostics-only assertions.
- For owner-latching behavior, cover both pause/no-emission on mismatch and resume when the pointer returns to the latched owner.
- Prefer app-layer no-cursor checks that prime `AppDelegate` state and drive `performScroll()` before falling back to lower-level `deliverScrollEvent(...)` coverage.
- Treat these tests as supporting evidence for core logic, not as the only final proof for runtime behavior changes.
- The AppKit harness here is the strongest no-cursor lane inside the test host.
  It verifies emitted scroll events against a real `NSScrollView`, but it does not fully model cross-app OS routing in the installed menu bar app.
- For the strongest realistic no-cursor runtime check, pair these tests with `../scripts/verify_autoscroll_external_no_cursor.sh`.

## Verification

- `xcodebuild test -project Scrollapp.xcodeproj -scheme Scrollapp -destination 'platform=macOS' -only-testing:ScrollappTests/AutoscrollCoreTests`
- `./scripts/verify_autoscroll_delivery.sh`
- `./scripts/verify_autoscroll_external_no_cursor.sh`
- Pair the focused test run with a successful app build and at least one direct verification of the built app's behavior when runtime interaction is the thing being changed.
