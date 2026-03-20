# Autoscroll ongoing

Date: 2026-03-13

Current objective:
- Finish Windows-style autoscroll parity for Scrollapp, with the current focus on the remaining live issues after permissions/runtime activation started working:
  - cursor is still getting stuck in place during live use
  - toggled autoscroll is still unreliable and may require holding the middle button
  - verify that the newest pass-through heuristics now preserve intended middle-click actions on clickable web cards such as X/Twitter posts
  - the next validation pass should include direct browser/runtime interaction instead of relying only on smoke checks
  - latest live evidence now proves the app can start, emit velocity, and deliver scrolls, but still stops as `activation button released after hold`, so the next pass should be a simplification/rewrite of the activation state machine rather than another incremental patch

Current state:
- Confirmed live success on 2026-03-13:
  - user verified: “Perfect. It works now.”
  - this confirms the cursor-teleport / cursor-sucked-into-icon bug is fixed in the currently installed `/Applications/Scrollapp.app`
  - the decisive final fix was:
    - stop overwriting `scrollEvent.location` in `deliverScrollEvent(...)`
    - keep the earlier real-pointer tracking fix so autoscroll reads physical pointer movement without letting synthetic events redefine the cursor
  - current verified outcome:
    - autoscroll can toggle on
    - the cursor now remains free instead of being teleported back to the icon
    - the installed app at `/Applications/Scrollapp.app` is the latest signed verified build
- Cursor-location safety pass on 2026-03-13:
  - user confirmed the exact contract:
    - the autoscroll icon and synthetic scrolling must not touch, write to, or transport the cursor
  - local runtime check showed:
    - a newly created synthetic `CGEvent` scroll wheel event already inherits the live cursor location by default
  - highest-confidence remaining live bug:
    - `deliverScrollEvent(...)` was still explicitly doing:
      - `scrollEvent.location = session.deliveryPoint`
    - that meant the app was writing every synthetic scroll event back to the anchor/icon location even after the pointer-tracking fix
    - this is the strongest explanation for the user’s “cursor is teleported to the icon / flickers at the icon” report
  - latest fix integrated:
    - `deliverScrollEvent(...)` no longer overwrites `scrollEvent.location`
    - synthetic scroll delivery now uses the event’s live default pointer location instead of writing the anchor back into the event
    - diagnostics now report:
      - `Scroll Delivery: session tap live-pointer (...)`
  - intent of this pass:
    - preserve the working toggle behavior
    - stop any remaining synthetic event path from writing the cursor back to the icon
- Pointer-freedom follow-up pass on 2026-03-13:
  - user clarified the hard contract:
    - autoscroll must not touch, write to, or otherwise redefine the cursor
    - it may only read cursor movement to compute speed relative to the anchored icon
  - new highest-confidence root cause:
    - the app was polling `NSEvent.mouseLocation` during autoscroll while also injecting synthetic scroll events back into the event stream at the latched anchor
    - this likely let synthetic events contaminate the “current cursor” source and created the live feeling that the cursor was being sucked back to the icon
  - latest runtime fix integrated in `Scrollapp/ScrollappApp.swift`:
    - event tap now listens for real pointer-motion events:
      - `mouseMoved`
      - `leftMouseDragged`
      - `rightMouseDragged`
      - `otherMouseDragged`
    - the app now tracks `lastPhysicalPointerLocation` only from real pointer/button events
    - `performScroll()` now uses that tracked physical pointer location instead of polling `NSEvent.mouseLocation`
    - the indicator panel was softened further:
      - size reduced from `28x28` to `20x20`
      - level lowered from `.statusBar` to `.floating`
  - intent of this pass:
    - preserve the anchored icon
    - preserve autoscroll speed based on cursor distance from the icon
    - stop synthetic wheel delivery from becoming the source of truth for cursor position
- Latest integration pass on 2026-03-13:
  - fixed a coordinate-space mismatch between `CGEvent.location` and `NSEvent.mouseLocation`
  - the session now uses:
    - `anchorPoint` in unflipped/AppKit-style screen coordinates for toggle-vs-hold math and indicator placement
    - `deliveryPoint` in CG global display coordinates for synthetic wheel delivery
  - this directly targets the live bug where a normal single middle click was being promoted to `holding` and then stopping as:
    - `Stop Reason: activation button released after hold`
  - scroll delivery was simplified back to one anchored session-stream path:
    - `scrollEvent.post(tap: .cgSessionEventTap)` at the latched `deliveryPoint`
    - `postToPid` is no longer the primary route in the live build
  - expected user-visible effects of this pass:
    - single middle-click should now latch into toggled mode instead of requiring hold
    - visible scrolling should resume because delivery no longer depends on PID routing
    - the indicator remains anchored while the real cursor stays free
- `AGENTS.md` is present and has been read.
- `MEMORY.md` has now been created to restore the compact project memory layer.
- Source-level implementation exists in `Scrollapp/ScrollappApp.swift` and `Scrollapp/AutoscrollCore.swift`.
- Source-level typecheck already passed.
- `Scrollapp.xcodeproj` has now been restored via `xcodegen` and the generated project is checked into the worktree.
- `xcodebuild build` now succeeds.
- The built app now has populated bundle metadata in its processed `Info.plist`.
- The launch crash caused by `UNUserNotificationCenter.current()` at startup has been fixed in the app source.
- The default `Scrollapp` scheme now passes from the local wrapper path with `25` tests green.
- The dedicated `ScrollappUITests` scheme now passes from the local wrapper path with `2` tests green, including a fresh-DerivedData run.
- The user explicitly does not want UI verification treated as optional, so the UI lane remains part of the finish line.
- The old `ScrollappUITests` linker/output-path failure has now been fixed by removing `BUNDLE_LOADER` from the generated macOS UI-testing target.
- The UI tests now launch by explicit bundle identifier.
- A project-level post-build xattr scrub has been added for the app and UI-test bundle because Google Drive / File Provider metadata was breaking `codesign` for signed UI runs.
- A local wrapper workflow now exists in `scripts/open_local_xcode.sh` for Xcode GUI work outside Google Drive / File Provider.
- `README.md` and `scripts/README.md` now recommend the safest workflow for Drive-backed repos:
  - `SCROLLAPP_XCODE_LOCAL_DIR=/private/tmp/scrollapp-xcode ./scripts/open_local_xcode.sh --check --no-open`
  - then open `/private/tmp/scrollapp-xcode/Scrollapp.xcodeproj` manually from Xcode
- The wrapper script now prints a manual fallback if its automatic `open -a /Applications/Xcode.app ...` step fails on this machine.
- A persistent manual verification harness now exists:
  - fixture page: `manual/autoscroll-fixture.html`
  - helper launcher: `scripts/open_autoscroll_fixture.sh`
  - documented in `scripts/README.md`
- The app now has live runtime diagnostics in the menu bar:
  - `Accessibility`
  - `Input Monitoring`
  - `Event Posting`
  - `Event Tap`
  - plus `Refresh Permissions`
- The project is now configured for real signing:
  - `project.yml` sets `DEVELOPMENT_TEAM: H9M8KNW35G`
  - `project.yml` sets `CODE_SIGN_STYLE: Automatic`
- `/Applications/Scrollapp.app` has been replaced with a correctly signed build:
  - identifier: `com.fromis9.scrollapp`
  - authority: `Apple Development: bruce.quan.nguyen@gmail.com (2WF29X2V22)`
  - team: `H9M8KNW35G`
- The app’s saved activation method is confirmed to be `Middle Click` via user defaults.
- A canonical product spec now exists at:
  - `specs.md`
- The spec records acceptance criteria for:
  - activation
  - target latching
  - cursor freedom
  - anchored indicator behavior
  - speed curve / feel
  - actionable middle-click pass-through
  - stop semantics
  - diagnostics
  - manual verification matrix
- Latest user-reported live diagnostics from the running signed app:
  - `Accessibility: Granted`
  - `Input Monitoring: Granted`
  - `Event Posting: Granted`
  - `Event Tap: Active`
- Despite that, middle-click autoscroll still “does nothing” from the user’s perspective.
- A new signed build with the latest activation-path fixes is now installed at `/Applications/Scrollapp.app` and relaunched.
- Wrapper validation is green:
  - `./scripts/open_local_xcode.sh --check --no-open`
  - `xcodebuild -list -project /Users/brucenguyen/tmp/scrollapp-xcode/Scrollapp.xcodeproj`
  - `xcodebuild -project /Users/brucenguyen/tmp/scrollapp-xcode/Scrollapp.xcodeproj -scheme Scrollapp -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO test`
  - `xcodebuild -project /Users/brucenguyen/tmp/scrollapp-xcode/Scrollapp.xcodeproj -scheme ScrollappUITests -destination 'platform=macOS' -test-timeouts-enabled YES -default-test-execution-time-allowance 20 -maximum-test-execution-time-allowance 30 test`
- Fresh wrapper-path normal launch verification is green:
  - wrapper-built `Scrollapp.app` launched, stayed alive for the check window, and quit cleanly
  - no fresh `Scrollapp` crash report was generated during that check
- Fresh verification after the coordinate/delivery fix is green:
  - `xcodebuild -project /private/tmp/scrollapp-xcode/Scrollapp.xcodeproj -scheme Scrollapp -destination 'platform=macOS' test`
    - passed with `27` tests
  - `xcodebuild -project /private/tmp/scrollapp-xcode/Scrollapp.xcodeproj -scheme ScrollappUITests -destination 'platform=macOS' -test-timeouts-enabled YES -default-test-execution-time-allowance 20 -maximum-test-execution-time-allowance 30 test`
    - passed with `2` UI smoke tests
  - `/Applications/Scrollapp.app` has been rebuilt, re-signed, replaced, and relaunched from the latest verified build
- Fresh verification after the pointer-tracking fix is also green:
  - `xcodebuild -project /private/tmp/scrollapp-xcode/Scrollapp.xcodeproj -scheme Scrollapp -destination 'platform=macOS' test`
    - passed with `27` tests
  - `xcodebuild -project /private/tmp/scrollapp-xcode/Scrollapp.xcodeproj -scheme ScrollappUITests -destination 'platform=macOS' -test-timeouts-enabled YES -default-test-execution-time-allowance 20 -maximum-test-execution-time-allowance 30 test`
    - passed with `2` UI smoke tests
  - `/Applications/Scrollapp.app` was rebuilt, re-signed, replaced, and relaunched again from the latest verified build
- Fresh verification after the cursor-location safety fix is green:
  - `xcodebuild -project /private/tmp/scrollapp-xcode/Scrollapp.xcodeproj -scheme Scrollapp -destination 'platform=macOS' -derivedDataPath /private/tmp/scrollapp-dd-main-cursorfix-1773450692 test`
    - passed with `27` tests
  - `xcodebuild -project /private/tmp/scrollapp-xcode/Scrollapp.xcodeproj -scheme ScrollappUITests -destination 'platform=macOS' -test-timeouts-enabled YES -default-test-execution-time-allowance 20 -maximum-test-execution-time-allowance 30 test`
    - passed with `2` UI smoke tests
  - `/Applications/Scrollapp.app` was rebuilt, re-signed, replaced, and relaunched from the latest verified build
- Latest implementation pass integrated:
  - `Scrollapp/ScrollappApp.swift`
    - session motion origin now uses the actual click point
    - AX metadata collection now includes actions and control metadata
    - indicator redesigned to a smaller neutral static style
    - PID-aware delivery added with session-tap fallback
  - `Scrollapp/AutoscrollCore.swift`
    - stronger generic actionable metadata heuristics added
    - interactive web-card pass-through tightened for browser content such as X/Twitter post cards
    - motion curve tuned faster with stronger early pickup and higher cruise/max speed
  - `ScrollappTests/AutoscrollCoreTests.swift`
    - added generic actionable metadata tests
    - added interactive web-card pass-through test
    - updated launch-speed threshold for the faster curve
- The latest signed build has been rebuilt, reinstalled, and relaunched at:
  - `/Applications/Scrollapp.app`
- Latest runtime-fix pass is now integrated:
  - `Scrollapp/ScrollappApp.swift`
    - `startAutoScroll(with:)` now preserves the real activation-button-down state across startup instead of clearing it via the generic stop path
    - `performScroll()` now stops immediately when runtime mode becomes `.inactive`, which closes the hold-release edge case
    - frontmost-app mismatch checks are now suppressed while the activation button is still down or the session is still in `initial`, so a single click can reliably complete the `.initial -> .toggled` transition
    - scroll delivery now prefers `postToPid` for external target apps instead of forcing browsers/Electron through session-tap-first delivery
    - session-tap fallback now uses the live pointer location instead of the anchored location to avoid pointer-snapping behavior on fallback delivery
    - the anchored indicator was simplified to a thin monochrome ring-only design with no center dot or crosshair
  - `Scrollapp/AutoscrollCore.swift`
    - generic-action detection now distinguishes:
      - generic action + strong metadata => `passThrough`
      - generic action without strong metadata => `undetermined`
    - explicit scrollability no longer wins before generic-action ambiguity is considered, which keeps clickable cards inside scrollable web areas from being auto-started just because an ancestor scroll view exists
    - added extra generic action names and metadata tokens for modern browser/web-app chrome
  - `ScrollappTests/AutoscrollCoreTests.swift`
    - added regression coverage for:
      - generic web cards without strong metadata staying `undetermined`
      - generic web cards inside explicit scroll ancestors staying `undetermined`

Worker ownership:
- Worker A: behavior completion in `Scrollapp/ScrollappApp.swift` and `Scrollapp/AutoscrollCore.swift`
- Worker B: build/project recovery in project/scaffold/docs wiring files
- Worker C: regression tests and verification support in `ScrollappTests/` and `ScrollappUITests/`

Current worker fan-out for the latest finish pass:
- Worker `Poincare` owns only:
  - `Scrollapp/AutoscrollCore.swift`
  - `ScrollappTests/AutoscrollCoreTests.swift`
  - goals:
    - stronger actionable metadata heuristics for Electron/Obsidian-style generic AX nodes
    - faster, less draggy speed curve while keeping 15 px dead zone
    - focused regression tests
- Worker `Fermat` owns only:
  - `Scrollapp/ScrollappApp.swift`
  - goals:
    - use click point as motion origin
    - enrich AX metadata collection
    - improve PID-aware scroll delivery with fallback
    - redesign indicator to small monochrome static style
- Latest worker results have been integrated:
  - `Poincare` completed core heuristics, feel tuning, and regression tests
  - `Fermat` completed app-layer motion-origin, AX metadata, delivery, indicator, and install pass
  - `Hypatia` supplied the follow-up browser-card pass-through heuristic used for X/Twitter-style clickable web targets

Current live fan-out after compaction:
- Worker `Halley` owns only:
  - `Scrollapp/AutoscrollCore.swift`
  - `ScrollappTests/AutoscrollCoreTests.swift`
  - goal: widen ancestor-based web/scroll activation and add focused regression tests
- Worker `Gauss` owns only:
  - `Scrollapp/ScrollappApp.swift`
  - goal: add last-activation diagnostics to the runtime menu
- Explorer `Euclid` owns:
  - read-only audit of button-number and event-type assumptions for middle click handling

Key findings:
- The architecture is on the right track: event tap, target latching by anchor point, suppression of activation clicks, and modifier forwarding are the correct primitive stack.
- Remaining likely gaps are edge-case parity and runtime validation rather than a full redesign.
- Simplification/research pass findings on 2026-03-13:
  - the current codebase is carrying too many overlapping mechanisms for one feature:
    - timer-driven mode transitions
    - button-up mode transitions
    - app-layer and core-layer actionability heuristics
    - dual delivery paths with fallback behavior that can reintroduce hover-routed behavior
    - duplicate anchor-like state via `anchorEventPoint` and `movementOrigin`
  - latest user-provided diagnostics:
    - `Accessibility: Granted`
    - `Input Monitoring: Granted`
    - `Event Posting: Granted`
    - `Event Tap: Active`
    - `Last Mouse Trigger: otherMouseDown button=2 @ (2179, 334)`
    - `Activation Match: yes`
    - `AX Hit-Test: AXGroup > AXWebArea > AXScrollArea > AXGroup > ... [H:N V:Y]`
    - `Activation Decision: start (horizontal + vertical)`
    - `Scroll Emission: vx=0.0 vy=64.0`
    - `Scroll Delivery: target pid 41059 (0, 64)`
    - `Stop Reason: activation button released after hold`
  - this proves:
    - permissions are no longer the blocker
    - the event tap sees the click
    - classification starts a session
    - velocity is being computed
    - delivery is happening
    - the remaining failure is the activation/session state machine, especially the click-release vs hold-release split
  - strongest subagent conclusion:
    - the simplest path forward is a small rewrite with one activation state machine and one delivery model, not more local patching
- Latest code-audit findings from subagents that directly drove the current patch:
  - early frontmost-app mismatch stopping could kill the session before `otherMouseUp` completed the `.initial -> .toggled` transition, which makes toggle mode feel like it requires holding
  - actionable generic web cards could still start autoscroll because ancestor scrollbars were treated as strong explicit scrollability before generic-action ambiguity was resolved
  - the indicator itself was visually dominating the cursor hotspot even though no direct cursor-warp API remained in source
- Latest targeted audit findings:
  - previous issues around motion origin, indicator dominance, weak actionable heuristics, and draggy feel have now been patched in source
  - new live report during this pass:
    - middle-clicking an X/Twitter post still triggered autoscroll instead of the intended open-in-new-tab action
  - follow-up fix applied:
    - generic interactive web-card targets inside `AXWebArea` now pass through when they expose real interactive actions plus metadata
  - latest live report after that fix:
    - the cursor still appears stuck in one place
    - toggled mode no longer feels reliable and may require holding the middle button
- Chromium/browser behavior establishes the main parity targets:
  - target-latched autoscroll
  - per-axis propagation/chaining from the clicked target
  - `initial` / `holding` / `toggled` mode behavior
  - first click exits and is swallowed
  - 15 px dead zone
  - directional cursor behavior

Active blockers:
- Xcode GUI can freeze while opening `Scrollapp.xcodeproj`, even though `xcodebuild` still works. Current sample evidence points to coordinated recursive reads of the Drive-backed project container.
- The wrapper path avoids the Xcode GUI freeze, but the Drive-backed project should still be treated as unsuitable for direct Xcode GUI use.
- The old UI automation timeout is no longer reproducing from the wrapper path after permissions were granted and tests were run outside the Drive-backed project.
- The repo-side project-generation hygiene issue is now closed: `project.yml` explicitly sets `BUNDLE_LOADER: ""` for `ScrollappUITests`, and the generated project keeps that explicit empty value.
- No known correctness-affecting build, launch, or project-plumbing blocker remains in the repo.
- Remaining uncertainty is runtime breadth, not a known defect:
  - no full interactive browser/native app matrix has been executed end to end from this terminal session
  - UI coverage is still launch-smoke only and does not simulate live autoscroll interaction
  - the new fixture reduces that gap for manual verification but does not replace a human-driven feel check
- New primary blocker:
  - the signed app has all required permissions and an active event tap, but middle click still does nothing
  - this narrows the issue to the activation path inside the app rather than macOS permissions or signing
- Highest-confidence current theory:
  - the app is seeing the click but classifying it into pass-through (most likely AX hit-test failure or activation decision rejecting the target)
  - less likely, but still possible: the click is seen and rejected earlier in the activation path despite `activationMethod = Middle Click`

Success criteria:
1. `xcodebuild test -project Scrollapp.xcodeproj -scheme Scrollapp -destination 'platform=macOS'` passes from the wrapper path.
2. `xcodebuild test -project Scrollapp.xcodeproj -scheme ScrollappUITests -destination 'platform=macOS'` passes from the wrapper path.
3. The built app launches and stays alive in a normal run.
4. No correctness-affecting crash remains unresolved in current logs.

Related temp artifacts:
- `tmp/autoscroll-progress.md`
- `tmp/autoscroll-research-2026-03-13.md`

Immediate next steps:
1. Main live blocker is closed.
2. Next optional finish passes if resumed:
   - tighten remaining actionable middle-click pass-through in apps like Obsidian / X / Electron chrome
   - continue feel tuning for speed / momentum parity if the user wants more polish
   - compact this ongoing file now that the core runtime bug is resolved
3. If new runtime behavior still fails in a later pass, collect the current menu diagnostics:
   - `Activation Decision`
   - `Session State`
   - `Scroll Emission`
   - `Scroll Delivery`
   - `Stop Reason`

Active rewrite fan-out:
- Worker `Poincare` owns only:
  - `Scrollapp/AutoscrollCore.swift`
  - `ScrollappTests/AutoscrollCoreTests.swift`
  - goal:
    - simplify the core to one state machine and one anchor model
    - remove `movementOrigin` and cursor-style machinery
    - keep only the minimal classifier/physics/stop policy needed by the simplified spec
- Worker `Fermat` owns only:
  - read-only planning for `Scrollapp/ScrollappApp.swift`
  - goal:
    - produce the precise app-layer rewrite plan against the simplified core API
    - identify deletions, lifecycle responsibilities, and regression traps
- Worker `Banach` owns only:
  - read-only verification planning
  - goal:
    - produce the minimal recursive verify loop and manual/live matrix for the rewrite

Current rewrite strategy:
- use `mouseUp` as the only authority for click-vs-hold resolution
- do not fully start scrolling on `middleMouseDown`
- on `middleMouseDown` only:
  - classify target
  - create a pending `initial` session
  - show a fixed anchor indicator
  - swallow only the activation down event
- while button remains down:
  - only watch dead-zone crossing
  - if crossed, switch to `holding` and begin active emission
- on `middleMouseUp`:
  - if still `initial`, switch to `toggled` and begin active emission
  - if `holding`, stop

Latest rewrite integration status:
- Simplified core rewrite has now been landed in:
  - `Scrollapp/AutoscrollCore.swift`
  - `ScrollappTests/AutoscrollCoreTests.swift`
- Simplified app-lifecycle rewrite has now been landed in:
  - `Scrollapp/ScrollappApp.swift`
- Main simplifications now in source:
  - one anchor point via `AutoscrollSession.anchorPoint`
  - no `movementOrigin`
  - no cursor-style machinery
  - no trackpad activation path
  - no activation-method branching beyond middle click
  - timer no longer owns release transitions
  - `mouseUp` is now the authoritative click-vs-hold resolution path
  - delivery now uses anchored routing with a single PID-first/session-fallback model
- Current verified build/test status:
  - wrapper main tests passed in fresh DerivedData:
    - `xcodebuild -project /private/tmp/scrollapp-xcode/Scrollapp.xcodeproj -scheme Scrollapp -destination 'platform=macOS' -derivedDataPath /private/tmp/scrollapp-xcode/tmp/dd-rewrite-main test`
  - wrapper UI smoke tests passed:
    - `xcodebuild -project /private/tmp/scrollapp-xcode/Scrollapp.xcodeproj -scheme ScrollappUITests -destination 'platform=macOS' -test-timeouts-enabled YES -default-test-execution-time-allowance 20 -maximum-test-execution-time-allowance 30 test`
  - fresh signed install copied to:
    - `/Applications/Scrollapp.app`
- Current live-validation target:
  - verify plain-content single middle click now toggles reliably after release
  - verify hold path stops on release
  - verify the real cursor no longer feels trapped/jumpy
  - verify actionable middle-click pass-through still works for links/cards/tabs

Context-overcrowding audit result:
- After compaction, the intended minimum reload set for this job is:
  - `AGENTS.md`
  - `MEMORY.md`
  - `specs.md`
  - `docs/jobs/archive/2026-03-13-autoscroll.md`
- Recommended routing to reduce overlap:
  - `AGENTS.md` = rules only
  - `MEMORY.md` = stable project state only
  - `specs.md` = behavior contract only
  - `docs/jobs/archive/2026-03-13-autoscroll.md` = only live execution state, latest evidence, active workers, next actions

Subagent-manager invocation contract for this job:
- Resume this task in sponsor-first mode, not solo-implementation mode.
- Read first:
  - `AGENTS.md`
  - `MEMORY.md`
  - `specs.md`
  - `docs/jobs/archive/2026-03-13-autoscroll.md`
- Use the `subagent-manager` skill explicitly because the user requested manager-style execution.
- Parent-agent responsibilities:
  - do minimal direct work
  - split work into narrow, non-overlapping worker scopes
  - keep `docs/jobs/archive/2026-03-13-autoscroll.md` as the single canonical continuity file
  - route artifacts and findings between workers
  - do final QA/integration only where central coordination is required
- Default worker lanes for this rewrite:
  - core/state-machine worker
  - app-lifecycle/delivery worker
  - verification/repro worker
- Keep recursive execute-and-verify active for every editing pass.

Read this first after compaction:
- `specs.md`
- `docs/jobs/archive/2026-03-13-autoscroll.md`
- then inspect the newest worker edits in:
  - `Scrollapp/AutoscrollCore.swift`
  - `Scrollapp/ScrollappApp.swift`
  - `ScrollappTests/AutoscrollCoreTests.swift`
  - and use the installed app at `/Applications/Scrollapp.app`
- if resuming the simplification pass, prioritize:
  - stripping the runtime architecture down to the minimum stable contract above
  - not preserving backward-compatible paths inside the implementation

Latest verification:
- Wrapper validation also passes:
  - `xcodebuild -list -project /Users/brucenguyen/tmp/scrollapp-xcode/Scrollapp.xcodeproj`
  - `xcodebuild -project /Users/brucenguyen/tmp/scrollapp-xcode/Scrollapp.xcodeproj -scheme Scrollapp -destination 'platform=macOS' -derivedDataPath /Users/brucenguyen/tmp/scrollapp-xcode/tmp/dd-test-stabilization-main-1773437135 CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO test`
    - result: `25` tests green
  - `xcodebuild -project /Users/brucenguyen/tmp/scrollapp-xcode/Scrollapp.xcodeproj -scheme ScrollappUITests -destination 'platform=macOS' -derivedDataPath /Users/brucenguyen/tmp/scrollapp-xcode/tmp/dd-test-stabilization-ui-1773437155 -resultBundlePath /Users/brucenguyen/tmp/scrollapp-xcode/tmp/ui-test-stabilization-1773437155.xcresult -test-timeouts-enabled YES -default-test-execution-time-allowance 20 -maximum-test-execution-time-allowance 30 test`
    - result: `2` UI tests green
  - wrapper-built app at `/private/tmp/scrollapp-launch-dd/Build/Products/Debug/Scrollapp.app` launches, stays alive, and quits cleanly
- Signing/runtime verification after the latest signing pass:
  - `/Applications/Scrollapp.app` is now signed with Apple Development and team `H9M8KNW35G`
  - the app’s menu reports all permissions granted and `Event Tap: Active`
  - user still reports that middle click does nothing
- Latest verification after the runtime-fix pass on 2026-03-13:
  - `xcodebuild test -project /private/tmp/scrollapp-xcode/Scrollapp.xcodeproj -scheme Scrollapp -destination 'platform=macOS' -derivedDataPath /private/tmp/scrollapp-xcode/tmp/dd-finish-main CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO`
    - result: `45` tests passed
    - xcresult: `/tmp/scrollapp-xcode/tmp/dd-finish-main/Logs/Test/Test-Scrollapp-2026.03.13_18-10-47--0600.xcresult`
  - `xcodebuild test -project /private/tmp/scrollapp-xcode/Scrollapp.xcodeproj -scheme ScrollappUITests -destination 'platform=macOS' -derivedDataPath /private/tmp/scrollapp-xcode/tmp/dd-finish-ui -test-timeouts-enabled YES -default-test-execution-time-allowance 20 -maximum-test-execution-time-allowance 30`
    - result: `2` UI tests passed
    - xcresult: `/tmp/scrollapp-xcode/tmp/dd-finish-ui/Logs/Test/Test-ScrollappUITests-2026.03.13_18-11-09--0600.xcresult`
  - `/Applications/Scrollapp.app` was replaced from `/private/tmp/scrollapp-xcode/tmp/dd-finish-ui/Build/Products/Debug/Scrollapp.app`
  - installed app codesign verification:
    - `Identifier=com.fromis9.scrollapp`
    - `Authority=Apple Development: bruce.quan.nguyen@gmail.com (2WF29X2V22)`
    - `TeamIdentifier=H9M8KNW35G`

Parity-fix pass on 2026-03-13:
- `Scrollapp/AutoscrollCore.swift` now resolves the activation-button release after re-evaluating dead-zone crossing, which fixes the hold-vs-toggle race when release happens before the next timer tick.
- `Scrollapp/ScrollappApp.swift` now applies that same transition on the actual middle-button-up path, not just in timer-driven updates.
- Activation classification is stricter:
  - weak AX roles such as `AXTextField` and generic `AXScrollArea` now fall back to pass-through instead of eagerly starting autoscroll
  - accepted web content still gets a narrow axis fallback for `AXWebArea` and `AXScrollArea` that encloses `AXWebArea`
- Regression coverage now includes:
  - weak-role classifier assertions for `AXScrollArea`, `AXTextField`, and `AXScrollArea` + `AXWebArea`
  - release-after-dead-zone-crossing transition assertion
  - vertical inversion assertion
- UI smoke tests are now launch-only, which removes the brittle terminate requirement that previously caused hangs.

Activation-path investigation on 2026-03-13:
- `defaults read com.fromis9.scrollapp` confirms:
  - `activationMethod = "Middle Click"`
- Runtime audit found no remaining permission/signing blocker once the app was correctly signed and relaunched.
- Explorer recommendation for the next diagnostic patch:
  - add one `LastActivationDebug`-style block to the menu with four lines:
    - `Last Mouse Trigger`
    - `Activation Match`
    - `AX Hit-Test`
    - `Activation Decision`
- Purpose of each field:
  - `Last Mouse Trigger`: prove the tap saw `.otherMouseDown button=2`
  - `Activation Match`: prove the configured trigger matched or explain first rejection reason
  - `AX Hit-Test`: prove AX resolved an element or failed with a reason
  - `Activation Decision`: show `start` vs `passThrough` and why
- This is the recommended next patch after compaction because it will separate:
  - click not seen
  - wrong button/config
  - AX hit-test failure
  - classifier pass-through

Most likely runtime root cause from the latest explorer pass:
- The highest-probability failure is now the AX classifier rather than the event tap or permissions.
- Likely failure shape:
  - middle click is received
  - AX role chain is leaf-first
  - `AutoscrollActivationClassifier` gives special treatment only to `primaryRole`
  - ordinary web/page text therefore resolves to `.undetermined`
  - `ScrollappApp` turns that into pass-through
  - from the user’s perspective, middle click “does nothing”
- Most likely concrete bug:
  - `AXWebArea` is treated as a start signal only when it is the leaf role, not when it appears as an ancestor in the AX chain
  - this is especially likely on plain page content where the clicked leaf is text/static content inside a web area
- Secondary likely issue:
  - scrollability detection depends too heavily on AX scrollbar presence
  - hidden/overlay scrollbars in browsers and custom views can make the app conclude that no scrollable target exists
- Lower-probability issue:
  - AX coordinate conversion could still fail in some apps or multi-display setups, but this is currently less likely than the classifier bug

Smallest high-probability patch after compaction:
- Patch the classifier first, not the event tap.
- Change activation classification so ancestor presence can start autoscroll after actionable-role checks:
  - start when roles contain `AXWebArea`
  - start when roles contain both `AXScrollArea` and `AXWebArea`
  - keep actionable roles/subroles as pass-through
  - keep explicit scrollbar evidence as a strong positive signal
- This is the smallest patch with the highest likelihood of making middle click start on ordinary page content without destabilizing the rest of the event path.

Latest implementation state on 2026-03-13:
- The source tree now includes the likely-fix classifier broadening:
  - `AutoscrollTargetClassifier.behavior` now starts when `roles.contains("AXWebArea")`
  - `AutoscrollTargetClassifier.fallbackAxes` now uses ancestor `AXWebArea` rather than only the leaf/primary role
- Focused regression tests were added for:
  - leaf content inside a web area
  - fallback axes for ancestor-backed web content
  - text fields inside web content staying non-activating
- The live runtime diagnostics block is now in the app menu and records:
  - `Last Mouse Trigger`
  - `Activation Match`
  - `AX Hit-Test`
  - `Activation Decision`
- The event path now writes those diagnostics during `.otherMouseDown` handling and activation classification.

Latest verification from this terminal:
- Wrapper-path app build succeeds:
  - `xcodebuild -project /private/tmp/scrollapp-xcode/Scrollapp.xcodeproj -scheme Scrollapp -destination 'platform=macOS' -derivedDataPath /private/tmp/scrollapp-build-install CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build`
  - result: `** BUILD SUCCEEDED **`
- The best-effort local test lane from this terminal is blocked by sandbox restrictions rather than current source compile errors:
  - unit-test runner hit `testmanagerd` sandbox denial while trying to execute tests
  - UI-test lane additionally hit signing-identity access problems from this terminal session
- A direct `swiftc -typecheck` attempt from this terminal also hit a local cache permission issue under `~/.cache/clang`, so the successful wrapper build is currently the stronger compile proof.

Current environment blocker:
- This terminal session cannot currently access a valid codesigning identity:
  - `security find-identity -v -p codesigning`
  - result seen here: `0 valid identities found`
- Because of that, the parent thread cannot safely replace the already-permissioned `/Applications/Scrollapp.app` with a newly signed equivalent from the terminal alone.
- The installed `/Applications/Scrollapp.app` is still the older signed copy; the newest logic is confirmed in source and in the unsigned wrapper build output.

Most practical next runtime step:
- Run the latest source from the local wrapper project in Xcode or otherwise launch the newest built app path, then use the new menu diagnostics after one middle click to confirm whether activation now starts.
- If it still fails, the four live diagnostic lines will pinpoint the exact remaining stage.

Latest implementation pass on 2026-03-13:
- `Scrollapp/AutoscrollCore.swift`
  - classifier now starts for ancestor-contained `AXWebArea`, not only leaf/primary-role `AXWebArea`
  - fallback axes logic is now centralized in `AutoscrollTargetClassifier.fallbackAxes(...)`
- `Scrollapp/ScrollappApp.swift`
  - runtime diagnostics now include:
    - `Last Mouse Trigger`
    - `Activation Match`
    - `AX Hit-Test`
    - `Activation Decision`
  - activation attempts now record whether the click matched the configured trigger, whether AX hit-testing resolved roles, and whether the click started autoscroll or passed through
  - `preferredAxesFallback(for:)` now routes through the shared classifier fallback logic
- `ScrollappTests/AutoscrollCoreTests.swift`
  - added regression coverage for:
    - leaf content inside `AXWebArea`
    - `AXTextField` inside `AXWebArea`

Latest integration pass on 2026-03-13:
- App-layer runtime fixes now landed in `Scrollapp/ScrollappApp.swift`:
  - session motion origin now uses the actual activation click point rather than `NSEvent.mouseLocation`
  - AX metadata collection now reads actions and extra control metadata so generic Electron-style tab chrome can pass through via actionable detection
  - scroll delivery now prefers target-PID posting for native-style targets when frontmost PID still matches, with session-tap fallback otherwise
  - the anchored indicator is now smaller, neutral, static, and fixed at the click point
  - diagnostics still expose the same runtime block, with AX hit-test/actionable summaries and delivery mode updates
- Motion/feel tuning is present in `Scrollapp/AutoscrollCore.swift`:
  - much stronger early acceleration
  - higher cruise speed and cap
  - lower required mouse travel for useful speed
- Current verification is green from the wrapper project:
  - `xcodebuild -project /private/tmp/scrollapp-xcode/Scrollapp.xcodeproj -scheme Scrollapp -destination 'platform=macOS' -derivedDataPath /private/tmp/scrollapp-xcode/tmp/dd-main-final test`
    - result: `42` tests passed
  - `xcodebuild -project /private/tmp/scrollapp-xcode/Scrollapp.xcodeproj -scheme ScrollappUITests -destination 'platform=macOS' -derivedDataPath /private/tmp/scrollapp-xcode/tmp/dd-ui-final -test-timeouts-enabled YES -default-test-execution-time-allowance 20 -maximum-test-execution-time-allowance 30 test`
    - result: `2` UI smoke tests passed
- Installed app refresh completed:
  - copied verified build from `/private/tmp/scrollapp-xcode/tmp/dd-main-final/Build/Products/Debug/Scrollapp.app`
  - replaced `/Applications/Scrollapp.app`
  - relaunched `/Applications/Scrollapp.app`
  - codesign check confirms:
    - `Identifier=com.fromis9.scrollapp`
    - `Authority=Apple Development: bruce.quan.nguyen@gmail.com (2WF29X2V22)`
    - `TeamIdentifier=H9M8KNW35G`

Current likely remaining gap:
- terminal-side verification is fully green, but final accept/reject still depends on live user feel in real apps because OS-level middle-click autoscroll cannot be fully proven from automated smoke tests alone
- if the next live run still feels wrong, the most likely remaining work is feel-only tuning, not permissions/project/plumbing
    - fallback axes using ancestor `AXWebArea`
    - fallback axes avoiding text fields inside web areas

Latest verification after the classifier/diagnostics patch:
- wrapper project regenerated and listed successfully:
  - `SCROLLAPP_XCODE_LOCAL_DIR=/private/tmp/scrollapp-xcode ./scripts/open_local_xcode.sh --check --no-open`
- main suite:
  - `xcodebuild -project /private/tmp/scrollapp-xcode/Scrollapp.xcodeproj -scheme Scrollapp -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO test`
  - result: `29` tests passed
- UI smoke suite:
  - `xcodebuild -project /private/tmp/scrollapp-xcode/Scrollapp.xcodeproj -scheme ScrollappUITests -destination 'platform=macOS' -test-timeouts-enabled YES -default-test-execution-time-allowance 20 -maximum-test-execution-time-allowance 30 test`
  - result: `2` UI tests passed
- signed build:
  - `xcodebuild -project /private/tmp/scrollapp-xcode/Scrollapp.xcodeproj -scheme Scrollapp -configuration Debug -destination 'platform=macOS' -derivedDataPath /private/tmp/scrollapp-final-dd build`
  - result: build succeeded
- installed runtime app:
  - `/Applications/Scrollapp.app` replaced with the new signed build
  - current codesign identity still matches:
    - `Apple Development: bruce.quan.nguyen@gmail.com (2WF29X2V22)`
    - team `H9M8KNW35G`
  - current launched process:
    - `/Applications/Scrollapp.app/Contents/MacOS/Scrollapp`

Immediate live-runtime next step:
- Have the user middle-click once in a target area that should autoscroll, then read back these four menu lines:
  - `Last Mouse Trigger`
  - `Activation Match`
  - `AX Hit-Test`
  - `Activation Decision`
- Those values now tell us exactly whether the remaining issue is:
  - click not seen
  - trigger mismatch
  - AX hit-test failure
  - classifier/axes pass-through
  - or a deeper post-start scrolling/routing issue

Key files touched in the latest runtime-debugging phase:
- `Scrollapp/ScrollappApp.swift`
  - live permission/event-tap status lines
  - `Refresh Permissions`
- `Scrollapp/AutoscrollCore.swift`
  - pure fallback-axis helper so runtime and tests share the same ancestor-based start logic
- `ScrollappTests/AutoscrollCoreTests.swift`
  - regression tests for leaf content inside `AXWebArea` and fallback-axis behavior
- `project.yml`
  - persistent development team + automatic signing

Latest fix pass after compaction:
- `Scrollapp/AutoscrollCore.swift`
  - added `AutoscrollTargetClassifier.fallbackAxes(for:)`
  - ancestor `AXWebArea` now maps to `.both`
  - `AXTextField` still suppresses fallback even when nested inside a web area
- `Scrollapp/ScrollappApp.swift`
  - `preferredAxesFallback(for:)` now delegates to the pure classifier helper instead of a separate ad hoc runtime rule
  - AX hit-test status is richer and now includes axes/actionable hints
  - the menu already includes the last-activation diagnostics:
    - `Last Mouse Trigger`
    - `Activation Match`
    - `AX Hit-Test`
    - `Activation Decision`
- `ScrollappTests/AutoscrollCoreTests.swift`
  - added:
    - `classifierStartsForLeafContentInsideWebArea`
    - `classifierKeepsTextFieldInsideWebAreaUndetermined`
    - `fallbackAxesUseAncestorWebArea`
    - `fallbackAxesAvoidTextFieldsEvenInsideWebArea`

Latest verification after the fix pass:
- Wrapper refresh:
  - `SCROLLAPP_XCODE_LOCAL_DIR=/private/tmp/scrollapp-xcode ./scripts/open_local_xcode.sh --check --no-open`
    - current project path printed as `/tmp/scrollapp-xcode/Scrollapp.xcodeproj`
- Main scheme:
  - `xcodebuild -project /tmp/scrollapp-xcode/Scrollapp.xcodeproj -scheme Scrollapp -destination 'platform=macOS' -derivedDataPath /tmp/scrollapp-xcode/tmp/dd-main-fix-1773442733 CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO test`
    - result: `29` tests green
- UI scheme:
  - `xcodebuild -project /tmp/scrollapp-xcode/Scrollapp.xcodeproj -scheme ScrollappUITests -destination 'platform=macOS' -test-timeouts-enabled YES -default-test-execution-time-allowance 20 -maximum-test-execution-time-allowance 30 test`
    - result: `2` UI tests green
- Signed install:
  - built from `/tmp/scrollapp-xcode/Scrollapp.xcodeproj`
  - installed to `/Applications/Scrollapp.app`
  - signature verified:
    - `Identifier=com.fromis9.scrollapp`
    - `Authority=Apple Development: bruce.quan.nguyen@gmail.com (2WF29X2V22)`
    - `TeamIdentifier=H9M8KNW35G`

Latest post-start scroll-debug pass:
- `Scrollapp/ScrollappApp.swift`
  - added second-stage runtime diagnostics:
    - `Scroll Emission`
    - `Scroll Delivery`
    - `Stop Reason`
  - these now show:
    - current computed velocity
    - whether the timer is idle vs posting
    - whether the synthetic wheel was created and posted
    - why autoscroll stopped, if it stopped
  - synthetic wheel delivery is now explicitly reported as session-tap injection at the anchored location, with the captured target PID retained only as a hint / lifecycle check
- Fresh verification after the post-start pass:
  - `xcodebuild -project /private/tmp/scrollapp-xcode/Scrollapp.xcodeproj -scheme Scrollapp -destination 'platform=macOS' -derivedDataPath /private/tmp/scrollapp-xcode/tmp/dd-main-verify-3 CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO test`
    - result: `29` tests green
  - `xcodebuild -project /private/tmp/scrollapp-xcode/Scrollapp.xcodeproj -scheme ScrollappUITests -destination 'platform=macOS' -derivedDataPath /private/tmp/scrollapp-xcode/tmp/dd-ui-verify-3 -test-timeouts-enabled YES -default-test-execution-time-allowance 20 -maximum-test-execution-time-allowance 30 test`
    - result: `2` UI tests green
  - `xcodebuild -project /private/tmp/scrollapp-xcode/Scrollapp.xcodeproj -scheme Scrollapp -configuration Debug -destination 'platform=macOS' -derivedDataPath /private/tmp/scrollapp-xcode/tmp/dd-install-3 build`
    - result: `BUILD SUCCEEDED`
  - installed app refreshed at `/Applications/Scrollapp.app`
    - signed time: `2026-03-13 17:09:02 -0600`
    - process observed running after relaunch

Immediate next live check:
- Ask the user to middle click once on ordinary web/page content in the relaunched `/Applications/Scrollapp.app`, then report:
  - whether autoscroll now starts
  - if not, the seven diagnostics from the menu:
    - `Last Mouse Trigger`
    - `Activation Match`
    - `AX Hit-Test`
    - `Activation Decision`
    - `Scroll Emission`
    - `Scroll Delivery`
    - `Stop Reason`

Read This First After Compaction:
- This file is the canonical resume point for the current autoscroll job.
- Read the two related temp artifacts only if deeper context is needed.


Latest Windows-feel pass on 2026-03-13:
- `Scrollapp/ScrollappApp.swift`
  - removed the active-path cursor hiding / custom cursor swapping
  - added a stationary autoscroll overlay indicator anchored at the original click point
  - kept runtime diagnostics and scroll delivery behavior intact
- `Scrollapp/AutoscrollCore.swift`
  - replaced the harsher raw axis curve with a gentler eased ramp
  - preserves dead zone, inversion, sensitivity, and cap behavior
- `ScrollappTests/AutoscrollCoreTests.swift`
  - added smoothing tests for gentle start and monotonic distance growth

Latest verification after the Windows-feel pass:
- main suite:
  - `xcodebuild -project /private/tmp/scrollapp-xcode/Scrollapp.xcodeproj -scheme Scrollapp -destination 'platform=macOS' -derivedDataPath /private/tmp/scrollapp-xcode/tmp/dd-main-verify-4 CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO test`
  - result: `31` tests passed
- UI smoke suite:
  - `xcodebuild -project /private/tmp/scrollapp-xcode/Scrollapp.xcodeproj -scheme ScrollappUITests -destination 'platform=macOS' -derivedDataPath /private/tmp/scrollapp-xcode/tmp/dd-ui-verify-4 -test-timeouts-enabled YES -default-test-execution-time-allowance 20 -maximum-test-execution-time-allowance 30 test`
  - result: `2` tests passed
- signed install refreshed again:
  - built from `/private/tmp/scrollapp-xcode/tmp/dd-install-4/Build/Products/Debug/Scrollapp.app`
  - reinstalled to `/Applications/Scrollapp.app`

Latest live user feedback after the Windows-feel pass:
- The app works again at the basic functional level.
- Current remaining problems are feel/UX, not activation or permissions:
  - no momentum / no inertial feel
  - still too slow; user has to drag the mouse too far to scroll a little
  - the indicator arrows feel too busy and flickery as they switch on/off by direction
- User preference for the next pass:
  - keep the icon simple and static
  - do not animate or toggle arrow directions aggressively
  - prioritize stronger/faster scroll response and more natural momentum-like feel
- Additional live feedback after that:
  - behavior is intermittent even on the same page/element
  - one middle click can work, the next can fail with the icon only flashing briefly

Latest diagnostic/user-observed runtime state:
- When it works:
  - autoscroll starts functionally
  - remaining complaints are speed, momentum-like feel, and too-busy indicator visuals
- When it fails:
  - the icon can appear briefly and then disappear with no scrolling
  - this is currently treated as a regression/intermittency issue rather than an activation-permission issue

Most recent exploratory finding to preserve:
- Explorer `Meitner` found a likely regression risk in the new overlay path:
  - `orderFrontRegardless()` on the indicator panel may briefly make `Scrollapp` frontmost
  - that can trip the frontmost-app stop guard in `shouldStopAutoscroll(...)`
  - recommended smallest fix if the flash/disappear issue returns:
    - replace `orderFrontRegardless()` with `orderFront(nil)`
    - only add a stop-guard exemption for `Scrollapp` PID if needed after that
- Important nuance:
  - the user later reported that the app works again, so this is now a risk note rather than the current top blocker
  - after more live use, the user reported intermittent failures again, so this has moved back up as the leading likely cause

Recommended next engineering pass after compaction:
1. Fix the likely intermittent overlay regression in `Scrollapp/ScrollappApp.swift`
   - replace `orderFrontRegardless()` with `orderFront(nil)` for the indicator panel
   - if needed, make the frontmost-app stop guard tolerate Scrollapp’s own passive indicator presence
2. Simplify the overlay indicator in `Scrollapp/ScrollappApp.swift`
   - remove direction-dependent arrow toggling
   - keep one static autoscroll anchor icon
3. Increase responsiveness / momentum feel in `Scrollapp/AutoscrollCore.swift`
   - raise near-anchor output so scrolling starts earlier with less pointer travel
   - if still needed, add stronger temporal smoothing/ramping in app state
   - keep the dead-zone semantics but reduce the “drag the mouse too much” feeling
4. Rebuild, reinstall, and re-run a live feel check
   - success condition is now UX-focused:
     - starts reliably
     - stationary static anchor icon
     - no flicker/jiggle
     - stronger, more natural scrolling response


Resume note at 2026-03-13T23:30-06:00:
- Parent thread resumed from `docs/jobs/archive/2026-03-13-autoscroll.md` before edits.
- Current remaining issues to close: intermittent same-element failure, static indicator preference, low speed / weak momentum feel.
- Hot spots identified in source:
  - `Scrollapp/ScrollappApp.swift`: `shouldStopAutoscroll(session:)`, `updateIndicator(for:)`, overlay `orderFrontRegardless()`, and session wheel delivery.
  - `Scrollapp/AutoscrollCore.swift`: current eased ramp is still too conservative for the user.
- Attempted subagent fan-out through local `codex exec`, but the CLI is currently panicking during startup (`system-configuration` / OTEL init), so CLI-based worker delegation is blocked in this session.
- Parent thread will continue sponsor-style with minimal centralized integration and will use built-in subagent path if available; otherwise it will proceed with the smallest direct fixes needed to finish.

Latest finish-pass on 2026-03-13 (evening):
- Parent thread resumed from this file in subagent-manager mode and delegated three lanes:
  - explorer reliability audit
  - worker motion tuning in `Scrollapp/AutoscrollCore.swift` + `ScrollappTests/AutoscrollCoreTests.swift`
  - worker UI/runtime polish in `Scrollapp/ScrollappApp.swift`
- Integrated final runtime fixes now in source:
  - static, non-flickery anchor indicator remains in `Scrollapp/ScrollappApp.swift`
  - overlay panel stays non-activating and uses `orderFront(nil)` instead of force-fronting
  - autoscroll no longer stops on a single frontmost-app mismatch; it now requires consecutive mismatches before stopping
  - app-layer velocity smoothing is now applied so scroll output ramps toward the target velocity and decays more naturally when recentering
- `AutoscrollSession` now tracks `frontmostMismatchCount`.
- `AutoscrollBehavior` now exposes `smoothedVelocity(previous:target:)` with focused regression tests.
- Updated test expectations to match the intentionally faster pickup near the dead zone.

Latest verification on 2026-03-13:
- Main suite:
  - `xcodebuild -project /private/tmp/scrollapp-xcode/Scrollapp.xcodeproj -scheme Scrollapp -destination 'platform=macOS' -derivedDataPath /private/tmp/scrollapp-xcode/tmp/dd-main-final2 test`
  - result: `35` tests passed
  - xcresult: `/private/tmp/scrollapp-xcode/tmp/dd-main-final2/Logs/Test/Test-Scrollapp-2026.03.13_17-35-33--0600.xcresult`
- UI smoke suite:
  - `xcodebuild -project /private/tmp/scrollapp-xcode/Scrollapp.xcodeproj -scheme ScrollappUITests -destination 'platform=macOS' -derivedDataPath /private/tmp/scrollapp-xcode/tmp/dd-ui-final -test-timeouts-enabled YES -default-test-execution-time-allowance 20 -maximum-test-execution-time-allowance 30 test`
  - result: `2` UI tests passed
  - xcresult: `/private/tmp/scrollapp-xcode/tmp/dd-ui-final/Logs/Test/Test-ScrollappUITests-2026.03.13_17-34-56--0600.xcresult`
- Installed app refreshed from verified build:
  - source: `/private/tmp/scrollapp-xcode/tmp/dd-main-final2/Build/Products/Debug/Scrollapp.app`
  - installed path: `/Applications/Scrollapp.app`

Immediate next step after compaction:
- live-feel test the freshly installed `/Applications/Scrollapp.app`
- specifically verify:
  - activation starts reliably every time on the same element
  - indicator stays static and no longer flickers
  - scrolling feels materially faster / less draggy
  - any remaining issue is now a runtime-feel issue, not project/signing/permission plumbing

Read This First After Compaction:
- Open the Scrollapp menu and use the diagnostics if live behavior still misbehaves.
- The current code and test state are green; the next iteration should be driven by the user’s feel check on `/Applications/Scrollapp.app`, not by more blind refactors.

Right-click + cursor-anchor regression fix on 2026-03-13 (late evening):
- User reported two fresh runtime issues:
  - right click no longer worked
  - autoscroll icon should stay anchored while the real cursor moves freely
- Parent thread resumed from this file and used available subagents for targeted read-only audits.
- Root cause found for right click:
  - while autoscroll was active, `handleStopClick(...)` swallowed right-click exit the same way it swallowed left-click exit
  - this prevented the right-click event pair from reaching the target app
- Fixes now in source:
  - `AutoscrollStopClickPolicy.shouldSwallow(buttonNumber:)` added in `Scrollapp/AutoscrollCore.swift`
  - left click still exits and is swallowed
  - right click now exits autoscroll but passes through normally to the target app
  - indicator anchoring now uses `session.anchorEventPoint` instead of `session.movementOrigin` in `Scrollapp/ScrollappApp.swift`
- Cursor audit result:
  - no active `NSCursor.hide()` / cursor warp logic remains in the code path
  - overlay remains non-interactive via `ignoresMouseEvents = true`

Latest verification after the right-click fix:
- Main suite:
  - `xcodebuild -project /private/tmp/scrollapp-xcode/Scrollapp.xcodeproj -scheme Scrollapp -destination 'platform=macOS' -derivedDataPath /private/tmp/scrollapp-xcode/tmp/dd-main-rcfix test`
  - result: `37` tests passed
  - xcresult: `/private/tmp/scrollapp-xcode/tmp/dd-main-rcfix/Logs/Test/Test-Scrollapp-2026.03.13_17-39-20--0600.xcresult`
- Pending/next in the live loop:
  - refresh installed `/Applications/Scrollapp.app` from the verified build
  - ask the user to retest:
    - right click during autoscroll
    - cursor freedom with anchored icon

- UI smoke suite also revalidated after the right-click fix:
  - `xcodebuild -project /private/tmp/scrollapp-xcode/Scrollapp.xcodeproj -scheme ScrollappUITests -destination 'platform=macOS' -derivedDataPath /private/tmp/scrollapp-xcode/tmp/dd-ui-rcfix -test-timeouts-enabled YES -default-test-execution-time-allowance 20 -maximum-test-execution-time-allowance 30 test`
  - result: `2` UI tests passed
  - xcresult: `/private/tmp/scrollapp-xcode/tmp/dd-ui-rcfix/Logs/Test/Test-ScrollappUITests-2026.03.13_17-39-58--0600.xcresult`
- Installed app refreshed again after the right-click fix:
  - source: `/private/tmp/scrollapp-xcode/tmp/dd-main-rcfix/Build/Products/Debug/Scrollapp.app`
  - installed path: `/Applications/Scrollapp.app`
- Immediate live check now needed from the user:
  - right click should work again while also ending autoscroll
  - icon should stay at the clicked anchor point while the real cursor remains free to move

Latest user feedback to preserve before compaction:
- The cursor still feels “sucked” or trapped.
- User reports the cursor is not moving freely and appears to keep snapping back to the autoscroll icon.
- This means there is still a live runtime bug in the pointer/control path even though explicit cursor hide logic is gone from source.
- User also reports that speed differentiation is still not right:
  - autoscroll should vary clearly based on how far the cursor is dragged away from the icon
  - the current behavior still does not feel like proper Windows autoscroll distance-based control
- User wants a more complete behavior-driven parity pass rather than isolated tweaks.
- Immediate instruction from the user for this turn:
  - write all of this into the temp status file before context compaction

Windows-style autoscroll behavior checklist to preserve for the next pass:
- The anchor icon stays fixed at the original middle-click point.
- The real mouse cursor remains visible and moves freely; it must never feel snapped back to the icon.
- Scroll speed varies continuously with distance from the anchor.
- Small movement outside the dead zone should scroll slowly.
- Larger movement should accelerate clearly.
- Diagonal movement should combine horizontal and vertical scrolling naturally.
- Re-centering toward the anchor should slow scrolling back down smoothly.
- The active autoscroll target stays latched to the clicked element, not whatever is under the cursor later.
- Middle-click actions on actionable chrome should pass through instead of starting autoscroll:
  - tabs
  - tab close affordances
  - links
  - buttons
  - other meaningful middle-click behaviors in apps like Obsidian/Electron
- Left click should exit autoscroll with the current swallow policy.
- Right click should not be broken by autoscroll and should pass through normally after ending autoscroll when appropriate.
- The anchor icon should be visually subtle:
  - monochrome or neutral, not blue
  - smaller than the current size
  - closer to modern macOS “liquid glass” visual language

Most likely high-priority next debugging targets after compaction:
- Find the real source of the “cursor snapping back” symptom. Current source audit says there is no active cursor hide/warp logic, so this may be caused by:
  - wrong point source used in velocity/control calculations
  - an interaction between event tap injection and `NSEvent.mouseLocation`
  - overlay/session feedback loop that makes control appear pinned
- Re-audit the pointer/control path around:
  - `performScroll()`
  - `AutoscrollBehavior.velocity(...)`
  - `startAutoScroll(with:)`
  - `classifyActivation(at:)`
  - any use of `NSEvent.mouseLocation`
- Re-audit actionable-target pass-through for Electron/Obsidian tab chrome, where AX roles may be too weak for the current classifier.

Read This First After Compaction:
- The most recent user-visible blockers are now:
  - cursor still feels trapped/snapped to the icon
  - speed-distance behavior still does not feel like Windows autoscroll
  - actionable middle-click behavior in apps like Obsidian still needs broader pass-through handling
- Resume from this file before any more code changes.
