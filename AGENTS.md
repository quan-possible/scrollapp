# Repository Guidelines

## Project Structure & Module Organization
`Scrollapp/` contains the macOS app sources. `ScrollappApp.swift` owns the menu bar lifecycle, permissions, and event tap wiring; `AutoscrollCore.swift` holds testable scrolling physics and mode logic. `ScrollappTests/` contains unit tests for core behavior, and `ScrollappUITests/` contains launch and UI smoke tests. Release images live in `img/`, build and packaging automation lives in `scripts/`, `docs/jobs/` holds resumable job snapshots, and `tmp/` is for disposable local artifacts only. Use the folder READMEs as the first-pass module map:
- `README.md` for the repo-level overview
- `Scrollapp/README.md` for app/runtime architecture
- `ScrollappTests/README.md` for core logic test coverage
- `scripts/README.md` for build and local Xcode helpers

## Build, Test, and Development Commands
- `open Scrollapp.xcodeproj` opens the app in Xcode when the project file is available locally.
- `xcodebuild test -project Scrollapp.xcodeproj -scheme Scrollapp -destination 'platform=macOS'` runs the macOS test suite from the command line.
- `./scripts/build_universal.sh` creates a universal app bundle at `build/universal/Scrollapp.app`.
- `./scripts/create_dmg_from_app.sh build/universal/Scrollapp.app` packages the built app into a distributable DMG.
The current scripts assume `Scrollapp.xcodeproj` exists at the repository root, so keep that file in sync with source changes when updating the local project setup.

## Coding Style & Naming Conventions
Use standard Swift style: 4-space indentation, `UpperCamelCase` for types, and `lowerCamelCase` for properties and methods. Prefer small value types for pure logic, as in `AutoscrollPhysics` and `AutoscrollModeMachine`, and keep AppKit or permission side effects near the app delegate layer. Name files after the main type they contain, and keep UI-facing strings concise because most controls surface directly in the menu bar.

## Testing Guidelines
Write unit tests in `ScrollappTests/` with Swift Testing (`import Testing`, `@Test`, `#expect`) and name them by behavior, for example `velocityRespectsDeadZone`. Keep UI and launch checks in `ScrollappUITests/` with `XCTest`. No coverage threshold is enforced, so any change to activation rules, scrolling physics, accessibility targeting, or launch behavior should include focused regression tests. For behavior-affecting work, unit tests are not enough on their own: finish with a successful app build and at least one direct verification of the built app's real behavior.

## Commit & Pull Request Guidelines
Recent history favors short lowercase subjects such as `update readme` and `added launch at login`. Keep that brevity, but make new commits more specific and imperative, for example `refine activation dead-zone handling`. Pull requests should summarize the user-visible change, list test evidence, link related issues, and include screenshots or recordings for menu bar or onboarding changes. Call out any permission-sensitive changes involving Accessibility, Input Monitoring, or launch-at-login behavior.

## Software Development Contract
Use `software-development` for substantive coding tasks in this repository. Read the nearest README chain before deep file exploration, and update the relevant folder `README.md` in the same task whenever a change affects folder ownership, entry points, commands, tests, invariants, or notable gotchas. Create a canonical job snapshot at `docs/jobs/YYYY-MM-DD-<job-slug>-ongoing.md` only when the task is long-running, non-linear, multi-stage, or likely to be resumed; skip it for simple one-pass work. Use the job start date as the filename prefix and keep that same date if the job resumes later. Before sign-off, the app must build successfully, and verification must include at least one direct check of the delivered behavior. For autoscroll work, that direct check should exercise real scrolling in the built app through the actual event path, using reliable automation, instrumentation, or an explicit manual fixture check. When the task is done, move the job record to `docs/jobs/archive/YYYY-MM-DD-<job-slug>.md`.
