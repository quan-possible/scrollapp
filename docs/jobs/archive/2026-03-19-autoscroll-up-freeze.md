# Autoscroll Up Freeze Investigation

Started: 2026-03-19
Status: completed

## Objective
- Investigate the report that autoscroll often freezes when scrolling upward beyond a certain cursor distance.

## Scope
- Inspect the upward autoscroll physics path in `Scrollapp/AutoscrollCore.swift`.
- Inspect the runtime delivery path in `Scrollapp/ScrollappApp.swift`.
- Review existing focused tests and fixture-based verification lanes for gaps around high-magnitude upward motion.

## Constraints
- Leave unrelated working tree changes untouched.
- Prefer evidence from current code, focused tests, and direct runtime/build verification where feasible.
- This pass is investigation-first; do not assume a fix until the failure mode is clear.

## Progress
- Loaded required repo context: `AGENTS.md`, `MEMORY.md`, `memory/2026-03-19.md`, `memory/2026-03-15.md`, and the README chain.
- Confirmed there was no matching active ongoing snapshot before starting this investigation.
- Read `Scrollapp/AutoscrollCore.swift`, `Scrollapp/ScrollappApp.swift`, and `ScrollappTests/AutoscrollCoreTests.swift`.
- Ran:
  - `xcodebuild build -project Scrollapp.xcodeproj -scheme Scrollapp -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO`
  - `./scripts/verify_autoscroll_delivery.sh` (environment failure under the Drive-backed derived-data path during test-bundle codesign)
  - `COPYFILE_DISABLE=1 xcodebuild test -project Scrollapp.xcodeproj -scheme Scrollapp -destination 'platform=macOS' -derivedDataPath /private/tmp/scrollapp-dd-investigate-up-freeze -only-testing:ScrollappTests/AutoscrollCoreTests`
  - a local numeric sweep of the vertical physics curve for positive and negative pointer offsets

## Findings
- Pure physics does not show an upward-only freeze:
  - vertical velocity is computed from `abs(delta)` and only the sign flips afterward
  - large negative/upward offsets saturate to the same max magnitude as large positive/downward offsets
  - no clamp, threshold, or rounding branch sends large upward offsets back to zero
- Runtime delivery can pause while velocity stays nonzero:
  - `performScroll()` computes velocity first, stores it back into `activeSession`, and only then checks whether delivery is still allowed for the live pointer
  - if the pointer leaves the latched window or latched owner frame, emission returns early without posting a scroll event
  - existing tests already prove this exact “paused but still active” behavior
- Verification outcome:
  - app build succeeded
  - the focused autoscroll test lane passed with `39` tests once run from `/private/tmp` instead of the Drive-backed path
  - the first verification script failure was environmental rather than behavioral:
    - `resource fork, Finder information, or similar detritus not allowed` while codesigning the test bundle under the Drive-backed derived-data location

## Evidence
- Core symmetry:
  - `Scrollapp/AutoscrollCore.swift:88-113`
  - `Scrollapp/AutoscrollCore.swift:390-405`
- Runtime pause path:
  - `Scrollapp/ScrollappApp.swift:753-829`
  - `Scrollapp/ScrollappApp.swift:1363-1393`
  - `Scrollapp/ScrollappApp.swift:1493-1523`
- Matching tests:
  - `ScrollappTests/AutoscrollCoreTests.swift:573-597`
  - `ScrollappTests/AutoscrollCoreTests.swift:645-683`

## Working Conclusion
- The reported “freeze beyond a certain upward distance” is much more likely to be the owner/window latching guard pausing delivery after the live pointer crosses the latched owner boundary than a bug in the pure autoscroll physics.
- Upward motion can feel disproportionately affected because the top edge of the latched owner is often closer than the bottom edge in real browser layouts due to toolbars, tab strips, and smaller nested scroll owners.

## Outcome
- Investigation complete with no production code changes in this pass.
