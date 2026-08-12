# M5 (increment a) — draggable overlay position + opacity, persisted

> First slice of M5, user-requested (2026-07-04): drag the always-visible corner overlay to reposition
> it, and adjust its opacity — both **persisted** across relaunch. Follows `../AGENTS.md`.

## Components
1. **`Settings`** (`SplitForgeCore`, pure `Codable`/`Equatable`, stdlib only):
   - `overlayOriginX: Double?`, `overlayOriginY: Double?` — both nil = default corner (no bespoke
     `Point` type; the app reads a point only when both are set).
   - `overlayOpacity: Double` — clamped to `[0.3, 1.0]`; default `1.0`.
   - `static let defaultSettings` and `normalized()` (clamps opacity; leaves origin as-is).
2. **`SettingsStore`** (`SplitForgeCore`, imports Foundation like `DefinitionLoader`):
   `init(defaults: UserDefaults = .standard)`, `load() -> Settings` (missing/corrupt → `.default`),
   `save(_:)`. Stores one JSON blob under key `"settings.v1"`. Injectable `UserDefaults` → unit-testable.
3. **`OverlayPanel.make(... movable: Bool = false)`** — when `movable`, set `ignoresMouseEvents = false`
   and `isMovableByWindowBackground = true` (drag by background), and **omit `.stationary`** from
   `collectionBehavior` (it can fight background-drag). The **overlay** is movable; the **HUD** stays
   `movable: false` (click-through). Trade-off: a draggable overlay can't also be click-through on itself
   (clicks move it) — acceptable for a repositionable widget. `KeyboardView` must not override
   `mouseDown`/`hitTest`, or background-drag won't reach the window.
4. **`OverlayController`**:
   - Built movable; applies the saved origin **only if it sits within some `NSScreen.screens[*].visibleFrame`**
     (check ALL screens, not just `.main`, for multi-monitor); otherwise fall back to `positionCorner()`.
     Applies `overlayOpacity` via `panel.alphaValue`. (Origin validity is screen-dependent, so this clamp
     lives app-side, not in pure Core — `Settings.normalized()` only touches opacity.)
   - Observes `NSWindow.didMoveNotification` for its panel with a **weak** capture; stores the observer
     token and removes it in `deinit`. On move → `onOriginChanged: (CGPoint) -> Void`. (Dragging the
     content via `isMovableByWindowBackground` does fire `didMove`.)
   - `setOpacity(_:)` sets `panel.alphaValue`; `resetPosition()` clears origin → `positionCorner()`.
   - **Effective on-screen opacity = view-background alpha × `panel.alphaValue`**; the `0.3` model floor
     (min preset 40%) keeps the overlay clearly visible — never invisible/unrecoverable.
5. **`MenuBarController`** — add an **Opacity** submenu (presets 100/80/60/40%, checkmark on current →
   `onOpacity: (Double) -> Void`) and a **Reset Position** item (→ `onResetPosition: () -> Void`), so
   position always has an escape hatch even beyond the launch clamp.
6. **`AppDelegate`** — owns a `SettingsStore` + current `Settings`; on launch loads and applies
   origin+opacity to the overlay; wires `onOriginChanged`/`onOpacity`/`onResetPosition` to mutate
   `Settings` and `save`.

## Scope / notes
- Opacity applies to the **overlay** (per request); the HUD is unaffected (it fades 0→1 on flash).
- Persistence = a single JSON blob in `UserDefaults` (simple + reliable for a menu-bar agent). A
  full Application-Support settings file + migration + the rest of M5 (surface toggles, layer names,
  login item) come in later M5 increments.

## Tests (pure Core, no AppKit)
- `Settings`: `Codable` round-trip; `normalized()` clamps opacity `0.05 → 0.3` and `1.5 → 1.0`;
  `defaultSettings` has nil origin and opacity `1.0`.
- `SettingsStore` with an isolated `UserDefaults(suiteName:)`: `save` then `load` round-trips origin +
  opacity; empty store → `defaultSettings`; a corrupt blob → `defaultSettings` (no crash).
- Origin clamp-to-screen uses `NSScreen` (app-side) → verified by running, not unit-tested.

## Definition of done
Builds; `swift test` green (72 + new); overlay is draggable, opacity is adjustable from the menu, and
both **persist across relaunch** (verified by running); fresh-critic approves every changed file; the
M5 row in `PLAN.md` notes this increment done.

## Simplicity guardrails
- Opacity via menu presets — **no** custom slider view (NSMenu can't host one cleanly).
- One `movable` flag on the existing `OverlayPanel` — **not** a second panel type or a custom drag handler.
- Persist only origin + opacity now; don't build the full settings schema yet.
- `Settings`/`SettingsStore` are the only new types; controllers gain small callbacks, no restructure.
