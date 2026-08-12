# M4 — Renderer + the three overlay surfaces

> Detailed plan for milestone M4. Follows `../AGENTS.md`. When done, set the M4 row in `PLAN.md` → ✅.

## Goal
Turn the M3 `KeyboardModel` into pixels: a runnable macOS menu-bar app that draws the Totem's shape
with the active layer's legends across **three surfaces** — menu bar indicator, always-visible corner
overlay, and a transient HUD that flashes on layer change — all driven by one `LayerStore`.

## Split: pure/testable (Core) vs AppKit (verified by running)
Keep all decision logic in `SplitForgeCore` (unit-tested, no AppKit); AppKit only draws and hosts.

### Pure logic → `SplitForgeCore` (new, unit-tested)
1. **`LayerStore`** — the single source of truth: `activeLayer: Int`, `model: KeyboardModel?`,
   `setActiveLayer(_:)` / `setModel(_:)` (notify via `onChange`), `keysForActiveLayer()`.
2. **`HUDViewModel`** — the show-on-change / auto-hide state machine, **no timers inside** (so it's
   deterministically testable):
   - `layerChanged()` → `isVisible = true`, **bump `token: Int` (even when already visible → restart,
     not extend)**, emit `onScheduleHide(token, duration)`;
   - `hideFired(token:)` → hides **only if** `token == current` (a newer change supersedes a pending hide).
   The app owns the real `Timer` and calls `hideFired(token:)`; tests call the methods directly.
3. **`KeyboardLayout.bounds(of:)`** — pure bounding-box of `[PositionedKey]` in key-units (accounts for
   w/h), so the renderer can scale-to-fit. Foundation-free (plain `Double`).

### AppKit → new `SplitForgeApp` executable target (build + run to verify)
4. **`KeyboardView`** (`NSView`) — draws the split shape: scale key-units→view via `KeyboardLayout.bounds`,
   draw each `PositionedKey` as a rounded rect at its `x,y,w,h` with the label centered. Highlights are
   just style. Split halves render naturally (x already separates them).
5. **Surfaces**, all fed by `LayerStore.onChange`:
   - **Menu bar** — `NSStatusItem` titled with the active layer (e.g. `L2`); menu = Quit (+ Re-sync).
   - **Corner overlay** — borderless, non-activating, always-on-top `NSPanel` (`.nonactivatingPanel`,
     `level = .statusBar`, `ignoresMouseEvents = true`, `collectionBehavior` = can-join-all-spaces),
     pinned to a screen corner, hosting a compact `KeyboardView` — always visible.
   - **HUD** — same panel style, shown/faded per `HUDViewModel` (flash the board for the new layer).
   - The overlay and HUD are **two separate panel instances** (each hosting its own `KeyboardView`),
     not one shared panel — avoids a visibility-state race between "always on" and "flash then hide".
6. **`AppDelegate` wiring**: build `IOKitHIDTransport(vid: 0x3A3C, pid: 0x0002)`, `VialClient` (dims
   from the bundled `totem` definition), `LayerStore`. `onReport` → `LayerReport.decode` → `setActiveLayer`,
   else `vial.handle`. `vial.onResult(.complete)` → `setModel(KeyboardModel.live(def, layers))`.
   `onDeviceConnected` → `vial.start()`. `.notPermitted` → a menu item / alert guiding to Input
   Monitoring. `NSApp.setActivationPolicy(.accessory)` (menu-bar agent, no dock icon).

## M4 defaults (real config is M5)
All three surfaces **on**; overlay pinned to a corner; HUD duration ~1.2s; layer shown as `L{n}`
(named layers come in M5). No preferences UI, no persistence, no launch-at-login here.

## Tests (XCTest, no AppKit)
- `LayerStore`: `setActiveLayer` notifies only on change; `setModel` notifies; `keysForActiveLayer()`
  reflects the active layer; nil model → empty.
- `HUDViewModel`: `layerChanged()` → visible + token bump + schedule emitted; `hideFired(currentToken)`
  → hidden; `hideFired(staleToken)` → stays visible; two rapid changes then hide(firstToken) → still
  visible (superseded).
- `KeyboardLayout.bounds`: known keys → correct (x,y,width,height); single key; empty → zero.

## Verification (hands-on for the AppKit parts)
`swift run SplitForgeApp` with the Totem connected → menu bar shows the layer; the corner overlay
shows the Totem shape with the current layer's legends; switching layers updates all surfaces and the
HUD flashes. Grant Input Monitoring if prompted. (I'll build/launch and screenshot to confirm.)

> **swift-run risk (critic-flagged):** a non-bundled SwiftPM executable has no `Info.plist`, so
> `NSStatusItem`/panel hosting and TCC (Input Monitoring) identity can be flaky. Mitigations: call
> `NSApp.setActivationPolicy(.accessory)` **before** `NSApp.run()`; if the status item/panels don't
> appear, generate a **thin `.app` bundle** (`Info.plist` with `LSUIElement=1`) — pulled forward from
> M6 — and launch that. Verification-time fallback, not new scope.

## Definition of done
Builds; `swift test` green (53 + new pure-logic tests); logic lives in Core behind no-AppKit types;
app runs and shows the three surfaces updating on layer change; fresh-critic approves every changed
file; `PLAN.md` M4 → ✅.

## Simplicity guardrails
- No preferences/persistence/login (M5) and no packaging/signing (M6).
- One `LayerStore` drives all surfaces; one `KeyboardView` reused by overlay + HUD.
- HUD timing state machine is timer-free in Core; the app owns the single real `Timer`.
- Reuse `KeyboardModel`/`PositionedKey`/`KeycodeLabeler`; don't duplicate geometry or labeling.
