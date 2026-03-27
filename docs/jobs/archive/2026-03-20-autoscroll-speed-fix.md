# Autoscroll Speed Fix

## Current Objective
- Make Windows-style middle-click autoscroll feel meaningfully faster as the pointer moves farther from the anchor, without regressing delivery or target-latching behavior.

## Scope
- Production code:
  - `Scrollapp/AutoscrollCore.swift`
  - `Scrollapp/ScrollappApp.swift`
- Tests:
  - `ScrollappTests/AutoscrollCoreTests.swift`
- Docs only if behavior or verification guidance changes materially:
  - `README.md`
  - `Scrollapp/README.md`
  - `ScrollappTests/README.md`

## Working Diagnosis
- The current physics curve is monotonic but saturates early.
- The runtime emits at `60 Hz`, which is slower than an earlier `100 Hz` version and likely contributes to the sluggish feel.
- Owner/window latching may pause delivery when the pointer moves far from the anchor.
- Verification currently proves scrolling occurs, but not that the speed profile feels correct.

## Active Workstreams
- Parent:
  - manage delegation
  - own verification and final integration
- Worker:
  - patch autoscroll speed behavior
  - add/update focused regression tests

## Verification Plan
- Focused tests:
  - `xcodebuild test -project Scrollapp.xcodeproj -scheme Scrollapp -destination 'platform=macOS' -only-testing:ScrollappTests/AutoscrollCoreTests`
- Final build:
  - `xcodebuild build -project Scrollapp.xcodeproj -scheme Scrollapp -destination 'platform=macOS'`
- Direct behavior check:
  - `./scripts/verify_autoscroll_external_no_cursor.sh`
  - plus targeted observation of emitted velocity/delivery behavior if needed

## Status
- Worker implementation completed and reviewed.
- Parent verification completed successfully.
- Ready to archive.

## Results
- Production changes:
  - autoscroll velocity is now modeled as a time-based rate instead of a per-tick step
  - the emission loop runs at the preferred `100 Hz` cadence again
  - emitted deltas now preserve cumulative distance across tick rates with subpixel carry
- Verification support changes:
  - `scripts/verify_autoscroll_external_no_cursor.sh` now waits for the real timer-driven session to move the external fixture instead of forcing direct `performScroll()` calls
  - `scripts/README.md` now documents that timer-driven external verification behavior

## Verification Results
- Focused tests:
  - `xcodebuild test -project Scrollapp.xcodeproj -scheme Scrollapp -destination 'platform=macOS' -only-testing:ScrollappTests/AutoscrollCoreTests`
  - passed: `41` tests
- Final build:
  - `xcodebuild build -project Scrollapp.xcodeproj -scheme Scrollapp -destination 'platform=macOS'`
  - passed
- Direct external verification:
  - `./scripts/verify_autoscroll_external_no_cursor.sh`
  - passed
  - observed scroll offset change: `420 -> 959` (`+539`)

## Notes
- The old external verification flow became stale once autoscroll changed from tick-based stepping to timer-driven rate control.
- Owner/window latch behavior was intentionally left unchanged in this pass; this fix targets speed feel and emission stability, not the separate “pause outside latched owner” behavior.

## Read This First After Compaction
- This file is the continuity anchor for the autoscroll-speed bug fix.
- The job is complete and can be read from the archived record after this file is moved.
