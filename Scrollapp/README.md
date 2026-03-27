# Scrollapp App Module

This folder contains the production macOS app code, bundle metadata, and bundled assets for Scrollapp.

## Read This First

- `ScrollappApp.swift`: app entry point, menu bar lifecycle, permission checks, event tap wiring, accessibility hit-testing, synthetic scroll delivery, and verification-only hooks.
- `AutoscrollCore.swift`: pure logic for autoscroll physics, target classification, and the small runtime session model that should stay easy to test.
- `Info.plist` and `Scrollapp.entitlements`: touch these only when changing bundle configuration, permissions, or runtime capabilities.
- `Assets.xcassets/`: app icon and bundled visual assets.

## Key Rules

- Keep pure, testable autoscroll logic in `AutoscrollCore.swift`.
- Keep AppKit, accessibility, event tap, and other runtime side effects in `ScrollappApp.swift`.
- Keep the shipped product surface simple and accurate:
  middle-click activation only, with menu controls for speed, invert direction, launch-at-login, diagnostics, about, and quit.
- When activation, classification, or scroll physics behavior changes, update `../ScrollappTests/AutoscrollCoreTests.swift` in the same task.
- Keep middle-click activation toggle-only. Mouse-down should only arm the pending session, and releasing the same button should latch autoscroll without reintroducing a separate hold mode.
- Keep real wheel input from cancelling an active autoscroll session; explicit click stops remain the exit gesture.
- Keep session lifetime anchored to explicit stop clicks plus same-window continuity.
- Keep the existing gradual near-anchor speed ramp so motion does not jump abruptly when autoscroll starts.
- Keep runtime delivery on the live-pointer session-tap path.
- Keep the window latch strict; current runtime matching is window-based rather than owner-reclassification based.
- The verification-only command mode should stay test-only and preserve the real runtime split between physical pointer coordinates and Quartz delivery coordinates.
- If a change alters runtime behavior, build assumptions, or onboarding guidance, update this README and the repo root `README.md`.
- Do not sign off on behavior changes with unit tests alone; finish with a successful app build and a direct check of built-app behavior.

## Verification

- `xcodebuild test -project Scrollapp.xcodeproj -scheme Scrollapp -destination 'platform=macOS' -only-testing:ScrollappTests/AutoscrollCoreTests`
- `./scripts/verify_launch_smoke.sh`
- `xcodebuild build -project Scrollapp.xcodeproj -scheme Scrollapp -destination 'platform=macOS'`
- `./scripts/open_autoscroll_fixture.sh`
- `./scripts/verify_autoscroll_external_no_cursor.sh`
- After building, launch the app and confirm the real interaction path works. For autoscroll changes, verify that actual scrolling occurs in the built app rather than only confirming intermediate logic.
