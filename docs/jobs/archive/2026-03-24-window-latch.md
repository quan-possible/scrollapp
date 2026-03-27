---
codex_session_id: "019d22c0-db1f-7671-a59d-ac3cbd0144fa"
codex_session_ids:
  - "019d22c0-db1f-7671-a59d-ac3cbd0144fa"
---

# Window Latch

## Objective
- Relax autoscroll continuity from element-level owner latching to window-level latching so same-window panel or element changes do not pause scrolling.

## Scope
- Update the runtime continuity gate in `Scrollapp/ScrollappApp.swift`.
- Update focused runtime regression coverage in `ScrollappTests/AutoscrollCoreTests.swift`.
- Update README guidance if the latch invariant changes.

## Plan
- Remove the latched-owner pause requirement while keeping the latched-window mismatch pause.
- Prove same-window cross-element scrolling still emits, and cross-window movement still pauses.
- Run focused tests, a full app build, and a direct built-app verification path.

## Verification Status
- Focused tests passed:
  - `COPYFILE_DISABLE=1 xcodebuild test -project Scrollapp.xcodeproj -scheme Scrollapp -destination 'platform=macOS' -derivedDataPath /private/tmp/scrollapp-dd-window-latch -only-testing:ScrollappTests/AutoscrollCoreTests`
  - `48` tests passed
- Final build passed:
  - `xcodebuild build -project Scrollapp.xcodeproj -scheme Scrollapp -destination 'platform=macOS' -derivedDataPath /private/tmp/scrollapp-dd-window-latch-build`
- Direct verification passed:
  - `./scripts/verify_autoscroll_external_no_cursor.sh`
  - refreshed `/Applications/Scrollapp.app`
  - observed external fixture vertical offset change `420 -> 711` (`+291`)
  - delivery status reported `session tap live-pointer route (latched pid=79771) (0, 21)`
  - emission status reported `mode=toggled vx=0.0 vy=2094.3`
- Post-verification runtime:
  - relaunched `/Applications/Scrollapp.app` so the running process matches the verified build

## Notes
- Keeping this sequential because the runtime gate, diagnostics, tests, and direct verification all depend on one shared continuity rule.

## Result
- Same-window continuity now stays active even when the pointer crosses into a different element or panel inside the latched window.
- Cross-window movement still pauses emission instead of retargeting.
- README and test guidance now describe the latch boundary as window-level continuity.
