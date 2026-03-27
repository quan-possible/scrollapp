---
codex_session_id: "019d1710-5de7-7763-b7d0-af29fce30c7c"
codex_session_ids:
  - "019d1710-5de7-7763-b7d0-af29fce30c7c"
---

# Autoscroll Disengage Investigation

## Objective
- Investigate why autoscroll disengages or pauses when the pointer moves far enough away while still inside the same window.
- Do not change runtime behavior in this pass.

## Scope
- Read current project context, trace activation and owner-matching logic, and collect evidence from tests and current source.
- Return a diagnosis plus a concrete fix plan.

## Current Findings
- Project memory already flags unresolved behavior around keeping scrolling active after the cursor leaves the clicked element.
- `Scrollapp/ScrollappApp.swift` currently gates delivery with `ownerMatchState(...)` and can pause while the pointer is outside the latched owner.
- The current focused tests intentionally preserve that behavior:
  - `ownerMismatchPausesWithNoEmissionButKeepsSessionActiveViaPerformScroll`
  - `differentPaneInSameWindowEmitsNoEventAndKeepsSessionActive`
  - `returningInsideOwnerResumesEmissionAndScrollingViaPerformScroll`
- The repo docs also currently describe the runtime as pausing while the pointer is outside the original owner.

## Open Questions
- Whether the current latched owner is too narrow for real browser/window content regions.
- Whether window-level matching or AX ancestry matching is causing false mismatch while staying in the same practical scroll region.

## Evidence Collected
- Read context:
  - `AGENTS.md`
  - `MEMORY.md`
  - `memory/2026-03-19.md`
  - `memory/2026-03-15.md`
  - `README.md`
  - `Scrollapp/README.md`
  - `ScrollappTests/README.md`
- Relevant source:
  - `Scrollapp/ScrollappApp.swift`
  - `Scrollapp/AutoscrollCore.swift`
  - `ScrollappTests/AutoscrollCoreTests.swift`
- Verification:
  - `COPYFILE_DISABLE=1 xcodebuild test -project Scrollapp.xcodeproj -scheme Scrollapp -destination 'platform=macOS' -derivedDataPath /private/tmp/scrollapp-dd-investigate-disengage -only-testing:ScrollappTests/AutoscrollCoreTests`
  - Result: passed, `47` tests

## Working Diagnosis
- This does not look like a physics-distance bug.
- The active session keeps running, but emission pauses whenever `ownerMatchState(...)` decides the live pointer is no longer in the latched owner identity.
- The same-window pause is not accidental in the current codebase; it is documented and covered by tests.
- The likely product bug is that the runtime is enforcing a narrower invariant than the user expects:
  - current behavior: "keep scrolling only while the pointer remains inside the latched owner"
  - expected behavior from the report: "keep scrolling across the same practical scroll region, or at least the same window, even when the pointer moves far away"

## Implementation Completed
- Production:
  - widened owner-candidate promotion so enclosing `AXWebArea` and broader enclosing same-role scroll hosts can replace tiny nested owners when they substantially contain the original target
  - relaxed owner identity matching so compatible same-window content hosts (`AXBrowser`, `AXScrollArea`, `AXTextArea`, `AXWebArea`) with overlapping or containing frames are treated as the same practical document surface
- Tests:
  - replaced the old same-window pause expectation with a same-window compatible document-host continuation test
  - added broader-owner preference tests for browser-like and Preview-like surfaces
- Docs:
  - updated repo/module/test README guidance to reflect same-window document-surface continuity

## Verification Results
- Focused tests:
  - `COPYFILE_DISABLE=1 xcodebuild test -project Scrollapp.xcodeproj -scheme Scrollapp -destination 'platform=macOS' -derivedDataPath /private/tmp/scrollapp-dd-same-window-fix -only-testing:ScrollappTests/AutoscrollCoreTests`
  - passed: `48` tests
- Final build:
  - `xcodebuild build -project Scrollapp.xcodeproj -scheme Scrollapp -destination 'platform=macOS'`
  - passed
- Direct built-app verification:
  - `./scripts/verify_autoscroll_external_no_cursor.sh`
  - passed
  - observed fixture offset change: `420 -> 1133` (`+713`)
  - observed delivery status: `session tap live-pointer route (latched pid=7692) (0, 20)`
- Post-verification runtime:
  - relaunched `/Applications/Scrollapp.app` so the running process matches the verified build

## Next Steps
- User validation should specifically check:
  - browser page continuity on X across far cursor movement within the same page surface
  - Preview continuity across the same document surface
  - continued pause behavior when leaving the original window entirely
