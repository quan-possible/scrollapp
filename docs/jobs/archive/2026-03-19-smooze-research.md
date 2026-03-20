# Smooze Auto-Scroll Reverse-Engineering Research

Started: 2026-03-19
Status: completed

## Objective

This document is intentionally narrow.

It answers one question only:

How should we reverse engineer and later replicate **Smooze's auto-scroll behavior** in Scrollapp, without implementing anything yet and without copying proprietary code?

This document does **not** cover:
- animated wheel scrolling in general
- grab / drag / throw
- gestures
- button remapping
- cursor tuning

## Scope and Guardrails

This pass is research only.

It does:
- gather public Smooze evidence relevant to auto-scroll
- inspect the installed app's safe-to-observe auto-scroll settings and strings
- derive the most likely auto-scroll behavior model
- propose a black-box replication plan for Scrollapp

It does **not**:
- implement Smooze-like auto-scroll in Scrollapp
- decompile or copy proprietary code
- treat uncertain inference as confirmed fact

## Evidence Base

### Official public sources

- Product page: <https://smooze.co/>
- Help / docs page: <https://smooze.co/docs.html>
- Update feed / changelog: <https://smooze.co/pro/updates/update.xml>

### Local installed-app evidence

Observed on this machine on 2026-03-19:
- app bundle: `/Applications/Smooze Pro.app`
- version:
  - `CFBundleShortVersionString = 2.2.7`
  - `CFBundleVersion = 785`
- bundle id:
  - `co.smoozepro.macos`

Relevant local evidence files:
- `/Applications/Smooze Pro.app/Contents/Resources/Base.lproj/Localizable.strings`
- `~/Library/Preferences/co.smoozepro.macos.plist`

### Auto-scroll-relevant local settings observed

From `~/Library/Preferences/co.smoozepro.macos.plist` under:

`displaysScroll -> "0-0-0" -> autoApps -> com.global -> autoSettings`

Observed values:

```json
{
  "autoAccelNumber": 12.818683,
  "isAnimateRelease": true,
  "isHoldToActivate": false,
  "isOverLinkActAsButton": true,
  "isReverseAutoScrollHorizontal": false,
  "isReverseAutoScrollVertical": false,
  "isSmartAutoScroll": true,
  "releaseDuration": 1,
  "superSlowDownNumber": 0
}
```

These settings are some of the strongest direct evidence in this document because they expose the app's own configuration vocabulary.

## What Smooze Clearly Exposes About Auto-Scroll

This section separates **direct evidence** from **inference**.

## Direct evidence

### 1. Auto-scroll is a first-class feature, not a side effect

Official product page:
- advertises `Auto Scroll`
- describes it as:
  - "Auto scroll anywhere on the screen"
  - "hands free"
  - "with buttery smooth animations"

Localized help text:
- `autoOutlt` says:
  - "Click a selected mouse button once to auto scroll anywhere on the screen"

**What this means**
- Smooze treats auto-scroll as its own mode.
- The advertised primary trigger is a selected mouse button.
- The default user-facing model is toggle-like activation, not just drag-to-scroll.

### 2. Speed depends on distance from an anchor point

Official docs:
- `Auto Scroll Acceleration`
  - "Increase to scroll faster while moving away from the anchor point."

Localized help text:
- `autoSpeed`
  - "Increase to scroll faster while moving away from the anchor point."

**What this means**
- There is definitely an anchor point.
- Pointer displacement from that anchor controls velocity.
- The exposed user control changes the growth rate of speed as distance increases.

### 3. Release can animate instead of stopping instantly

Official docs:
- `Animate Release`
- `Release Duration`

Localized help text:
- `autoRelease`
  - stopping can be instant when disabled
  - when enabled, release is animated "like a trackpad or an iPhone"
  - release speed depends on current scroll speed and the release-duration setting
- `autoReleaseDuration`
  - larger means smoother / longer release

Observed settings:
- `isAnimateRelease = true`
- `releaseDuration = 1`

**What this means**
- Auto-scroll has a separate release phase, not just an on/off stop.
- That release phase depends on current runtime velocity.
- The product is intentionally imitating inertial momentum, not a constant-timer fade.

### 4. There is a hold mode and a non-hold mode

Localized help text:
- `holdToActivate`
  - "Hold the Auto Scroll button in order to scroll."

Observed settings:
- `isHoldToActivate = false`

**What this means**
- Smooze supports at least two activation semantics:
  - toggle / click mode
  - hold-to-scroll mode

### 5. There is a "smart auto-scroll" classifier

Localized help text:
- `smartScrollOutlt`
  - Smooze detects whether the area under the mouse is scrollable
  - if scrollable, it activates auto-scroll
  - if not scrollable, it triggers the normal button action
  - example:
    - middle-click in Chrome web content starts auto-scroll
    - middle-click in a tab area closes the tab instead

Observed settings:
- `isSmartAutoScroll = true`

Update feed:
- `2.0.9` says: "Smart Auto Scroll is now smarter."

**What this means**
- Smart auto-scroll is not marketing fluff. It is a real behavior mode with its own logic.
- Smooze distinguishes between scrollable content and actionable UI like tabs.
- The decision rule matters a lot to the product feel.

### 6. Link behavior is configurable separately from general smart scroll

Localized help text:
- `overLinkActAsButton`
  - if enabled, while over a link, the default button action is invoked instead of starting auto-scroll
  - if disabled, auto-scroll can start regardless of what is under the cursor

Observed settings:
- `isOverLinkActAsButton = true`

**What this means**
- Link pass-through is a special case, important enough to merit its own toggle.
- Smooze likely considers links an actionable subtype that users often want to preserve.

### 7. Auto-scroll supports precision slowdown

Localized help text:
- `superSlowDown`
  - "Increase this in order to move really slow. Higher is slower."

Observed settings:
- `superSlowDownNumber = 0`

**What this means**
- Smooze exposes a low-speed precision control, separate from the main acceleration control.
- This likely affects the near-anchor region or low-velocity ramp.

### 8. Auto-scroll direction can be reversed per axis

Observed settings:
- `isReverseAutoScrollVertical`
- `isReverseAutoScrollHorizontal`

Localized help text and docs clearly mention directional reversal in the broader scrolling surface, and the auto-scroll settings confirm dedicated per-axis auto-scroll flags.

**What this means**
- Auto-scroll is not limited to vertical output.
- The system is likely capable of bidirectional or dual-axis auto-scroll, even if vertical is the common case.

### 9. Auto-scroll is configured per app per display

Observed preferences structure:
- `displaysScroll`
  - display-scoped object
  - under each display:
    - `autoApps`
      - keyed by app bundle id

**What this means**
- Auto-scroll settings are resolved using both:
  - current display
  - current app

This is a big product behavior clue because it means "exact replication" cannot be just one global auto-scroll profile if we want to match Smooze closely.

## Strong Inferences About Auto-Scroll

These points are not directly stated by Smooze, but they are the best current reading of the evidence.

### 1. Smart auto-scroll probably uses target classification, not just geometry

Evidence:
- link-specific pass-through toggle
- Chrome example distinguishing web area vs tab area
- update note that "Smart Auto Scroll is now smarter"

Inference:
- Smooze is probably not just checking "does this window look scrollable."
- It likely classifies the UI surface under the pointer into buckets such as:
  - scrollable content
  - tab strip / control / clickable UI
  - link-like actionable content

### 2. The classifier probably uses Accessibility or similar UI metadata

Evidence outside auto-scroll alone:
- local binary strings contain:
  - `AXUIElement`
  - `AXScrollArea`
  - `AXList`
  - `AXTabGroup`
  - `AccessibilityViewController`

Inference:
- The simplest plausible way to distinguish web content from tab bars and links on macOS is some form of accessibility-driven hit testing or ancestry inspection.
- This fits the behavior described by the product text unusually well.

### 3. Release animation likely reuses the current measured scroll velocity

Evidence:
- localized help explicitly says release speed depends on speed "at the time of the release"

Inference:
- On release, Smooze probably snapshots the current auto-scroll velocity and runs a deceleration curve from that velocity, rather than restarting from a fixed preset.

### 4. The "super slow down" control likely shapes the low-distance regime

Evidence:
- it exists in auto settings
- it is described as "move really slow"
- it is separate from the main acceleration slider

Inference:
- This is probably not just another overall multiplier.
- It is more likely a near-anchor precision control or a curve shaper that flattens movement close to the anchor.

### 5. Horizontal auto-scroll probably exists but may be less emphasized

Evidence:
- dedicated horizontal reverse setting exists

Inference:
- The auto-scroll output model is likely 2D, even if most users experience it as primarily vertical.

## Best Current Model Of Smooze Auto-Scroll

If we had to model Smooze auto-scroll today as a black-box state machine, this is the most plausible version.

### State machine

1. `idle`
2. `activation input received`
3. `classify target under cursor`
4. either:
   - `pass through native button action`
   - or `enter auto-scroll mode`
5. `anchor point established`
6. `pointer displacement -> target velocity`
7. `apply slowdown / acceleration shaping`
8. `emit scrolling continuously while mode remains active`
9. on release or stop:
   - `stop immediately`
   - or `enter release animation`
10. `decelerate to zero`
11. `return to idle`

### Classifier branch

The classifier likely behaves roughly like this:

1. If smart mode is disabled:
   - start auto-scroll regardless of target type
2. If smart mode is enabled:
   - if area under cursor is scrollable:
     - start auto-scroll
   - if area under cursor is not scrollable:
     - invoke native button action
3. If the area is specifically link-like and `over link act as button` is enabled:
   - invoke native button action instead of auto-scroll

### Velocity model

The most likely shape is:

1. anchor is fixed at activation
2. pointer distance from anchor produces a raw target speed
3. `autoAccelNumber` controls how aggressively speed ramps with distance
4. `superSlowDownNumber` reshapes the low-speed region for precision
5. vertical and horizontal directions are derived from relative pointer position and axis settings

### Stop model

The stop path probably depends on mode:

- hold mode:
  - releasing the button stops or begins release animation
- toggle mode:
  - another stop action, button action, or explicit cancel ends the mode

### Release model

Most plausible release path:

1. capture current velocity
2. apply an inertial decay curve
3. scale decay by `releaseDuration`
4. stop at zero

## What "Replicate The Exact Behaviors" Means In Practice

If we want to replicate Smooze's auto-scroll behavior faithfully, the work is not just:
- middle click -> scroll

It is at least these nine behavior contracts:

1. activation can be toggle or hold
2. an anchor point is fixed on activation
3. pointer distance from anchor controls speed
4. speed ramps according to a configurable acceleration control
5. the near-anchor region can be tuned for very slow precision movement
6. smart classification decides between starting auto-scroll and preserving native action
7. links can be treated specially
8. stopping can trigger inertial release instead of an abrupt stop
9. effective behavior can vary by app and display

That is the behavior surface we should think of as "the exact thing," not only the visible scrolling itself.

## How To Reverse Engineer Only The Auto-Scroll Behavior Safely

This is the recommended black-box process for the next research pass.

### Phase 1. Build an auto-scroll observation matrix

For each scenario, record:
- app
- display
- target surface
- activation input
- whether native button action happened
- whether auto-scroll started
- anchor location
- direction behavior
- low-speed controllability
- release behavior

Minimum scenario set:
- browser web content
- browser tab strip
- browser link inside web content
- text editor body
- sidebar list
- Finder list/grid
- app with nested scroll regions

### Phase 2. Perturb one auto-scroll setting at a time

Change only:
- smart auto-scroll
- over-link-as-button
- hold-to-activate
- animate release
- release duration
- auto-scroll acceleration
- super slow down
- reverse vertical
- reverse horizontal

For each change, observe:
- startup decision
- anchor semantics
- velocity change
- release change

### Phase 3. Measure the runtime, not just the feel

Use our own external instrumentation around Smooze:
- CGEvent capture harness
- NSScrollView external fixture window
- high-frame-rate screen recording
- pointer position logging
- AX hit-test probes at activation points

Questions to answer:
- does Smooze keep scrolling attached to the original target after the cursor moves away?
- does it require the pointer to remain inside the original owner?
- how does it behave over nested scroll owners?
- what exactly distinguishes link pass-through from general actionable pass-through?
- what is the shape of release decay relative to current velocity?

### Phase 4. Reconstruct the exact decision policy

The most important reverse-engineering output is not code.

It is a plain-language policy like:

"When smart mode is on and the middle button is pressed:
- if the AX hit target is a scrollable content owner, start auto-scroll
- if the hit target is a tab/control/actionable UI, preserve native middle-click behavior
- if the hit target is link-like and the link-pass-through toggle is on, preserve native action
- otherwise start auto-scroll"

That policy is the real thing to replicate.

## Recommended Scrollapp Replication Plan For Auto-Scroll Only

This section is still design only. No implementation is proposed here.

### 1. Keep the current core/runtime split

Do not collapse Scrollapp into one giant controller.

Keep:
- pure mode and velocity logic in `AutoscrollCore.swift`
- AX, event tap, and delivery logic in `ScrollappApp.swift`

That is already the right foundation for this problem.

### 2. Treat "smart auto-scroll" as a first-class policy layer

Do not bury smart pass-through inside incidental heuristics.

Create an explicit policy surface for:
- smart mode on/off
- link pass-through on/off
- hold mode on/off
- release animation on/off
- release duration
- acceleration
- slow-zone / precision tuning
- reverse vertical / horizontal

### 3. Model auto-scroll as a 3-part system

To get close to Smooze, Scrollapp's auto-scroll should be thought of as:

1. **activation classifier**
   - should this click start auto-scroll or preserve native action?
2. **velocity engine**
   - how does displacement from anchor become scroll velocity?
3. **stop / release engine**
   - how does the mode end and how does momentum decay?

If those three parts are separated cleanly, replication gets much easier.

### 4. Add app/display scoping later, not first

Smooze clearly supports per-app per-display auto-scroll settings, but Scrollapp does not need to start there.

Recommended order:
1. match global behavior first
2. validate classifier and release feel
3. only then add:
   - per-app overrides
   - per-display overrides

### 5. Treat the Chrome example as a required acceptance test

Smooze gives one especially important concrete example:

- middle-click in a Chrome web area -> start auto-scroll
- middle-click in a Chrome tab area -> preserve tab-close behavior

If Scrollapp eventually wants Smooze-like auto-scroll, this should become one of the canonical acceptance tests.

## Auto-Scroll Features Scrollapp Most Likely Needs To Match

If we strip the target down to only the highest-value Smooze auto-scroll behaviors, the shortlist is:

1. smart pass-through on actionable non-scrollable UI
2. separate link pass-through option
3. toggle vs hold activation
4. anchor-based distance-to-speed mapping
5. precise low-speed control near the anchor
6. release animation tied to current velocity
7. optional horizontal handling
8. eventual per-app and per-display overrides

## Open Questions

These are the main auto-scroll-specific questions that remain unresolved after this document.

1. Does Smooze pause when the pointer leaves the original owner, or does it keep delivering to the latched target?
2. How exactly does smart mode classify links, tabs, and nested scrollable regions?
3. Is the low-speed tuning implemented as a dead-zone reshaper, a nonlinear response curve, or a post-scale clamp?
4. What decay curve is used for animated release?
5. How much of the target decision depends on AX metadata versus app-specific heuristics?
6. Does horizontal auto-scroll engage automatically from 2D displacement or only in some contexts?

## Bottom Line

The right way to think about Smooze auto-scroll is:

not just "middle-click to start scrolling,"

but:

"a target-aware anchored scrolling mode with configurable activation semantics, configurable pass-through rules, configurable velocity shaping, and optional inertial release."

That is the behavior we would need to replicate if the goal is to match Smooze closely.

## Verification

Checks used to build this document:
- official product page retrieval
- official docs page retrieval
- official update feed retrieval
- installed app localized-string inspection
- installed app user-defaults inspection for `autoSettings`

No correctness-affecting issues remain for this document. The remaining uncertainty is explicitly listed as open questions rather than being stated as fact.
