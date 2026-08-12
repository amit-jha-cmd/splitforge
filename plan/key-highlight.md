# Feature — highlight the pressed key on the overlay (firmware broadcast)

> User request (2026-07-04): see the active button light up on the overlay when pressed. Chosen approach:
> **firmware broadcasts the exact matrix position** on each press/release (perfect, all layers/held mods).
> Requires a one-time reflash. Follows `../AGENTS.md`.

## Protocol addition (`docs/PROTOCOL.md`)
A third message type on the existing send-only Raw HID channel:
`byte[0]=0xCC` (magic), `byte[1]=0x02` (KEY), `byte[2]=row`, `byte[3]=col`, `byte[4]=pressed (1/0)`.
(Existing: `0x01`=LAYER. VIA reads still start `0x11`/`0x12`, so no collision.)

## Firmware (`firmware/totem/keymap_broadcast.c`)
Add `process_record_user(uint16_t keycode, keyrecord_t *record)` that, for a **valid matrix position**
(`record->event.key.row < MATRIX_ROWS && .col < MATRIX_COLS`, to skip combos/virtual events), calls
`raw_hid_send([0xCC, 0x02, row, col, pressed])` and returns `true` (normal processing continues). Fires
on the master for both halves (split key events resolve on the master), so row 0–3 = left, 4–7 = right —
matching the bundled `totem.json`. Rebuild both handed `.uf2`s; user reflashes.

## Host — Core (pure, unit-tested)
- **`KeyPressReport`** — `decode(_ bytes: [UInt8]) -> KeyPress?` where `KeyPress { row, col, pressed }`.
  Returns nil unless `bytes.count >= 5 && bytes[0]==0xCC && bytes[1]==0x02`. Mirrors `LayerReport`.

## Host — App (verified by running)
- **`KeyboardView`**: add `pressedMatrix: Set<[Int]>`; when drawing each key, if `pressedMatrix` contains
  its `matrix`, fill it with a bright **blue** highlight (instead of the dark key colour). The key already
  carries `matrix`, so no keycode lookup is needed.
- **`OverlayController.setKeyPressed(row:col:down:)`** — insert/remove `[row, col]` in the view's
  `pressedMatrix` and redraw. `clearPressed()` resets it on a keymap re-sync (clears an orphan from
  app-start-mid-hold or a dropped report). **Do NOT clear on layer change** — highlight is by physical
  matrix position, so a held layer/mod key must stay lit across the layer switch it triggers, until its
  own release message arrives.
- **`AppDelegate.onReport`** — route `KeyPressReport.decode` (`0x02`) to `overlay.setKeyPressed` (after
  the existing `LayerReport` `0x01` check, before `vial.handle`). Clear pressed state on a completed
  keymap read.

## Tests (Core)
- `KeyPressReport.decode`: valid press `[0xCC,0x02,1,3,1]` → `(row:1,col:3,pressed:true)`; release
  (`…,0`) → pressed false; padded 32-byte report; wrong magic/type → nil; too short → nil.

## Verification (by running)
Reflash → press keys on the Totem → the matching overlay key lights up blue and clears on release,
including held home-row mods / layer keys, on any layer. Combos/virtual keys (matrix sentinel position)
are guarded in firmware → no highlight (expected).

## Simplicity guardrails
- Reuse the existing broadcast channel + `raw_hid_send` (one new message type) — no new firmware feature
  flags. Host decode mirrors `LayerReport` (tiny). Highlight is a `Set<[Int]>` on the view — no new view.
- Match by **matrix position** (already on `PositionedKey`) — no keycode/NSEvent/permission work.
- Don't debounce/animate the highlight in v1; a stuck key is cleared on the next re-sync.
