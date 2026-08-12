# M4 addendum — dual-function key labels (tap + hold)

> Extends M4 per user feedback: keys that are mod-taps / layer-taps have TWO functions (tap = key,
> hold = modifier or layer). The overlay currently shows only the tap. Show both. Follows `../AGENTS.md`.

## Problem
`KeycodeLabeler` collapses dual-function keycodes to their tap label:
- Home-row mods `MT(mod, kc)` → just the letter (A/S/D/F), hiding the ⌘/⌥/⌃/⇧ hold.
- Layer-taps `LT(layer, kc)` → just the tap key (e.g. Tab), hiding the "hold → Layer N".
The hold behavior is exactly what's hard to memorize, so it must appear on the overlay.

## Design (smallest change that shows both)
1. **`KeycodeLabeler`** — add `struct KeyLabel { primary: String; hold: String? }` and
   `decode(_ keycode: UInt16) -> KeyLabel`. Keep `label(_:) = decode(_:).primary` (back-compat).
   - `MT(mod, kc)` (`0x2000–0x3FFF`): primary = tap key; hold = **modifier glyph(s)** from the mod
     mask — `⌃`(ctrl) `⇧`(shift) `⌥`(alt) `⌘`(gui). mod = `(kc >> 8) & 0x1F`; mask = `mod & 0x0F`.
     Multi-bit masks (e.g. Hyper/Meh) concatenate in fixed order **`⌃⇧⌥⌘`** so combos render
     deterministically (never drop a bit). Bit `0x10` (right-hand indicator) is ignored for the glyph.
   - `LT(layer, kc)` (`0x4000–0x4FFF`): primary = tap key (or `L{n}` if none); hold = `L{layer}`.
   - `QK_MODS` (`0x0100–0x1FFF`, e.g. RALT(A)): primary = base key; hold = modifier glyph (it's a
     single chord, but showing the modifier is still the useful "what else is on this key").
   - Everything else (basic, plain layer switches MO/TO/…, TRNS/NO, hex fallback): `hold = nil`.
2. **`KeyboardModel`** — change the internal legend store from `[[[String]]]` to **`[[[KeyLabel]]]`**
   (one place to carry both primary + hold per cell). `live` fills each cell via `decode(_:)`;
   `staticLegends` fills `KeyLabel(primary: text, hold: nil)`; `keys(forLayer:)` reads `.primary`/`.hold`.
   **`PositionedKey`** gains `hold: String?` with an explicit `public init(..., hold: String? = nil)`.
   All current `PositionedKey` constructions (in `keys(forLayer:)` and `KeyboardLayoutTests`) use
   **labeled** args and omit `hold` → keep compiling; confirm by grep before editing.
3. **`KeyboardView`** — draw `hold` small and dimmed (white ~55%) in the **top-right corner** of each
   key when non-nil; primary centered. **Shrink fonts to fit rather than skip** (user request): when a
   key carries a hold label, reduce the primary font so the corner has room, and shrink the sub-label
   font in a loop until it fits the key width (down to a ~5pt floor). Only omit if it can't fit at the floor.

## Bit-layout facts (verified from the real capture)
`0x2804`→MT(⌘,A) hold `⌘`; `0x2416`→MT(⌥,S) `⌥`; `0x2107`→MT(⌃,D) `⌃`; `0x2209`→MT(⇧,F) `⇧`;
`0x422B`→LT(2,Tab) primary `⇥` hold `L2`. Mod mask bits: `0x01`⌃ `0x02`⇧ `0x04`⌥ `0x08`⌘ (bit `0x10` =
right-hand indicator, ignored for the glyph).

## Tests
- `KeycodeLabeler.decode`: MT → (tap, mod glyph) for the four real home-row mods; LT → (tap, `L{n}`)
  and LT-with-no-tap → (`L{n}`, `L{n}`); QK_MODS → (base, glyph); a **multi-bit MT mask → glyphs in
  `⌃⇧⌥⌘` order**; basic/layer-switch/TRNS/NO/hex → hold nil.
  `label(_:)` still returns the primary for all existing cases (no regression).
- `KeyboardModel.live`: a key over `MT(⌘,A)` → `PositionedKey.label == "A"`, `.hold == "⌘"`; a basic
  key → `.hold == nil`. Bundled-Totem: matrix `[0,0]` (Q) hold nil; a home-row-mod cell hold = its glyph.

## Definition of done
Builds; `swift test` green (64 + new, no regressions); overlay shows the hold glyph/layer on dual-
function keys; fresh-critic approves every changed file; then this rolls into the **M4** close-out
(one code-critic pass covers M4 + this addendum). `PLAN.md` gotcha updated with the mod-mask glyphs.

## Simplicity guardrails
- One extra optional field (`hold`), not a general multi-legend list — tap+hold is the real need.
- Reuse existing `KeycodeLabeler` range logic; only split the return into primary/hold.
- No new types beyond `KeyLabel`; no renderer restructure — just a corner sub-label.
