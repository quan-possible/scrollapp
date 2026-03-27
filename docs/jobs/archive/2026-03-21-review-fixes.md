## Job

- slug: review-fixes
- started: 2026-03-21
- status: completed

## Codex Session

- codex_session_id: 019d13b4-d180-7cb3-8960-7d47a85cad75
- codex_session_ids:
  - 019d13b4-d180-7cb3-8960-7d47a85cad75

## Goal

- Fix the highest-confidence issues from the full application review while preserving the current simplified product shape.

## Scope

- Runtime/autoscroll correctness fixes
- Verification/test trustworthiness fixes
- Docs/distribution alignment with the simplified app surface

## Decisions

- Keep the product on the simpler current path instead of restoring the older seven-activation-method surface
- Fix behavior and verification first, then align docs and packaging to that simplified reality
- Leave unrelated pre-existing working-tree changes intact unless they are part of the requested fixes

## Workstreams

- Runtime:
  - ancestor actionability should honor ancestor `AXActions`
  - low-speed smoothing should preserve fine near-center control
  - non-activation buttons should stop active autoscroll cleanly
  - launch-at-login state should reflect actual ServiceManagement status
- Verification:
  - event-capture setup failures should fail or explicitly skip instead of silently returning
  - the shared CLI verification path should include a reliable launch-smoke check
  - external verification should refresh diagnostics and assert direction/magnitude more clearly
- Docs/distribution:
  - README and module docs should match the simplified app surface and macOS requirement
  - DMG packaging should preserve the canonical app identifier
  - verification docs should stop implying `/Applications` mutation is required

## Verification Status

- Completed:
  - `xcodebuild build -project Scrollapp.xcodeproj -scheme Scrollapp -destination 'platform=macOS'`
  - `xcodebuild test -project Scrollapp.xcodeproj -scheme Scrollapp -destination 'platform=macOS'`
  - `./scripts/verify_launch_smoke.sh`
  - `./scripts/verify_autoscroll_delivery.sh`
  - `./scripts/verify_autoscroll_external_no_cursor.sh`

- Final status:
  - runtime fixes landed
  - focused core tests pass with 47 tests
  - shared `xcodebuild test -scheme Scrollapp` is stable again
  - launch smoke is covered by the direct `verify_launch_smoke.sh` lane
  - direct external autoscroll delivery was verified through the no-cursor integration lane

## Notes

- Review reference: `docs/jobs/archive/2026-03-21-full-application-review.md`
- The separate `ScrollappUITests` XCTest runner still appears flaky for headless CLI use, so the repo now prefers a direct launch-smoke script over forcing that lane into the shared scheme.
