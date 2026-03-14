# Project Memory

Last updated: 2026-03-13

## Current Objective
- Finish Windows-style middle-click autoscroll parity on macOS.
- Keep the parent agent in sponsor/subagent-manager mode for the remaining implementation and verification work.

## Current State
- `Scrollapp/ScrollappApp.swift` uses a real `CGEventTap` rather than only `NSEvent` monitors.
- `Scrollapp/AutoscrollCore.swift` holds testable autoscroll physics, target classification, and mode logic.
- The current implementation already supports:
  - latched autoscroll anchored to the original click point
  - active target PID capture for synthetic wheel posting
  - hold vs toggle mode
  - first-click-to-exit swallowing
  - horizontal and vertical synthetic scrolling
  - modifier forwarding during autoscroll for host-app behaviors such as zoom
- Source-level typecheck has passed for:
  - `Scrollapp/AutoscrollCore.swift`
  - `Scrollapp/ScrollappApp.swift`

## Known Gaps
- The repo still does not contain a checked-in `.xcodeproj`, `.xcworkspace`, or `Package.swift`.
- README and build scripts still assume `Scrollapp.xcodeproj` exists.
- Full runtime validation is blocked until the project scaffold is restored or reconstructed.
- Remaining behavioral risks still to close:
  - activation classifier is too permissive when AX is missing or ambiguous
  - nested scroll propagation still needs real runtime proof against browsers/native apps
  - cursor behavior is still more static than Chromium/Windows directional panning cursors
  - lifecycle edge cases need explicit validation:
    - target becomes unscrollable mid-session
    - window/app/navigation changes
    - multi-display coordinate correctness
    - custom browser/Electron UI with weak AX metadata

## Research Conclusions
- Chromium is the strongest practical behavioral spec for Windows-style autoscroll parity.
- The core behavioral contract is:
  - target-latched activation, not hover-routed scrolling
  - per-axis propagation from the clicked target upward
  - `initial` / `holding` / `toggled` mode semantics
  - first click exits and is swallowed
  - actionable middle-click targets should pass through
  - 15 px dead zone and direction-aware cursor matter to the feel
- Apple-side architecture is already on the right primitive stack:
  - `CGEventTapCreate`
  - `CGEventSetLocation`
  - `CGEventPostToPid`
  - `AXUIElementCopyElementAtPosition`
  - AX scroll bar inspection and writable AX values as fallback

## Build And Tooling Notes
- Xcode is installed at `/Applications/Xcode.app`.
- The active developer path is expected to be Xcode, not Command Line Tools.
- `tmp/` is the disposable workspace for rolling snapshots and research notes.

## Canonical Temp Context
- Research snapshot: `tmp/autoscroll-research-2026-03-13.md`
- A canonical `*-ongoing.md` snapshot should be maintained during the implementation pass.

## Next Recommended Steps
- Restore or reconstruct the Xcode project scaffold.
- Finish the remaining autoscroll parity gaps with delegated workers.
- Add or refine regression tests around classifier behavior, mode transitions, and lifecycle exits.
- Run end-to-end manual validation in:
  - Safari
  - Chrome
  - Finder
  - Xcode
  - a native `NSScrollView`

## Important Constraints
- Do not revert unrelated working tree changes.
- Prefer subagent fan-out for moderate or larger work.
- Use `apply_patch` for manual file edits.
- Keep temporary artifacts under `tmp/`.
