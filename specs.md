# Scrollapp Autoscroll Spec

Last updated: 2026-03-15

## Goal

Replicate Windows-style middle-click autoscroll on macOS as closely as practical for browsers, Electron apps, and native scroll views.

The app should:
- latch autoscroll to the element that was middle-clicked
- preserve normal middle-click behavior on actionable UI
- keep the real cursor free to move
- use a small anchored indicator at the click point
- scale speed clearly with distance from the anchor
- feel smooth and responsive instead of draggy

## Core Behavior

### 1. Activation

- Default activation is `Middle Click`, meaning mouse button `2` with no required modifier.
- Modifier-based activation methods must respect the exact configured modifier set.
- `Double Middle Click` must require:
  - the second click within the system double-click interval
  - the second click within the autoscroll dead zone
- A click that does not match the configured activation method must pass through untouched.

### 2. Start Conditions

- Autoscroll should start by default on non-interactive content.
- Actionable UI must win over autoscroll.
- If the target is ambiguous, the default should be autoscroll unless there is strong evidence that the click is meant to trigger an interaction.
- If the clicked area cannot actually scroll, autoscroll should not start.
- When several scroll containers are nested, the nearest real scroll owner should win.

Strong pass-through signals:
- links
- buttons
- tabs
- close buttons
- toolbar controls
- menu items
- compact text input controls such as search fields, address bars, form inputs, and other obvious input chrome
- generic controls that expose actionable metadata such as `AXPress`, `tab`, `close`, `button`, `link`, or similar chrome semantics
- nearby actionable or linked ancestors that strongly suggest the click is on UI chrome rather than content

Strong autoscroll signals:
- explicit horizontal or vertical scrollbar metadata
- content ancestry such as `AXWebArea`
- known content or container roles such as `AXBrowser`, `AXList`, `AXOutline`, `AXTable`, `AXScrollArea`
- large editor-like text surfaces such as code editors, document editors, terminal scrollback, rich-text editors, and chat/history panes
- generic non-interactive surfaces that do not present strong pass-through signals

### 3. Target Latching

- The autoscroll session latches to the original activation point.
- The autoscroll session must stay bound to the original target owner chosen at activation.
- Moving the cursor over another scrollable area, another pane, or another app must not retarget the session.
- Moving the cursor to another monitor or Space-visible window must not retarget the session.
- After activation, pointer position controls only speed and direction. It must not trigger re-hit-testing or target reclassification.
- If the original target owner becomes invalid, closes, or can no longer receive scroll input, the session should stop rather than retarget itself.
- If the original view is replaced by navigation, tab switch, editor replacement, or a recreated pane, the session should stop rather than follow the replacement implicitly.

### 4. Session Modes

- `initial`: middle button is down and the cursor is still within the dead zone
- `holding`: middle button is still down and the cursor has crossed the dead zone
- `toggled`: middle button has been released without crossing the dead zone
- `inactive`: no autoscroll session

Rules:
- middle down enters `initial`
- leaving the dead zone while the button is held enters `holding`
- releasing in `initial` enters `toggled`
- releasing in `holding` stops
- single middle-click activation must reliably enter `toggled`; the user should not have to keep holding the middle button for normal autoscroll use

### 5. Cursor And Indicator

- The real cursor must remain visible and free to move.
- The app must never warp or snap the cursor back to the anchor.
- The app must never make the cursor feel visually or behaviorally trapped in place.
- The anchor indicator must stay fixed at the original activation point.
- The indicator must ignore mouse events.
- The indicator should be:
  - monochrome or neutral
  - visually subtle
  - roughly one-half to one-third of the previous size
  - static rather than flickering directional arrows
  - compatible with a modern macOS liquid-glass look

### 6. Motion And Feel

- The dead zone target is `15 px`.
- While the pointer remains inside the dead zone, autoscroll should stay armed but idle.
- Speed must increase continuously with distance from the anchor.
- Small movement just outside the dead zone should scroll slowly but immediately.
- Medium movement should produce a clearly faster cruise speed.
- Far movement should accelerate further up to a capped maximum speed.
- Re-centering must slow smoothly back to zero.
- Returning to the dead zone should settle the session cleanly back to zero scroll.
- Diagonal movement must combine axes naturally.
- The feel should be smooth and responsive, not like dragging a scrollbar.
- Smoothing should reduce jitter without making initial motion sluggish.

### 7. Axes

- Vertical-only targets should scroll vertically only.
- Horizontal-only targets should scroll horizontally only.
- Two-axis targets should support diagonal motion.
- Unknown generic content should default to vertical scrolling.
- Fallback axis inference should stay simple:
  - preserve explicit AX-reported axes when available
  - use both axes for clear two-axis content such as `AXWebArea`
  - otherwise default to vertical only

### 8. Modifier Forwarding

- While autoscroll is active, live modifier state must be forwarded to synthetic wheel events.
- Holding `Command` during autoscroll should allow host apps to interpret the scroll as zoom when they support that behavior.

### 9. Stop Behavior

- Left click stops autoscroll and is swallowed once.
- Right click stops autoscroll but should still perform its native right-click action.
- External wheel input stops autoscroll.
- `Esc` stops autoscroll.
- Triggering activation again while autoscroll is active stops or replaces the current session.
- App switching or window focus takeover should stop autoscroll rather than leaving a stale session running in the background.
- Menus, popovers, modal dialogs, and other takeover UI on top of the original target owner should stop autoscroll.
- If the original target owner disappears, closes, or becomes invalid, autoscroll stops.
- Hovering another window, pane, tab, or app must never redirect the session.

### 10. Diagnostics

The menu must expose:
- `Accessibility`
- `Input Monitoring`
- `Event Posting`
- `Event Tap`
- `Last Mouse Trigger`
- `Activation Match`
- `AX Hit-Test`
- `Activation Decision`
- `Scroll Emission`
- `Scroll Delivery`
- `Stop Reason`

This diagnostics block is part of the product until behavior is stable.

## Acceptance Criteria

### A. Content Autoscroll

- Middle-clicking plain page content starts autoscroll.
- Middle-clicking plain generic content outside `AXWebArea` should still start autoscroll unless the target is strongly interactive.
- Middle-clicking truly non-scrollable dead content should not create a useless autoscroll session.
- The indicator appears at the click point and stays there.
- The cursor remains free to move.
- Scrolling speed increases with cursor distance from the indicator.
- A single middle click keeps autoscroll running after release unless the activation genuinely entered hold mode.
- After activation, moving the cursor over another app or pane must not cause that other surface to start scrolling.

### B. Actionable Middle Click Pass-Through

- Middle-clicking a link performs the app’s native middle-click link behavior.
- Middle-clicking a tab or tab-close affordance performs the app’s native behavior.
- Middle-clicking a button or toolbar control does not start autoscroll.
- Middle-clicking a compact input control such as a search field or address bar does not start autoscroll.

### C. Editor-Like Text Surfaces

- Middle-clicking a large editor-like text surface should start autoscroll when it behaves as document content.
- This includes targets such as code editors, document editors, terminal scrollback/content views, and chat/history panes.
- These surfaces should not be excluded just because they expose text-related accessibility roles.

### D. Stop Semantics

- Left click exits and does not send an extra click through.
- Right click exits and still produces a context menu or native right-click action.
- External scroll input exits.
- `Esc` exits.
- Switching away from the original app/window or replacing the original target view exits.

### E. Feel

- The app should not require excessive cursor travel to get useful speed.
- The initial response should feel immediate just outside the dead zone.
- The indicator should not flicker or pulse in a distracting way.

## Manual Verification Matrix

Run these checks before calling the job done:

1. `manual/autoscroll-fixture.html`
- page body
- nested scroll container
- horizontal strip
- link
- button
- compact text field

2. Safari
- plain page content
- link
- nested scroll region
- start in one tab, then switch tabs; the old session should stop

3. Chrome or another Chromium browser
- plain page content
- nested scroll region
- tab/link behavior
- clickable card targets such as X/Twitter posts that should open in a new tab on middle click
- start in one tab, then move across tabs or switch tabs; the original session should not retarget and should stop if the original tab view is replaced

4. Electron app such as Obsidian
- editor/content area
- tab close via middle click
- tab strip non-content chrome
- activate in one pane, then move the pointer over another pane without disengaging autoscroll; the original pane should remain the owner
- activate in one editor pane, then open takeover UI such as a command palette or modal; autoscroll should stop

5. Native macOS apps
- Finder list
- Xcode editor or navigator
- Terminal content area, then move the pointer over another app; Terminal should remain the owner until stop
- Terminal content area, then open a menu or switch away; the session should stop

## Implementation Targets

- `Scrollapp/AutoscrollCore.swift`
  - physics
  - smoothing
  - mode transitions
  - classifier heuristics
  - stop-click policy
- `Scrollapp/ScrollappApp.swift`
  - event tap handling
  - AX metadata extraction
  - session construction and latching
  - synthetic event delivery
  - indicator rendering and placement
  - diagnostics
- `ScrollappTests/AutoscrollCoreTests.swift`
  - classifier regressions
  - speed curve regressions
  - stop-click policy regressions

## Current Known Gaps To Close

- actionable middle-click pass-through is still too weak for Electron-style tab chrome
- motion origin still needs to line up perfectly with the actual activation click
- scroll delivery is still not reliably constrained to the original latched owner
- speed/feel still needs tuning toward a faster, smoother Windows-like response
- the indicator still needs a smaller monochrome redesign

## Latest Live Requirements

- The cursor must move freely during autoscroll; it must not stay stuck in one place.
- Toggled autoscroll must work from a normal single middle click; it must not require holding the middle button.
- Once a session starts, the original target owner must remain fixed until stop; hover alone must never retarget scrolling.
- The session must not survive obvious ownership changes such as tab replacement, modal takeover, app switching, or target invalidation.
- The next verification pass should include direct browser/runtime interaction, not only source-level and smoke-test checks.
