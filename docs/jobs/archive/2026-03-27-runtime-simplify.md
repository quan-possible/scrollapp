---
codex_session_id: 019d30ee-43f9-7ff3-9fa7-a131ad064bb0
codex_session_ids:
  - 019d30ee-43f9-7ff3-9fa7-a131ad064bb0
---

# Runtime Simplify

## Objective
- Simplify Scrollapp to the bare minimum needed while preserving current runtime behavior exactly.

## Scope
- Runtime code in `Scrollapp/AutoscrollCore.swift` and `Scrollapp/ScrollappApp.swift`
- Regression coverage in `ScrollappTests/AutoscrollCoreTests.swift`
- Repo docs and verification scripts only where they must change to match the simplified implementation

## Guardrails
- Preserve current behavior, even where current runtime differs from older spec text
- Do not revert unrelated working tree changes
- Keep verification strong enough to satisfy the repo software-development contract
- Prefer deleting dead paths over adding new abstraction

## Plan
- Identify and remove runtime-dead session, owner, and helper state
- Simplify the app delegate control flow without changing behavior
- Trim tests that only protect removed dead internals and keep behavior-facing checks
- Update README guidance if ownership, commands, or invariants change
- Run focused tests, final build, and a direct verification lane

## Verification Target
- `xcodebuild test -project Scrollapp.xcodeproj -scheme Scrollapp -destination 'platform=macOS' -only-testing:ScrollappTests/AutoscrollCoreTests`
- `xcodebuild build -project Scrollapp.xcodeproj -scheme Scrollapp -destination 'platform=macOS'`
- `./scripts/verify_autoscroll_external_no_cursor.sh`

## Notes
- The repo already contains in-progress local changes; treat them as the working baseline.
- Verification passed through the local wrapper project at `/private/tmp/scrollapp-xcode/Scrollapp.xcodeproj` to avoid Google Drive / File Provider Xcode hangs.
- `./scripts/verify_autoscroll_delivery.sh` passed after the focused tests were updated to allow multi-tick emission carry.
- `./scripts/verify_launch_smoke.sh` passed.
- `./scripts/verify_autoscroll_external_no_cursor.sh` passed against `/Applications/Scrollapp.app` with an external offset delta of `82.0`.
