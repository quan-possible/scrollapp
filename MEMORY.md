# Project Memory

Last updated: 2026-03-27

## Current Objective
- Keep the simplified autoscroll runtime while preserving the pre-simplification feel in real use.
- Require future simplification passes to prove behavior parity before sign-off.

## Current State
- `Scrollapp/AutoscrollCore.swift` is the main pure-logic layer for autoscroll physics and target classification.
- `Scrollapp/ScrollappApp.swift` owns the event tap, AX hit-testing, autoscroll session state, and synthetic wheel delivery.
- The repo now uses folder-level `README.md` files as first-pass code maps:
  - root `README.md`
  - `Scrollapp/README.md`
  - `ScrollappTests/README.md`
  - `scripts/README.md`
- The project is now enrolled in the `codex-personal` and `codex-manager` portfolios under the registry id `scrollapp`, so manager-level status and follow-up work should load this repo directly instead of treating it as out-of-band app work.
- The March 27 simplification pass removed dead runtime and test/UI surface while keeping the app on the session-tap delivery path.
- The runtime feel regression from that pass was repaired:
  - the live app is back on the rate-based `1.0 / 100.0` emission model
  - the curve ceiling was raised to `maxSpeedPerSecond = 9000.0`
  - the top-end now matches the user's expected feel much more closely than the simplified regression build
- Direct verification lanes now include:
  - `./scripts/verify_autoscroll_delivery.sh`
  - `./scripts/verify_launch_smoke.sh`
  - `./scripts/verify_autoscroll_external_no_cursor.sh`
- `ScrollappUITests` and its Xcode scheme were removed; launch smoke now lives in `scripts/verify_launch_smoke.sh`.
- The `simplify` skill was updated outside this repo to require:
  - pre-edit behavior baselines
  - rollback-safe checkpoints
  - explicit old-vs-new parity gating before simplification sign-off

## Known Gaps
- The app feel is now user-guided rather than numerically identical to a frozen historical baseline, so future tuning work should capture explicit before/after evidence first.
- Browser automation is still not complete proof for the global event-tap path; direct app-path verification remains necessary for behavior-sensitive changes.
- The global `simplify` skill changes live under `~/.codex` and were not part of the Scrollapp Git push.

## Current Guidance
- Prefer structural classification rules over metadata-heavy heuristics.
- Do not reintroduce cursor anchoring, pointer snapping, or broad URL-based link inference without fresh runtime evidence.
- If the next pass drifts in live usage, instrument the delivery/classification path rather than adding more heuristics.
- Before future simplification work, capture the old behavior on the same user-visible surface that will be used for sign-off.
- For live autoscroll tuning, verify against the installed app path and keep the external no-cursor script in the loop.
- Follow the repo `software-development` contract for substantive coding work:
  - read the nearest README chain before deep file exploration
  - update the relevant folder `README.md` when structure, commands, tests, or invariants change
  - require a successful final app build before sign-off
  - require a relaunch of the freshly built app before sign-off so the running process matches the verified build
  - require at least one direct verification of built-app behavior rather than stopping at indirect unit evidence

## Canonical Job Context
- Active ongoing snapshot: none
- Completed job records live under `docs/jobs/archive/`

## Important Constraints
- Do not revert unrelated working tree changes.
- Use `apply_patch` for manual file edits.
- Keep temporary artifacts under `tmp/`.
