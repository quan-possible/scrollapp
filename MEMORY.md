# Project Memory

Last updated: 2026-03-14

## Current Objective
- Restore reliable Windows-style middle-click autoscroll on macOS with the smallest generalizable implementation.
- Keep runtime behavior simple enough that activation and delivery can be debugged from live evidence instead of stacked heuristics.

## Current State
- `Scrollapp/AutoscrollCore.swift` is the main pure-logic layer for autoscroll physics and target classification.
- `Scrollapp/ScrollappApp.swift` owns the event tap, AX hit-testing, autoscroll session state, and synthetic wheel delivery.
- The simplification pass removed dead UI/test surface:
  - `Scrollapp/ContentView.swift`
  - `ScrollappTests/ScrollappTests.swift`
  - `ScrollappUITests/ScrollappUITestsLaunchTests.swift`
- The current runtime is back on the smallest delivery path:
  - synthetic wheel events post through `.cgSessionEventTap`
  - no forced anchored event-location override
  - diagnostics report live-pointer delivery again
- Focused verification is green:
  - `xcodebuild test -project Scrollapp.xcodeproj -scheme Scrollapp -destination 'platform=macOS' -only-testing:ScrollappTests/AutoscrollCoreTests`
    - `19` tests passed
  - `xcodebuild build -project Scrollapp.xcodeproj -scheme Scrollapp -destination 'platform=macOS'`
    - passed
  - refreshed `/Applications/Scrollapp.app` from the verified build on 2026-03-14 03:29 MDT

## Known Gaps
- Runtime behavior is still unstable in real browser usage even though focused tests pass.
- A clean solution for "keep scrolling after the cursor leaves the clicked element" is still unresolved.
- Prior attempts to force target-latched delivery caused two distinct regressions:
  - `postToPid(...)` led to visible activation without real scrolling
  - anchored event-location override reintroduced cursor-pull behavior
- Browser automation is not reliable proof for the global event-tap path, so live runtime debugging still needs app-side instrumentation or manual validation.

## Current Guidance
- Prefer structural classification rules over metadata-heavy heuristics.
- Do not reintroduce cursor anchoring, pointer snapping, or broad URL-based link inference without fresh runtime evidence.
- If the next pass continues to fail in live usage, instrument the delivery/classification path rather than adding more heuristics.

## Canonical Temp Context
- Ongoing snapshot: `tmp/autoscroll-simplify-ongoing.md`

## Important Constraints
- Do not revert unrelated working tree changes.
- Use `apply_patch` for manual file edits.
- Keep temporary artifacts under `tmp/`.
