# Scrollapp App Module

This folder contains the production macOS app code, bundle metadata, and bundled assets for Scrollapp.

## Read This First

- `ScrollappApp.swift`: app entry point, menu bar lifecycle, permission checks, event tap wiring, accessibility hit-testing, and synthetic scroll delivery.
- `AutoscrollCore.swift`: pure logic for autoscroll physics, target classification, and fallback-axis decisions that should stay easy to test.
- `Info.plist` and `Scrollapp.entitlements`: touch these only when changing bundle configuration, permissions, or runtime capabilities.
- `Assets.xcassets/`: app icon and bundled visual assets.

## Key Rules

- Keep pure, testable autoscroll logic in `AutoscrollCore.swift`.
- Keep AppKit, accessibility, event tap, and other runtime side effects in `ScrollappApp.swift`.
- When activation, classification, or scroll physics behavior changes, update `../ScrollappTests/AutoscrollCoreTests.swift` in the same task.
- Keep runtime delivery on the live-pointer session-tap path.
- The runtime may latch the original owner and pause delivery while the pointer is outside that owner, but it must not retarget to a different owner.
- When latching an owner from AX ancestry, prefer the stable enclosing scroll host over a smaller nested web/text child so pause matching does not flicker inside one real scroll region.
- The verification-only command mode should stay test-only and preserve the real runtime split between physical pointer coordinates and Quartz delivery coordinates.
- If a change alters runtime behavior, build assumptions, or onboarding guidance, update this README and the repo root `README.md`.
- Do not sign off on behavior changes with unit tests alone; finish with a successful app build and a direct check of built-app behavior.

## Verification

- `xcodebuild test -project Scrollapp.xcodeproj -scheme Scrollapp -destination 'platform=macOS' -only-testing:ScrollappTests/AutoscrollCoreTests`
- `xcodebuild build -project Scrollapp.xcodeproj -scheme Scrollapp -destination 'platform=macOS'`
- `./scripts/open_autoscroll_fixture.sh`
- `./scripts/verify_autoscroll_external_no_cursor.sh`
- After building, launch the app and confirm the real interaction path works. For autoscroll changes, verify that actual scrolling occurs in the built app rather than only confirming intermediate logic.
