# M5c + icon — editable layer names, launch at login, app icon

> User request (2026-07-04): add editable layer names, launch-at-login, and an app icon. Follows `../AGENTS.md`.

## 1. Editable layer names
- **`Settings`** (Core): add `layerNames: [String: String]` (layer-index string → name), persisted.
  `normalized()` **drops blank/whitespace-only entries** so the dict can't accumulate garbage keys.
  Helper `layerName(_ layer: Int) -> String?` (nil if unset/blank).
- **`LayerDisplay.name(layer:names:)`** (Core, pure): trimmed custom name if non-blank, else
  `"Layer \(layer)"`. Unit-tested — the one bit of real logic.
- **`LayerStore`** (Core): **add a `layerNames` slot** (settable) + `displayName(forActiveLayer)` via the
  helper. **Route both surfaces through it** — `OverlayController.refresh()` (today hardcodes
  `"Layer \(activeLayer)"`) and `MenuBarController.refresh()` (today `"⌨ L\(activeLayer)"`) must use
  `store.displayName(...)` (menu bar shows e.g. `⌨ Nav`, fallback `⌨ L2`).
- **`AppDelegate`** seeds `store.layerNames = settings.layerNames` at launch (alongside applyOrigin/setOpacity).
- **Editing UI** (`PreferencesWindowController`, AppKit): a small window with a labelled `NSTextField`
  per layer (0…7). Loaded from `Settings`; save on **`controlTextDidEndEditing`** / the field action —
  **not** per-keystroke. On save: update `Settings.layerNames` + `store.layerNames`, persist, and
  **call `store.onChange?()`** so the overlay + menu bar repaint immediately (a rename doesn't change the
  layer, so `onChange` won't fire otherwise). Opened from a menu-bar **"Preferences…"** item. `AppDelegate`
  **retains** the `PreferencesWindowController` (else the window deallocs on close).

## 2. Launch at login
- **`SMAppService.mainApp`** (`import ServiceManagement`, macOS 13+). A menu-bar **"Launch at Login"**
  checkbox, **always shown** (don't hide it — silent absence is worse than a visible no-op): toggles
  `register()` / `unregister()`, then **re-reads `.status` to drive the checkmark** (never trust the
  call's return). It works from a plain `cp` install in `/Applications` *or* `~/Applications`
  (translocation/quarantine — the usual "unreliable" cause — doesn't apply to a local copy); if it ever
  fails to persist, `.status` reads `.notRegistered` and the checkmark honestly reflects that.
- `.status` may be **`.requiresApproval`** on first enable (user flips the switch in System Settings →
  General → Login Items) — treat as "on" (checkmark) and **do not surface an error dialog** for it. Catch
  genuine thrown errors quietly; the checkmark stays accurate from `.status`.

## 3. App icon
- **`tools/make_icon.swift`** — draws a dark squircle (rounded-rect, blue-tinted) with a white SF Symbol
  `keyboard` centred, renders the standard iconset PNG sizes, and runs `iconutil -c icns` → `tools/AppIcon.icns`.
  Run once; **commit `tools/AppIcon.icns`** (regenerate with the script if the design changes).
- **`build_app.sh`** — copy `tools/AppIcon.icns` → `Contents/Resources/AppIcon.icns` and add
  **`CFBundleIconFile=AppIcon`** to `Info.plist` (correct key; NOT `CFBundleIconName`, which needs an
  asset catalog we don't have). **Cache-bust on install** so Finder/Spotlight pick the icon up on a
  same-path reinstall: `touch` the installed `.app`, then run `lsregister -f` at its **full path**
  (`/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Support/lsregister`
  — it isn't on `PATH`).

## Tests (pure Core, no AppKit)
- `Settings` codable round-trips `layerNames`; `layerName` returns nil for blank/unset.
- `LayerDisplay.name`: custom → the name; unset/blank → `"Layer N"`.
- `LayerStore.displayName(forActiveLayer)` follows both the active layer and the names dict.

## Verification (AppKit / icon → by running)
- Preferences: rename a layer → overlay header + menu bar **repaint immediately** and persist across relaunch.
- Launch at Login (only when installed in `/Applications`): toggle → SplitForge appears in System Settings →
  General → Login Items (may show as needing approval); survives logout/login; checkmark matches `.status`.
- Rebuilt app shows the icon in Finder / Spotlight / ⌘-Tab (after the install-time icon-cache refresh).

## Definition of done
Builds; `swift test` green (76 + new); names editable + persisted + shown; login toggle works; icon in the
bundle; fresh-critic approves every changed file; `PLAN.md` M5 → ✅ (all M5 done) and M6 icon noted.

## Simplicity guardrails
- Names: one pure display helper + a dict on `Settings`/`LayerStore`; a fixed-rows (0–7) Preferences
  window — not a dynamic-from-model table.
- Launch-at-login: `SMAppService.mainApp` + a menu checkbox — no separate helper/login-item target.
- Icon: SF Symbol on a squircle via a small script — no external art tools; commit the `.icns`.
- Reuse the existing menu/overlay/Settings plumbing; no restructure.
