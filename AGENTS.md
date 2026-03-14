# Repository Guidelines

## Project Structure & Module Organization
`Scrollapp/` contains the macOS app sources. `ScrollappApp.swift` owns the menu bar lifecycle, permissions, and event tap wiring; `AutoscrollCore.swift` holds testable scrolling physics and mode logic; `ContentView.swift` is the lightweight SwiftUI view layer. `ScrollappTests/` contains unit tests for core behavior, and `ScrollappUITests/` contains launch and UI smoke tests. Release images live in `img/`, build and packaging automation lives in `scripts/`, and `tmp/` is for disposable local artifacts only.

## Build, Test, and Development Commands
- `open Scrollapp.xcodeproj` opens the app in Xcode when the project file is available locally.
- `xcodebuild test -project Scrollapp.xcodeproj -scheme Scrollapp -destination 'platform=macOS'` runs the macOS test suite from the command line.
- `./scripts/build_universal.sh` creates a universal app bundle at `build/universal/Scrollapp.app`.
- `./scripts/create_dmg_from_app.sh build/universal/Scrollapp.app` packages the built app into a distributable DMG.
The current scripts assume `Scrollapp.xcodeproj` exists at the repository root, so keep that file in sync with source changes when updating the local project setup.

## Coding Style & Naming Conventions
Use standard Swift style: 4-space indentation, `UpperCamelCase` for types, and `lowerCamelCase` for properties and methods. Prefer small value types for pure logic, as in `AutoscrollPhysics` and `AutoscrollModeMachine`, and keep AppKit or permission side effects near the app delegate layer. Name files after the main type they contain, and keep UI-facing strings concise because most controls surface directly in the menu bar.

## Testing Guidelines
Write unit tests in `ScrollappTests/` with Swift Testing (`import Testing`, `@Test`, `#expect`) and name them by behavior, for example `velocityRespectsDeadZone`. Keep UI and launch checks in `ScrollappUITests/` with `XCTest`. No coverage threshold is enforced, so any change to activation rules, scrolling physics, accessibility targeting, or launch behavior should include focused regression tests.

## Commit & Pull Request Guidelines
Recent history favors short lowercase subjects such as `update readme` and `added launch at login`. Keep that brevity, but make new commits more specific and imperative, for example `refine activation dead-zone handling`. Pull requests should summarize the user-visible change, list test evidence, link related issues, and include screenshots or recordings for menu bar or onboarding changes. Call out any permission-sensitive changes involving Accessibility, Input Monitoring, or launch-at-login behavior.
