# M3 — KeyboardModel + geometry (the extensibility backbone)

> Detailed plan for milestone M3. Follows `../AGENTS.md`. When done, set the M3 row in `PLAN.md` → ✅.

## Goal
Make geometry **data-driven** and combine it with M2's legends into one render-ready `KeyboardModel`
for M4 to draw. Ship an accurate bundled Totem definition. Adding another keyboard = adding a JSON
file, **no code**.

## Grounding (from the user's checkout — `keyboards/geigeigeist/totem/keyboard.json`)
- Totem VID `0x3A3C` / PID `0x0002`. **Matrix = 8 rows × 5 cols** (split doubles rows: left rows 0–3,
  right rows 4–7), **38 keys**; matrix cells `[3,1]` and `[7,1]` are unused (read as TRNS).
- **Correction to carry from M2:** the spike used a *cosmetic* `4×10`; the real dims for matrix→key
  mapping are **8×5** (8·5 = 40 cells/layer = same 1280-byte buffer). M3+ uses 8×5 from the definition;
  update the spike's `VialClient(... rows: 8, cols: 5)` for a correct legend print.
- `layouts.LAYOUT.layout` gives each key `{ matrix:[r,c], x, y }` (KLE-ish float coords, x 0–14,
  y 0–3.85). This is the geometry source for the bundled definition.
- **⚠️ Right-half columns run OPPOSITE to x:** `R00 = matrix:[4,4] @ x=9` (leftmost of right half),
  `R04 = matrix:[4,0] @ x=13`. So each key must keep its OWN `matrix` **and** its OWN `x` — never
  infer position by sorting on matrix, or the right hand transposes. No `w`/`h`/`rotation` in the
  source (all 1×1; thumb splay is pure fractional x/y). No `half` field needed (x separates halves).
- **Generate `totem.json` programmatically** from `keyboard.json` (a small script), not by hand —
  avoids transcription errors in 38 × (x,y) and the reversed right-hand cols.

## Components (all in `SplitForgeCore` unless noted)
1. **`KeyboardDefinition`** (Codable — `Codable` is stdlib, so the type stays Foundation-free):
   ```
   id, name, usbVendorId, usbProductId,
   matrix { rows, cols },
   keys: [ KeyDef { matrix:[row,col], x, y, w = 1, h = 1, rotation = 0 } ],
   staticLegends?: { "<layer>": { "<row>,<col>": "label" } }   // fallback for non-VIA boards
   ```
   `validate()` throws on: missing dims; a key's `[row,col]` outside the definition's **own**
   `matrix.rows/cols` (not a hardcoded 8×5); duplicate matrix coords; empty keys.
2. **`KeyboardModel`** (pure assembly): built from a `KeyboardDefinition` + a legend source —
   - **live**: `[[[UInt16]]]` (from `VialClient`) → `KeycodeLabeler.label` per cell, or
   - **static**: `staticLegends`.
   Exposes `matrix`, `layerCount`, geometry, and `keys(forLayer:) -> [PositionedKey]` where
   `PositionedKey { matrix, x, y, w, h, rotation, label }` — exactly what M4 iterates. **Iterates
   `definition.keys` only (never the full row×col grid)**, so the 2 unused cells never become phantom
   keys. A legend source with fewer layers/rows than expected → **empty label, no crash** (safe).
3. **`DefinitionLoader`** (imports Foundation — `JSONDecoder` + `Bundle.module`):
   `decode(_ data) -> KeyboardDefinition` and `loadBundled(name:) -> KeyboardDefinition`, reading the
   bundled resource `Sources/SplitForgeCore/Resources/totem.json`. (Runtime user-directory loading is
   deferred to M5 preferences.)
4. **Bundled `totem.json`** — generated from `keyboard.json`: 38 keys, matrix 8×5, VID/PID, name "TOTEM".

## Package
Add `resources: [.process("Resources")]` to the `SplitForgeCore` target so `Bundle.module` sees
`totem.json`. Pure files stay Foundation-free; **only `DefinitionLoader` imports Foundation**.

## Tests (XCTest, no hardware)
- `KeyboardDefinition` decodes from a JSON fixture; `validate()` rejects out-of-range matrix, duplicate
  coords, and empty keys.
- Bundled `totem.json` loads → **38 keys, matrix 8×5, VID 0x3A3C / PID 0x0002**; every key's matrix in
  range; no duplicate matrix coords.
- `KeyboardModel` assembly from **live** legends (reuse the real captured layer-0 fixture from M2) →
  `keys(forLayer: 0)` yields the correct label at the correct matrix/position; and from **static** legends.
- Round-trip: a `PositionedKey.label` equals `KeycodeLabeler.label(rawKeycodeAtThatMatrixCell)`.

## Definition of done
Builds; `swift test` green (41 existing + new); Core's pure files unchanged (Foundation only in
`DefinitionLoader`); bundled Totem is render-ready; fresh-critic approves **every** changed file;
`PLAN.md` M3 → ✅.

## Simplicity guardrails
- **No** rendering (M4) and **no** preferences/user-directory loading (M5).
- Reuse `KeycodeLabeler` / `KeymapBuffer` from Core; don't duplicate.
- **One** model type consumed by the renderer regardless of legend source (live vs static).
- Geometry stays plain float `x/y/w/h` (KLE-ish); no rendering/unit math here.
