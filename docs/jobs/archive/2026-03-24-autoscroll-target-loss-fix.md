---
codex_session_id: "019d21f6-e1bf-7810-bfc4-647d99dd7136"
codex_session_ids:
  - "019d21f6-e1bf-7810-bfc4-647d99dd7136"
---

# Autoscroll Target Loss Fix

## Objective
- Stop autoscroll from hard-cancelling when the latched target PID check fails even though the practical window or document surface is still valid.

## Scope
- Update runtime lifetime logic in `Scrollapp/ScrollappApp.swift`.
- Update focused regression coverage in `ScrollappTests/AutoscrollCoreTests.swift`.
- Update repo/module README guidance if the session-lifetime invariant changes.

## Current Findings
- User diagnostics show `Stop Reason: stopped by target loss pid=...`.
- Current runtime stops in `deliverScrollEvent(...)` before owner/window matching if `NSRunningApplication(processIdentifier:)` returns `nil`.
- The app already has stronger user-facing continuity anchors via `targetWindowID` and `latchedScrollOwner`.

## Plan
- Remove or demote fatal PID-loss stopping so session lifetime follows explicit clicks and window/owner continuity instead.
- Add regression coverage proving target PID lookup failure no longer kills an otherwise valid session.
- Run focused tests, final build, and direct autoscroll verification.

## Verification Status
- Focused tests passed:
  - `COPYFILE_DISABLE=1 xcodebuild test -project Scrollapp.xcodeproj -scheme Scrollapp -destination 'platform=macOS' -derivedDataPath /private/tmp/scrollapp-dd-target-loss-fix -only-testing:ScrollappTests/AutoscrollCoreTests`
  - `48` tests passed
- Final build passed:
  - `xcodebuild build -project Scrollapp.xcodeproj -scheme Scrollapp -destination 'platform=macOS'`
- Direct verification passed:
  - `./scripts/verify_autoscroll_external_no_cursor.sh`
  - refreshed `/Applications/Scrollapp.app`
  - launched the real app bundle in verification mode
  - observed external fixture vertical offset change `420 -> 874` (`+454`)
  - final diagnostic snapshot still reported `Scroll Delivery: paused outside latched owner`, but the real timer-driven external fixture scroll completed successfully before cleanup
- Post-verification runtime:
  - relaunched `/Applications/Scrollapp.app` so the running process matches the verified build

## Notes
- Keeping this work sequential because the runtime, tests, docs, and verification are all coupled to the same session-lifetime decision path.

## Result
- Removed the fatal target-PID stop gate from `deliverScrollEvent(...)`.
- Added regression coverage proving an unavailable target PID does not cancel an otherwise still-matched session.
- Updated module and test README guidance to document window or owner continuity as the lifetime rule instead of PID lookup success.
