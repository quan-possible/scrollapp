## Job

- slug: full-application-review
- started: 2026-03-21
- status: completed

## Codex Session

- codex_session_id: 019d13b4-d180-7cb3-8960-7d47a85cad75
- codex_session_ids:
  - 019d13b4-d180-7cb3-8960-7d47a85cad75

## Goal

- Perform a full application review focused on bugs, regressions, risky complexity, and gaps in verification, using parallel sub-agent audits.

## Scope

- Review production app logic in `Scrollapp/`
- Review tests in `ScrollappTests/` and `ScrollappUITests/`
- Review verification and build scripts in `scripts/`
- Review recent autoscroll changes in the dirty working tree without modifying them

## Constraints

- Leave unrelated working-tree changes untouched
- Favor simple, effective behavior over layered heuristics
- Treat the archived `2026-03-21-autoscroll-cancel-debug` record as a seed for adjacent bug hunting, not as the whole review scope

## Plan

- Read current docs, memory, and archived bug context
- Delegate parallel audits across runtime logic, tests, and scripts/docs
- Reproduce or validate suspicious paths locally where feasible
- Consolidate findings with severity, file references, and concrete risk explanations

## Verification Status

- Review-only task; no code changes made in this pass
- Focused tests passed:
  - `xcodebuild test -project Scrollapp.xcodeproj -scheme Scrollapp -destination 'platform=macOS' -only-testing:ScrollappTests/AutoscrollCoreTests`
  - `44` tests passed
- Targeted validation completed:
  - confirmed the smoothing floor suppresses low-speed scrolling ranges numerically
  - confirmed the project target is macOS `14.0` even though the README still claims macOS `11.0`
  - confirmed the runtime no longer exposes configurable activation methods despite the README claiming seven methods plus trackpad support
  - confirmed `xcodebuild test -project Scrollapp.xcodeproj -scheme Scrollapp -destination 'platform=macOS' -only-testing:ScrollappUITests/ScrollappUITests` fails because the primary scheme does not include the UI-test target
  - ran `./scripts/verify_autoscroll_external_no_cursor.sh` twice and observed both runs succeed while printing the pre-scroll `idle (inside dead zone)` diagnostics from the status file

## Findings

- P1: clickable ancestors that are only actionable through generic AX actions can still be misclassified as plain content because runtime ancestry scanning ignores ancestor `AXActions`
- P1: the new smoothing floor zeroes low-speed motion, undermining the advertised fine-control region near the anchor
- P1: multiple delivery-path tests can pass vacuously when the event tap cannot be created because they `return` instead of failing or explicitly skipping
- P2: non-activation mouse buttons do not stop an active session even though the README says any other mouse button should exit
- P2: the primary shared `Scrollapp` scheme excludes the UI-test target, so the default project test command never exercises `ScrollappUITests`
- P2: the external no-cursor verification script reports stale app diagnostics because it never requests a post-scroll snapshot before reading `scrollDelivery` and `scrollEmission`
- P2: the external no-cursor verification script only asserts that the offset changed, so wrong-direction or too-small movement can still pass
- P2: product docs advertise activation methods and trackpad support that are not implemented in the current runtime
- P3: repo docs still advertise macOS `11.0` support while the checked-in project target is macOS `14.0`

## Result

- Completed a parallel full-application review focused on autoscroll-adjacent bugs, verification trust, and product-surface drift
- Left the existing dirty working tree untouched
- Archived this job record on completion

## Notes

- Existing dirty files were present before this review:
  - `README.md`
  - `Scrollapp/AutoscrollCore.swift`
  - `Scrollapp/README.md`
  - `Scrollapp/ScrollappApp.swift`
  - `ScrollappTests/AutoscrollCoreTests.swift`
  - `scripts/README.md`
  - `scripts/verify_autoscroll_external_no_cursor.sh`
