# HID protocol

split-forge uses **two channels on the same Raw HID interface** (usage page `0xFF60`, usage `0x61`), split by cadence.

## 1. Active layer — firmware broadcast (device → host, passive)

The firmware calls `raw_hid_send()` on every layer change (and once on boot). The host passively listens; no request is sent. A 32-byte report:

| byte | value | meaning |
|------|-------|---------|
| 0 | `0xCC` | magic — "relay from device" (distinct from Vial/VIA command IDs, which start low) |
| 1 | `0x01` | message type: `LAYER` |
| 2 | `0..N` | active layer = `get_highest_layer(state)` |
| 3–31 | `0x00` | reserved |

The host accepts a report **only if** `byte[0] == 0xCC && byte[1] == 0x01`, so it can share the interface with Vial without confusion. The firmware snippet is adapted verbatim from [qmk-hid-host](https://github.com/zzeneg/qmk-hid-host); see `firmware/totem/keymap_broadcast.c`.

**We never define `raw_hid_receive()`** — Vial/VIA owns it, and overriding it breaks Vial (vial-qmk issue #538). The broadcast is send-only.

### Key presses — firmware broadcast (device → host, passive)

The firmware also calls `raw_hid_send()` from `process_record_kb` on every key press and release, so the host overlay can highlight the pressed key. (It hooks `process_record_kb`, not `process_record_user`, because the Vial keymap already defines `process_record_user` — the keyboard-level hook then calls through to it.) Same 32-byte report, message type `0x02`:

| byte | value | meaning |
|------|-------|---------|
| 0 | `0xCC` | magic — "relay from device" |
| 1 | `0x02` | message type: `KEY` |
| 2 | `0..MATRIX_ROWS-1` | matrix row (Totem: 0–3 left half, 4–7 right half) |
| 3 | `0..MATRIX_COLS-1` | matrix column |
| 4 | `0/1` | released / pressed |
| 5–31 | `0x00` | reserved |

The host accepts a report **only if** `byte[0] == 0xCC && byte[1] == 0x02`, and highlights the key at that matrix position (matching `PositionedKey.matrix`). Combos/virtual keypositions are skipped in firmware (a sentinel `row/col`), so they produce no highlight.

## 2. Legends — VIA read (host → device, one-shot on connect)

To draw what each key does, the host reads the live keymap using standard VIA commands (the same ones the Vial web app uses). All reports are 32 bytes, report ID 0.

### `id_dynamic_keymap_get_layer_count` (`0x11`)
Request: `[0x11, 0x00 …]` → Response: `[0x11, <count>, …]`.

### `id_dynamic_keymap_get_buffer` (`0x12`)
Read the keymap in ≤28-byte chunks (32 − 4 header bytes).

Request: `[0x12, offset_hi, offset_lo, size, …]`
Response: `[0x12, offset_hi, offset_lo, size, <size data bytes> …]`

The keymap buffer is **16-bit big-endian keycodes**, ordered **layer-major, then row-major, then column**:

```
byte_offset(layer, row, col) = (layer * ROWS * COLS + row * COLS + col) * 2
total_size                   = LAYERS * ROWS * COLS * 2
```

`ROWS`/`COLS` come from the keyboard's `KeyboardDefinition` (matrix dimensions). Keycodes are mapped to human labels by `KeycodeLabeler` (M2), with a raw-name fallback for uncommon codes.

> Geometry (physical key positions) is **not** read live in v1 — it comes from the bundled `KeyboardDefinition` JSON. Fetching the Vial definition (LZMA-compressed) for zero-config arbitrary boards is a future stretch.

## Coexistence with the Vial web app

The passive broadcast (channel 1) never collides — it's send-only and header-tagged. The VIA reads (channel 2) are a brief one-shot on connect; if the Vial web app is reading at the same instant, responses can interleave. Mitigation: retry, and a manual **Re-sync** action; recommend closing Vial while syncing.
