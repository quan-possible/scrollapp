## Job

- slug: autoscroll-cancel-debug
- started: 2026-03-21
- status: completed

## Codex Session

- codex_session_id: 019d12a3-33e8-7180-b124-d151574e7160
- codex_session_ids:
  - 019d12a3-33e8-7180-b124-d151574e7160

## Goal

- Find why autoscroll is getting cancelled altogether shortly after activation in real use.

## Current Context

- Click-to-toggle activation was restored and external no-cursor verification passed.
- The remaining user-reported issue is a real runtime cancellation, not just a temporary pause.
- The strongest likely hard-stop path is `handleScrollWheel`, which currently stops autoscroll on any non-synthetic wheel event.

## Next Steps

- If live browser usage still cancels, inspect browser-specific event feedback rather than the generic wheel-stop path.

## Result

- Removed the unconditional `handleScrollWheel` stop path for non-synthetic wheel events.
- Added regression coverage proving external wheel input no longer cancels an active session.
- Verification completed successfully:
  - focused tests passed: `44` tests
  - `xcodebuild build -project Scrollapp.xcodeproj -scheme Scrollapp -destination 'platform=macOS'` passed
  - `./scripts/verify_autoscroll_external_no_cursor.sh` passed with fixture offset change `420 -> 673`
  - launched the fresh Debug app bundle after verification
