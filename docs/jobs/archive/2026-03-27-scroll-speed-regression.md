---
codex_session_id: 019d30ee-43f9-7ff3-9fa7-a131ad064bb0
codex_session_ids:
  - 019d30ee-43f9-7ff3-9fa7-a131ad064bb0
---

# Scroll Speed Regression

## Objective
- Restore the pre-simplification autoscroll speed after the user reported that the live app now scrolls very slowly.

## Scope
- `Scrollapp/AutoscrollCore.swift`
- `Scrollapp/ScrollappApp.swift`
- `ScrollappTests/AutoscrollCoreTests.swift`
- relevant docs only if runtime invariants change

## Guardrails
- Keep the simplification gains where they do not affect user-visible behavior
- Prefer the minimum behavior-preserving fix over another broad refactor
- Verify in the installed app path before sign-off

## Plan
- Compare the current smoothed/emitted scroll path against the pre-simplification runtime
- Restore whichever timing or per-tick emission behavior changed the effective speed
- Re-run focused tests, build, direct external verification, and relaunch the app

## Result
- Restored the pre-simplification per-tick autoscroll semantics.
- Reverted the timer interval to `1.0 / 60.0`.
- Reverted smoothing to the legacy fixed blends.
- Removed time-normalized emission and per-second carry, which had reduced live scroll output dramatically.

## Verification
- `./scripts/verify_autoscroll_delivery.sh` passed
- `./scripts/verify_launch_smoke.sh` passed
- `./scripts/verify_autoscroll_external_no_cursor.sh` passed with offset delta `2702.0`
- Relaunched `/Applications/Scrollapp.app`; current pid is `40633`
