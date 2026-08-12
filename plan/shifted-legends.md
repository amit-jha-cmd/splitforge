# Feature plan — show shifted symbols on the overlay (`1` → `!`)

## Problem
Vial shows each basic key's **shifted legend** (`1`→`!`, `2`→`@`, `;`→`:`, …). Our overlay shows only
the tap `primary` + an optional `hold` sub-label, so symbol/number keys look bare compared to Vial.

## Key fact (why this is a labeler change, not firmware)
The shifted symbol is **not** in the keymap and is **not** broadcast — it's a fixed property of the
base HID keycode under a **US-ANSI** layout. Vial hard-codes the same US-ANSI table. So we derive it
host-side from the keycode; no firmware change, no reflash.

**Assumption (documented, matches Vial):** US-ANSI. On a non-US OS input source the real shifted
output could differ; we mirror Vial and assume US. Out of scope to detect the live OS layout.

## Scope — the exact 21 US-ANSI shifted pairs
Only keys whose **tap** is one of these base keycodes gets a shifted legend:

| keys | shifted |
|---|---|
| `1 2 3 4 5 6 7 8 9 0` | `! @ # $ % ^ & * ( )` |
| `- = [ ] \` | `_ + { } \|` |
| `; ' ` `` , . /` | `: " ~ < > ?` |

- **`0x32` `KC_NONUS_HASH` is EXCLUDED → `shifted = nil`.** It's an ISO-only key absent from US-ANSI;
  under our US-ANSI assumption `#` is `Shift+3` and `~` is `Shift+`grave, so pairing `0x32`→`~` would
  be wrong (Vial doesn't). (Aside: `basicLabel` already renders `0x32` as `#` at line 88 — pre-existing
  and out of scope; we just must not compound it with a bogus shifted pairing.)
- **Letters get NO shifted legend** — the primary already renders uppercase (`A`), so `Shift+A` is
  redundant clutter. This holds **even when the hold is Shift** (`MT(SFT, KC_A)` → shifted nil).
- **Everything else** (space, enter, F-keys, nav, layer-switches, hex fallback) → `shifted = nil`.
- Applies through the dual-function families: `MT(SFT, KC_1)` taps `1` → shows shifted `!` **and** hold
  `⇧`; `LT(2, KC_SCLN)` → shifted `:` and hold `L2`. (Vial shows the shifted legend regardless of hold.)

## Design (simplest that meets it) — mirror `hold` exactly
A third parallel optional label, decoded once in `KeycodeLabeler` (the single source of keycode truth),
threaded through the model, drawn by the view. Confirmed simplest: computing in the view would push
keycode knowledge into the dumb renderer (which only sees `PositionedKey`, no `UInt16`); overloading
`hold` collapses two independent glyphs that render in different corners and co-occur; folding into
`primary` breaks the centered shrink-to-fit.

### M1 — Core: decode the shifted symbol (unit-tested)
`KeycodeLabeler` (`macapp/Sources/SplitForgeCore/KeycodeLabeler.swift`):
- Add `shifted: String?` to `KeyLabel` (alongside `primary`, `hold`); `init` gains
  `shifted: String? = nil` so every existing call site still compiles. `label(_:)` unchanged.
- Add a private `shiftedSymbol(_ code: UInt8) -> String?` as a **`switch`** over the 21 codes above
  (matching the existing `basicLabel` style, not a dictionary); `0x32` and all others → `nil`.
- In `decode(_:)`, set `shifted` wherever the **tap** is a basic key: the `0x02–0x00FF` basic case,
  `QK_MODS` (`0x0100–0x1FFF`), `MT` (`0x2000–0x3FFF`), and `LT` (`0x4000–0x4FFF`) **only when it has a
  tap key** (`kc != 0`; the bare `L{n}` form → nil). Layer-switch (`0x52xx`) / default hex → nil.

Tests (`KeycodeLabelerTests`) — all non-vacuous:
- `KC_1`→shifted `!`; a sweep asserting each of the 21 pairs;
- `KC_A`→shifted nil; `KC_SPACE`/`KC_ENT`→nil;
- `0x32` `KC_NONUS_HASH`→shifted nil (locks the exclusion against regression);
- `MT(SFT, KC_1)`→(primary `1`, hold `⇧`, shifted `!`);
- `MT(SFT, KC_A)`→(primary `A`, hold `⇧`, **shifted nil**) — letter exclusion holds under a Shift hold;
- a `QK_MODS` symbol case (a modified `KC_1`, `0x0100|0x1E`)→shifted `!` — proves the `0x0100–0x1FFF`
  branch sets `shifted`;
- `LT(2, KC_SCLN)`→(primary `;`, hold `L2`, shifted `:`); bare `LT(2, KC_NO)`→(primary `L2`, shifted nil).

### M2 — Model + render: thread it through and draw it (visual verify)
- `KeyboardModel.PositionedKey` (`KeyboardModel.swift`): add `shifted: String?` (default `nil`,
  parallels `hold`); populate in `keys(forLayer:)` from `kl.shifted`. `staticLegends` keys stay
  `shifted: nil` (definition legends are literal text — no implicit shift).
- `KeyboardView.draw` (`macapp/Sources/SplitForgeApp/KeyboardView.swift`): draw `shifted` small +
  dimmed in the **top-LEFT** corner — a mirror of the existing top-right `hold` sub-label, reusing the
  same `fitted(...)` shrink-to-fit and the same skip-if-still-too-big guard.
  - **Three-legend co-occurrence is the NORM on Layer 1**, not an edge case: every number-row key there
    is `MT(mod, KC_n)`, so it carries primary (center) + hold (top-right) + shifted (top-left) on a 1u
    key (all 38 keys are 1u).
  - **Precedence when space is scarce:** the `primary` center label is **never dropped**. `hold` and
    `shifted` sit in **opposite** top corners, so they don't compete for the same pixels; each keeps its
    own independent shrink-then-skip guard (neither is prioritized over the other). To give the two
    corners room, shrink the center label when *either* corner glyph is present: extend the existing
    `hasHold ? base*0.86` (line 58) to `(hasHold || hasShifted) ? base*0.86 : base`.
  - Visual acceptance is at the real overlay render scale (the `hold` glyph already renders legibly in
    the top-right at 1u today, and the top-left mirror is the same size) — captured in Verification, not
    a unit test, since the NSView isn't unit-tested (consistent with M4).
- Model test (`KeyboardModelTests`, parallels `testLiveAssemblyCarriesHoldLabel`):
  `KeyboardModel.live` with `KC_1` → `keys(forLayer:0)` first key `.shifted == "!"`; plain `KC_Q` →
  `.shifted == nil`; a `staticLegends`-built model → every key `.shifted == nil`.

## Non-goals
- No firmware/reflash. No live-OS-layout detection. No user toggle to hide shifted legends (a later
  follow-up if the overlay feels busy). No per-key color.

## Risks
- **Clutter / three legends on a 1u key** — the *common* Layer-1 case, handled by the dimmed small
  opposite-corner glyphs + shrink-to-fit + independent skip guards + the center-label shrink above.
  Never crashes/clips the panel; worst case a corner glyph is skipped on an unusually tight key.
- **US-ANSI-only** — documented assumption, identical to Vial's behavior.

## Verification
`cd macapp && swift build && swift test` green; then visually confirm on hardware that Layer 1 shows
`! @ # $ …` top-left of the number row **while** the hold mods (`⌘ ⌥ ^ ⇧`) still show top-right and the
tap number stays centered and legible.
