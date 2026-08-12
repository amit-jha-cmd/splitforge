# M2 — VialClient: live keymap read + keycode labeling (implementation plan)

> Detailed plan for milestone M2. Follows `../AGENTS.md`. When done, set the M2 row in `PLAN.md` → ✅.

## Goal
Turn the proven M0 spike behavior into reusable, unit-tested app components: on connect, read the
live keymap from the keyboard over VIA, and translate raw 16-bit keycodes into short human labels —
producing per-layer legend data that M3 will lay onto the Totem geometry. Pure logic stays free of
IOKit; the one IOKit boundary sits behind a protocol with a mock for tests.

## Hardware facts to honor (from M0)
- Totem VID `0x3A3C` / PID `0x0002`, product `TOTEM`. Layer count = 16. Matrix ≈ 4×10 (40 keys/layer;
  unused = `KC_TRNS 0x0001`).
- Base layer uses home-row mods → decoding mod-tap (`0x2xxx`) and layer-tap (`0x4xxx`) is required.
- Full buffer reads cleanly in 28-byte chunks and coexists with the broadcast.

## Components
1. **`HIDTransport` protocol** (`Sources/HID/`): the minimal device I/O the reader needs —
   `func setReport(_ bytes: [UInt8]) throws` and inbound-report delivery via a **closure**
   (`var onReport: ([UInt8]) -> Void`) — matches the existing IOKit callback shape and dodges Swift-6
   concurrency friction (see PLAN.md SwiftPM gotcha). No AsyncStream.
   - `IOKitHIDTransport`: real impl, extracted from `splitforge-spike/main.swift` (IOHIDManager,
     match on VID/PID + usage page `0xFF60`, input-report callback, `IOHIDDeviceSetReport`).
   - `MockHIDTransport`: test double that returns scripted responses for requests.
2. **`VialClient`** (`Sources/HID/`, transport-agnostic orchestration): given `(layerCount, rows, cols)`
   - reads `get_layer_count` (`0x11`) to confirm count,
   - computes chunks via `KeymapBuffer.chunks/totalSize`, issues `Via.getBufferRequest` per chunk,
   - **routes each inbound report by `bytes[0]` command byte first** (`0xCC` broadcast vs `0x11` vs
     `0x12`), then correlates `get_buffer` responses by echoed offset; tracks the set of **outstanding
     offsets** and **idempotently ignores** a late/duplicate chunk for an already-filled offset,
   - assembles a flat `[UInt16]`, reshapes to `[layer][row][col]`,
   - **bounded wait**: if a chunk never arrives (unplug / Vial-web contention) it reports the read as
     **incomplete** rather than hanging, so `resync()` can retry,
   - one-shot on connect; exposes `resync()`.
3. **`KeycodeLabeler`** (`Sources/Core/`, pure) — `func label(_ keycode: UInt16) -> String`:
   - basic keycodes (A–Z, 0–9, punctuation, space/enter/tab/bksp/esc/del, mods, F-keys, arrows/nav);
   - mod-tap `MT` `0x2000–0x3FFF` → tap-key label (e.g. `A`); layer-tap `LT` `0x4000–0x4FFF` → `L{n}/{tap}`;
   - layer switches `MO/TO/TG/TT/DF/OSL` → `L{n}` style; `KC_TRNS 0x0001` → `▽`; `KC_NO 0x0000` → ``;
   - **bit layouts differ** — `MT` = `0x2000|(mod<<8)|kc` (mod in bits 8–12), `LT` = `0x4000|(layer<<8)|kc`,
     and `MO/TO/TG/TT/DF/OSL` pack the layer in their own ranges; extract the mod/layer field per QMK's
     range for each and **verify each family in the fixture-backed test**;
   - **raw-hex fallback** (`0x5221`) for anything unrecognized — never crash, never block a render.
4. **`KeymapBuffer.reshape`** helper (`Sources/Core/`): flat `[UInt16]` → `[layer][row][col]` for dims
   (inverse of `cellOffset`), so `VialClient` and tests share one definition of the layout.

## Extraction
Refactor the IOKit code out of `splitforge-spike/main.swift` into `IOKitHIDTransport`; the spike keeps
working by constructing `VialClient` over that transport (proves the extraction end-to-end without
hardware in CI, on hardware for real).

## Tests (XCTest, no hardware)
- `KeymapBuffer.reshape`: round-trips against `cellOffset` for (16,4,10) and ragged dims.
- `VialClient` + `MockHIDTransport`:
  - emitted `getBuffer` requests cover the whole keymap with no gaps/overlap for (16,4,10);
  - **real captured layer-0 bytes** as a fixture → asserts decoded keycodes (`0x0014,0x001A,0x0008,…`);
  - out-of-order, short final chunk, **duplicate/late chunk (idempotently ignored)**, and
    **missing chunk → read reported incomplete** (mock simply never answers that offset) all handled.
- `KeycodeLabeler`: table incl. the real home-row mods (`0x2804→A`, `0x2416→S`, …), basic keys,
  `MO/LT/TG`, `TRNS/NO`, and the `0x5221` hex fallback.

## Definition of done
Builds; `swift test` green (24 existing + new); IOKit isolated behind `HIDTransport`; fresh-critic
approves **every** changed file; `PLAN.md` M2 row → ✅; new gotchas (if any) recorded.

## Simplicity guardrails
- **No** geometry/definition loading here (that's M3) — `VialClient` takes `(layerCount, rows, cols)`
  as inputs, staying decoupled and fully testable.
- **Read-only**: do not implement VIA keymap *writes*.
- Reuse existing `Via`/`KeymapBuffer`/`LayerReport` from Core — do not duplicate framing logic.
- Label set covers the common/observed keycodes with a hex fallback; exhaustive QMK coverage is a
  later refinement, not an M2 blocker.
