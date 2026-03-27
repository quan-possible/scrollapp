---
codex_session_id: 019d30ee-43f9-7ff3-9fa7-a131ad064bb0
codex_session_ids:
  - 019d30ee-43f9-7ff3-9fa7-a131ad064bb0
---

# Speed Ceiling Tune

## Objective
- Raise the autoscroll top-end speed without making near-center motion too jumpy.

## Scope
- `Scrollapp/AutoscrollCore.swift`
- `ScrollappTests/AutoscrollCoreTests.swift`

## Guardrails
- Keep the restored 100 Hz rate-based runtime model.
- Prefer a curve-only adjustment over another architectural change.
- Verify against the installed app path before sign-off.
