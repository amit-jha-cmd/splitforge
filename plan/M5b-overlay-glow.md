# M5 (increment b) — replace the center HUD with a blue glow on the persistent overlay

> User request (2026-07-04): the transient center HUD is intrusive over other apps. Remove it. Instead,
> on a layer change, briefly **glow the always-visible corner overlay blue** (fade out). Follows `../AGENTS.md`.

## Changes
1. **Remove the center HUD** — delete `HUDController.swift`, `HUDViewModel.swift`, and
   `HUDViewModelTests.swift`; drop all HUD wiring from `AppDelegate`. The surfaces become: menu bar +
   persistent overlay (which now glows on change).
2. **`GlowView`** (app, AppKit) — an `NSView` layered above the keyboard that draws a blue rounded-rect
   **inner border stroke + a faint blue tint** (no shadow). `alphaValue` starts at `0`.
3. **`OverlayController`** — the panel's content becomes a container hosting the `KeyboardView` (fill)
   and, added **above** it, a `GlowView` (fill). Both use `wantsLayer = true` so the fade is smooth.
   New `flashGlow()`: **cancel any in-flight fade first** (`glowView.layer?.removeAllAnimations()`),
   reset `glowView.alphaValue = 1` **and pop `panel.alphaValue = 1.0` (100%)**, then run a fresh
   `NSAnimationContext` group over ~0.7s animating `glow.animator().alphaValue → 0` **and
   `panel.animator().alphaValue → currentOpacity`** (dim back to the user's selected opacity).
   (Cancelling first is required — resetting a property while its implicit animation runs does NOT
   reliably supersede; verify by hammering rapid layer changes.) The overlay stays always visible.
   `setOpacity` records `currentOpacity` (the value to dim back to).
4. **`OverlayPanel`** — with the HUD gone, the `movable:false` click-through branch is dead code (only
   the draggable overlay remains). Drop the `movable` parameter and the branch; the factory always
   produces the draggable, non-click-through overlay panel. Update `OverlayController`'s call site.
5. **`AppDelegate`** — when the active layer changes **to a non-base layer** (`changed && newLayer != 0`),
   call `overlay.flashGlow()` — glow on *entering* a layer, not when returning to base 0 (user request:
   the glow should read as "you switched," and a momentary layer's return-to-base was visually stealing
   it). Replaces `hudController.flash()`; remove the `HUDViewModel`/`HUDController` members and setup.

## Decisions / notes
- Glow = a saturated blue (`systemBlue`) rounded-rect border with a soft outer shadow, fading ~0.7s.
  Tunable (color/duration/thickness).
- **Decision (opacity):** the glow lives inside the overlay panel, so it inherits the user's opacity
  setting (capped at `panel.alphaValue`). This keeps a **single panel**; a low-opacity overlay gets a
  correspondingly subdued glow, which is acceptable and consistent (the whole widget dims together).
  It's drawn saturated so it still reads at the 40% floor. Not a "TBD" — no second panel.
- Increment-a (drag / opacity / persistence) is untouched.

## Tests
- No new **pure** logic — the glow is presentation-only (an `NSAnimationContext` alpha animation), so it's
  verified by **running**, not unit-tested. Removing the HUD drops its 4 `HUDViewModel` unit tests; the
  rest of the suite stays green. (Honest trade: we're deleting a feature and its tests, and the new
  behavior has no testable pure state.)

## Definition of done
Builds; `swift test` green (existing minus the removed HUD tests); the center HUD is gone; the persistent
overlay glows blue on layer change and fades; fresh-critic approves every changed file; `PLAN.md` updated.

## Simplicity guardrails
- `NSAnimationContext` alpha animation for the glow — **no** custom timer or state machine. A new flash
  supersedes by **explicitly cancelling** the in-flight animation (`layer?.removeAllAnimations()`) then
  re-running — not by merely resetting `alphaValue` (which the running implicit animation would stomp).
- One new view (`GlowView`); reuse the existing overlay panel + `OverlayController`.
- Net **deletion** of code (HUD removed) — the app gets simpler, not more complex.
