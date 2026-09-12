# split-forge — living plan

> **This is the canonical, living plan.** Keep the **Milestone status** table and the
> **Gotchas for agents** section up to date as work lands. Every change follows
> [`../AGENTS.md`](../AGENTS.md): plan → simplicity-critic loop → user approval →
> implement with tests → fresh-critic-per-round review until every file is approved.

---

## Milestone status

| Milestone | Status | Notes |
|---|---|---|
| **M0** — Scaffold + AGENTS.md + dual-protocol spike | ✅ done | On hardware: spike shows **live layer changes** AND a full live VIA keymap read (16 layers), coexisting. 24/24 tests, critic-approved. VID/PID `0x3A3C/0x0002`. |
| **M1** — Firmware: finalize layer-broadcast module | ✅ done | Broadcast on change + `post_init`, both hardware-validated; RAW_ENABLE via VIA; prebuilt handed `.uf2`s committed to `firmware/totem/`. Source critic-approved in M0. |
| **M2** — VialClient: live keymap read + keycode labeling | ✅ done | `VialClient` (chunked `get_buffer`, command-byte routing, idempotent dupes, short-chunk reject, incomplete/timeout), `KeycodeLabeler` (MT/LT/layer + hex fallback), IOKit extracted to `SplitForgeHID`. **41 tests**, critic-approved all 10 files. |
| **M3** — KeyboardModel + geometry (extensibility) | ✅ done | `KeyboardDefinition` (Codable + validate), `KeyboardModel` (`keys(forLayer:)`→PositionedKey, live or static), `DefinitionLoader` (`Bundle.module`). Bundled `totem.json` **generated** from keyboard.json (38 keys, 8×5). **53 tests**, critic-approved all 11 files. |
| **M4** — Renderer + three overlay surfaces | ✅ done | AppKit `SplitForgeApp`: menu bar + corner overlay + transient HUD from one `LayerStore`. Keyboard-shaped render + **dual-function labels** (tap + hold ⌘/⌥/⌃/⇧ / `L#`, shrink-to-fit). Verified on hardware. **72 tests**, critic-approved all 19 files. |
| **M5** — Preferences + persistence + launch at login | ✅ done | **a** drag/opacity/persist (off-screen heal, Reset Position); **b** blue-glow-on-enter (explicit `CABasicAnimation`); **c** editable **layer names** (Preferences window, persisted, live repaint) + **Launch at Login** (`SMAppService`) + **app icon** (`tools/make_icon.swift`). **83 tests**, all critic-approved. (Center HUD removed per user → per-surface toggles moot; layer-name UI covers 0–7.) |
| **M6** — Packaging, docs, polish | ✅ done | `tools/build_app.sh` release-builds, assembles `SplitForge.app` (agent, `LSUIElement`), ad-hoc signs, installs to `/Applications`; resource resolves from the bundle (verified). README documents install + Input Monitoring + tccutil recovery. Critic-approved. (Launch-at-login = optional M5 follow-up.) |
| **F1** — Highlight the pressed key on the overlay | ✅ done (2026-07-04) | Firmware hooks **`process_record_kb`** → `raw_hid_send([0xCC,0x02,row,col,pressed])` per press/release (guards `< MATRIX_ROWS/COLS` to skip combos), calling through to the keymap's `process_record_user`. Host: `KeyPressReport.decode` + `KeyboardView.pressedMatrix` (blue) + `OverlayController.setKeyPressed`/`clearPressed` (re-sync heals stuck keys) + `AppDelegate.onReport` routes `0x02` exclusively (after `0x01`, before `vial.handle`). **88 tests**, critic-approved all 7 files. **Requires reflashing both halves** with the new `.uf2`s. |
| **F2** — Shifted legends on the overlay (`1`→`!`) | ✅ done (2026-07-04) | **Host-only, no reflash.** `KeycodeLabeler.shiftedSymbol` = a 21-pair US-ANSI table (`1..0`→`!@#$%^&*()`, `-=[]\;'` `` ` `` `,./`→`_+{}\|:"~<>?`), applied to the *tap* keycode across basic/QK_MODS/MT/LT-with-tap (nil for letters, bare `L{n}`, layer-switches, `KC_NONUS_HASH 0x32`). `KeyLabel.shifted`→`PositionedKey.shifted`→`KeyboardView` draws it small/dimmed **top-LEFT** (mirror of the top-right `hold`; always 1 char so no collision); center label shrinks when either corner glyph is present. **93 tests**, both milestones critic-approved. |
| **F3** — Cirque 40 mm trackpad on the right half | 🟡 awaiting hardware verification (2026-09-12) | **Firmware-only, no host change.** Right half's XIAO replaced by an **RP2040-Zero** on a 1:1-by-GPIO adapter, so `matrix_pins` / `SERIAL_USART_*` / `EE_HANDS` are untouched and only the *keymap* directory is patched — the overlay stays a keymap overlay. Cirque TM040040 on **I²C0, `GP12`=SDA / `GP13`=SCL**, relative mode, taps + secondary taps, throttle pinned to 10 ms. New `firmware/totem/mcuconf.h` enables `RP_I2C_USE_I2C0`; no `halconf.h` is needed because the cirque i2c driver emits `-DHAL_USE_I2C=TRUE` itself. Build gate green (`-DPOINTING_DEVICE_ENABLE` + `-DHAL_USE_I2C=TRUE` in `cflags.txt`; `i2c_master.o` + `cirque_pinnacle_i2c.o` built); both handed `.uf2`s rebuilt (212→232 blocks) and committed. **Requires reflashing both halves.** Plan: [`cirque-trackpad.md`](cirque-trackpad.md). |

Legend: ⬜ pending · 🟡 in progress · ✅ done (tests green + critic-approved). When marking a
milestone ✅, add a one-line date + what changed, and fold any new lessons into **Gotchas**.

---

## Context

The user configures a **Totem** (38-key split, wired, Vial/QMK — left half **XIAO RP2040**, right half
**RP2040-Zero** since F3) in the Vial web app
but can't keep layers in their head. Goal: a macOS overlay that **looks like the Totem** (split shape,
all keys) and shows **what each key does on the active layer**, in real time, so they build a mental
map. Must be **data-driven so other keyboards can be added without code**.

Hard constraint: **the active layer lives inside the firmware — neither macOS nor stock Vial exposes
live layer-change events.** The *keymap* (per-key/per-layer function) *can* be read over Vial/VIA HID.

**Two HID channels, split by cadence:**

| Need | Source | Cadence |
|---|---|---|
| Real-time **active layer** | Firmware **broadcast** (`raw_hid_send`, `0xCC` header) — passive listen | Continuous |
| **Legends** (per-key/layer) | **VIA read** (`dynamic_keymap_get_buffer`) — active fetch | Once on connect, cached; re-sync |
| **Geometry** (Totem shape) | **Definition file** (bundled; user-addable) | Static |

Rule of thumb: **static-in-time → file; changes-at-runtime → live.** Vial/VIA has no layer-change
push, and polling would collide with the Vial web app — hence the firmware broadcast is necessary.

Prior art (proves every piece): [KeyPeek](https://github.com/srwi/keypeek) (Rust, live Vial layer
overlay) and [qmk-hid-host](https://github.com/zzeneg/qmk-hid-host) (firmware broadcast pattern).

---

## Architecture

```
 Totem (RP2040, Vial-QMK)                               macOS app (Swift/AppKit)
 ┌──────────────────────────────┐                       ┌──────────────────────────────────┐
 │ layer_state_set_user() ──────┼─►[0xCC,0x01,layer] ──►│ HIDListener  (passive)           │
 │   raw_hid_send(32B)          │   usage 0xFF60        │      └─► active layer ┐           │
 │ Vial/VIA raw_hid_receive ◄───┼─ VIA get_buffer ─────►│ VialClient (fetch on connect)    │
 │   (firmware's own handler,   │   keycodes/layer      │      └─► keycodes ┐  KeyboardModel│
 │    we DO NOT override it)    │◄─ response ───────────┤                  ▼  (geometry +   │
 └──────────────────────────────┘                       │  KeycodeLabeler   per-layer      │
   Definition file (geometry + matrix map) ─────────────►│  → KeyboardRenderer → 3 surfaces │
   [bundled Totem; user-addable JSON]                    │    (menu bar / corner / HUD)     │
                                                         └──────────────────────────────────┘
```

Full wire format: [`../docs/PROTOCOL.md`](../docs/PROTOCOL.md).

### Extensibility contract — `KeyboardDefinition` (JSON)
```
{ id, name, usbVendorId, usbProductId, matrix:{rows,cols},
  keys:[ { matrix:[row,col], x,y,w,h, rotation? } ],   // x already separates L/R halves
  staticLegends?: { <layer>: { "<row,col>": "label" } }   // fallback for non-Vial boards
}
```
Add a keyboard = drop in a definition JSON (no code). Internal `KeyboardModel` is identical whether
legends come live over VIA or from `staticLegends`, so the renderer never knows the source.

---

## Repository structure

```
split-forge/
├── AGENTS.md                 # workflow rules (the process)
├── README.md
├── plan/PLAN.md              # THIS FILE — living plan + gotchas
├── docs/{PROTOCOL.md,flashing.md}
├── firmware/totem/           # Vial-QMK keymap OVERLAY + (M1) prebuilt .uf2
├── definitions/totem.json    # (M3) bundled KeyboardDefinition
└── macapp/                   # Swift package / Xcode project
    ├── Sources/SplitForgeCore # pure logic — NO IOKit/AppKit; fully unit-tested
    ├── Sources/splitforge-spike # M0 IOKit spike CLI (not shipped)
    └── Tests/SplitForgeCoreTests
```

---

## Milestones (detail)

### M0 — Scaffold + dual-protocol feasibility spike
Repo skeleton + AGENTS.md; firmware broadcast source; host spike CLI that (a) passively prints the
active layer and (b) reads a layer's keycodes live over VIA. **Exit:** switching layers prints the
number **and** a keymap dump appears **and Vial web still connects**. Tests: decode + VIA framing +
keymap-buffer math (24 cases).

> **2026-07-03** — Code complete; fresh-critic approved all 17 files (re-ran `swift test` itself);
> applied cleanups (per-device buffer free on reconnect, doc fixes, +2 edge tests). 24/24 green.
> Remaining to close M0: **user flashes firmware and runs the spike on the real Totem** to confirm
> the layer prints, the keymap dumps, and Vial web still connects. Record the Totem's VID/PID then.

### M1 — Firmware: finalize layer-broadcast module
Broadcast on layer change **and** `keyboard_post_init_user`; `RAW_ENABLE`; never touch
`raw_hid_receive`. Deliver keymap patch, prebuilt `.uf2`, host harness tests.

### M2 — VialClient: live keymap read + keycode labeling
VIA client (layer count + chunked `get_buffer`) → keycodes/layer. `KeycodeLabeler` (common QMK ranges
`MO/LT/TG/TO`/mod-taps + raw-name fallback). One-shot on connect, cached, re-syncable. Unit tests.

### M3 — KeyboardModel + geometry (extensibility backbone)
`KeyboardDefinition` loader (bundled accurate `totem.json` + matrix map); assemble `KeyboardModel`
= geometry + per-layer legends (live or static). Tests for parse/mapping/assembly.

### M4 — Renderer + three overlay surfaces
`KeyboardRenderer` draws the split Totem + legends. Menu bar + always-visible corner overlay +
transient HUD on change, all from one `LayerStore`. Click-through, non-activating, always-on-top.
Tests: view-model + HUD state machine (inject the clock).

### M5 — Preferences + persistence + launch at login
Definition picker, re-sync button, per-surface toggles (default all on), **draggable overlay position
+ opacity control (user-requested 2026-07-04, do first)**, HUD duration, layer-name overrides,
`SMAppService` login item. Persisted settings + tests.
> **First M5 increment (user-requested):** drag the corner overlay to reposition + adjust its opacity,
> both **persisted** so they survive relaunch. Design note: a draggable overlay can't also be
> click-through on itself (clicks move it) — default the overlay to draggable, keep the HUD click-through. (Per-layer
color/icon deferred.)

### M6 — Packaging, docs, polish
`.app`, ad-hoc sign, login item that **registers + survives reboot**, DMG, full README setup path,
end-to-end manual checklist. May fold into M5 only if thin.

---

## Testing strategy
- **Swift:** XCTest. Pure logic in `SplitForgeCore` (no IOKit/AppKit) → fully unit-tested; put
  `IOHIDManager` behind a protocol + mock. Run: `cd macapp && swift test`.
  - **`swift test | tail -3` LIES about the count:** after the real XCTest bundle (`Executed 88 tests,
    with 0 failures`), an *empty second swift-testing bundle* prints `✔ Test run with 0 tests … passed`.
    `tail -3` shows only that trailing `0 tests` line. Use `tail -8`, or `grep 'Executed .* tests'`, to
    read the true total. (Bit a critic 2026-07-04 — it nearly reported "0 tests".)
- **Firmware:** host-side harness asserts each layer's report + a manual flash-and-switch checklist.

## Verification (end-to-end)
1. Flash `.uf2`; normal typing + **Vial web still connects**.
2. Launch app; grant **Input Monitoring**; connect → keymap read + Totem shape renders.
3. Switch layers → menu bar + corner overlay + HUD update.
4. Remap in Vial → **Re-sync** → legend updates.
5. `swift test` green. 6. Drop in a 2nd definition JSON → selectable (extensibility check).

## Risks & assumptions
Vial coexistence (top risk, proven in M0); keycode-label coverage (raw-name fallback); Input
Monitoring permission; initial-layer sync (post_init; first report is truth); geometry bundled not
live (v1); no-matching-device rests in a calm state; **wired RP2040 Vial build confirmed** (wireless
nRF52840/ZMK would need a different approach).

---

## Gotchas for agents (hard-won — read before touching related code)

**Firmware / Vial**
- **The three I²C defines must travel together (F3):** the Totem builds against board
  `GENERIC_PROMICRO_RP2040`, whose `configs/config.h` supplies *guarded* fallbacks `I2C_DRIVER I2CD1`,
  `I2C1_SDA_PIN GP2`, `I2C1_SCL_PIN GP3` — and **`GP2`/`GP3` are Totem matrix columns 4 and 2**. The
  keymap's `config.h` is force-included *before* the board's, so ours win; drop any one of the three and
  I²C silently drives two live matrix columns. Symptom would be a dead/erratic column, not an I²C error.
- **No `halconf.h` is needed for I²C (F3):** `POINTING_DEVICE_DRIVER = cirque_pinnacle_i2c` sets
  `I2C_DRIVER_REQUIRED = yes`, which emits `-DHAL_USE_I2C=TRUE` (`builddefs/common_features.mk:1005–1007`);
  the common `halconf.h` guard is `#if !defined(HAL_USE_I2C)`, so the `-D` wins. But `RP_I2C_USE_I2C0 FALSE`
  is **unguarded**, so an `mcuconf.h` override *is* required.
- **`mcuconf.h` belongs in the KEYMAP dir (F3):** there is no `MCUCONFDIR` make variable — unlike
  `halconf.h`/`chconf.h`, which resolve only from `KEYBOARD_PATH_1..5`. `mcuconf.h` is found purely by `-I`
  order, and the keymap dir is `-I` entry #1 (board configs are #8), so `#include_next <mcuconf.h>` chains
  correctly. This is what keeps `firmware/totem/` a keymap overlay rather than a firmware fork.
- **`SPLIT_POINTING_ENABLE`'s 1 ms throttle does NOT apply to a cirque build (F3)** — the opposite of
  what the header ordering suggests at a glance. `pointing_device.h:54` includes `cirque_pinnacle.h`
  *before* its own `SPLIT_POINTING_ENABLE` fallback at `:130–134`, and `cirque_pinnacle.h:56–57` already
  sets `POINTING_DEVICE_TASK_THROTTLE_MS 10` under the same `#if !defined` guard, so the 1 ms branch is
  dead. Verified by counterfactual preprocessing: deleting our define still yields 10. We set it
  explicitly anyway so the split link's traffic budget — shared with F1's per-key `0xCC 0x02` reports —
  is stated in our config rather than inherited from driver include order.
- **Never define `raw_hid_receive()`** in the keymap — Vial/VIA owns it; overriding causes a compile
  conflict (vial-qmk issue #538). We are **send-only**; the host is a VIA *client* for reads.
- Layer broadcast uses a **`0xCC` magic first byte** so it's distinguishable from Vial/VIA responses
  (whose command IDs are low, e.g. `0x01/0x11/0x12`). Host filters on `byte0==0xCC && byte1==0x01`.
- `RAW_EPSIZE` may not be visible to keymap code depending on the board → we guard it:
  `#ifndef RAW_EPSIZE #define RAW_EPSIZE 32`. See `firmware/totem/keymap_broadcast.c`.
- Include is `#include "raw_hid.h"` (not `raw.h`). `raw_hid_send(buf, len)` takes a 32-byte buffer.
- **Hook `process_record_kb`, NOT `process_record_user`, for the key-press broadcast (F1):** the Vial
  keymap (`keyboards/geigeigeist/totem/keymaps/vial/keymap.c`) *already defines* `process_record_user`,
  so adding a second one **link-errors** (`multiple definition of process_record_user`). The
  keyboard-level `process_record_kb` is undefined by the keymap → hook that, broadcast the matrix
  position, then `return process_record_user(keycode, record)` to run the keymap's own handler and
  propagate its continue/halt verdict unchanged. Broadcast fires **before** that call, so a key the
  keymap swallows is still highlighted (physical press did happen — desired). Combos/virtual events use
  sentinel `row/col` (255) ⇒ the `< MATRIX_ROWS/COLS` guard skips them; no real Totem key is ≥ row 8 /
  col 5, so none is dropped.
- Totem for Vial = **wired RP2040**. Left half is a stock **XIAO RP2040**; since F3 the right half is an
  **RP2040-Zero** on an adapter that maps every net to the same GPIO number the XIAO used, so the matrix
  and split-serial pin definitions are identical on both halves — only the spare GPIOs differ (GP12/GP13
  carry the trackpad's I²C0 bus). The wireless XIAO **nRF52840 runs ZMK**, not Vial/QMK —
  raw HID over USB does **not** apply there; that's a different project.
- **This Totem is a TWO-controller split with `EE_HANDS`** (`keyboards/geigeigeist/totem/config.h`;
  handedness in EEPROM). Build BOTH handed images and flash each half its own:
  `make geigeigeist/totem:vial:uf2-split-left` and `:uf2-split-right` (each overwrites
  `geigeigeist_totem_vial.uf2` in the qmk root — copy it out between builds). **Only the USB-connected
  (master) half speaks Raw HID**, so the layer broadcast comes from whichever half is plugged into the
  Mac; layer logic runs on the master and syncs to the slave, so the broadcast is correct regardless
  of which side is plugged in. Vial keymap: `keyboards/geigeigeist/totem/keymaps/vial/` (VIA+VIAL
  already on ⇒ RAW_ENABLE implied; we add it explicitly plus `SRC += keymap_broadcast.c`).
  - **`:uf2-split-left`/`:uf2-split-right` are FLASH targets, not build-only** — they compile, copy
    `geigeigeist_totem_vial.uf2` to the qmk root, then **block on `Flashing for bootloader: rp2040`**
    waiting for an `RPI-RP2` device forever. To get files without a keyboard attached: run the target,
    grab the `.uf2` from the qmk root once the log says `Copying …[OK]`, then kill the process.
    Handedness is baked at compile time (`INIT_EE_HANDS_LEFT/RIGHT` in `quantum/split_common/
    split_util.c`), so the left and right `.uf2`s differ by MD5 — that's the correctness check.
  - A full RP2040 build takes **well over 6–7 min**; don't run it under a short foreground timeout.
- **Firmware build toolchain (macOS) — full recipe, verified 2026-07-03:**
  - Install: `brew trust qmk/qmk`; `brew tap osx-cross/arm && brew trust osx-cross/arm`;
    `brew tap osx-cross/avr && brew trust osx-cross/avr`; then `brew install qmk/qmk/qmk`. Modern
    Homebrew refuses **each** untrusted tap (`Refusing to load formula … from untrusted tap`); the
    qmk formula pulls its ARM+AVR compilers from the `osx-cross/*` taps, so all three need trusting.
  - `qmk: command not found` = CLI missing; after install `qmk --version` prints `1.1.8`.
  - The brew `qmk` CLI only exposes `config/clone/console/env/setup` **until** you run
    `qmk config user.qmk_home="$PWD"` inside a vial-qmk checkout — that unlocks
    `compile/git-submodule/list-keyboards/doctor` (they load from the repo).
  - The ARM toolchain is **two** keg-only formulae, both needed on PATH (the `qmk` wrapper does NOT
    add them): `arm-none-eabi-gcc@8` (compiler) **and** `arm-none-eabi-binutils` (`ar`/`ld`/`objcopy`).
    Missing binutils fails late, at archiving: `sh: arm-none-eabi-ar: command not found`. Use:
    `export PATH="/opt/homebrew/opt/arm-none-eabi-gcc@8/bin:/opt/homebrew/opt/arm-none-eabi-binutils/bin:$PATH"`
    A full RP2040 build is slow (many minutes) — run it un-timed; add `-j"$(sysctl -n hw.ncpu)"`.
  - Build: `qmk compile -kb <totem-path> -km vial` → `.uf2`. Flash: drag `.uf2` → `RPI-RP2` drive
    (no picotool/dfu tool needed). Anaconda's Python doesn't interfere (formula is self-contained).
  - Trap: piping `brew install … | tail` masks brew's real exit code — check the true status.

**Legends / labeling**
- **Shifted symbols (`1`→`!`) are host-derived, US-ANSI, NOT from the keymap (F2):** the shifted
  legend is a fixed property of the base HID keycode under US-ANSI — it's neither stored in the keymap
  buffer nor broadcast. Vial hard-codes the same table; we mirror it in `KeycodeLabeler.shiftedSymbol`
  (21 pairs). Derive it from the **tap** (`keycode & 0xFF`) so it flows through mod-taps/layer-taps too;
  return nil for letters (primary is already uppercase — even under a Shift hold), the bare `L{n}`
  layer-tap (`kc==0`), layer-switches, and `KC_NONUS_HASH` (`0x32`, absent on US-ANSI). A non-US OS
  input source would technically shift differently — out of scope, same as Vial.
- **Three legends on one 1u key is the NORM on layered boards (F2):** a number-row `MT(mod, KC_n)` key
  shows primary (center) + hold (top-right) + shifted (top-left) at once. Keep the two sub-labels in
  **opposite** top corners, each with its own shrink-to-fit + skip-if-too-big guard, and shrink the
  center label when either is present. The shifted glyph is always a single char, so it can't collide
  with the hold glyph in practice.

**macOS / IOKit**
- `IOHIDManager` reads require **Input Monitoring** permission. `IOHIDManagerOpen` returns
  `kIOReturnNotPermitted` (not a crash) when denied — detect it and guide the user. The permission
  applies to the *host process* (the terminal for the spike; the .app later).
- Match the raw HID interface by **usage page `0xFF60` + usage `0x61`** (`kIOHIDDeviceUsagePageKey`/
  `kIOHIDDeviceUsageKey`), **not** the keyboard usage page — a QMK device exposes several interfaces.
- Sends to the board use `IOHIDDeviceSetReport(device, kIOHIDReportTypeOutput, reportID: 0, …)` with a
  32-byte payload (no leading report-ID byte — that maps to hidapi's `hid_write`).
- **SDK quirk (macOS 26 / Swift 6.3):** the input-report callback's `report` parameter is a
  **non-optional** `UnsafeMutablePointer<UInt8>` — do NOT `guard let report else …` (won't compile).
  `length` is `CFIndex`. The `context` pointer *is* optional.
- Input-report buffers passed to `IOHIDDeviceRegisterInputReportCallback` must **outlive** the
  registration — keep a strong reference (the spike stores them in an array).

**SwiftPM**
- Use **`// swift-tools-version: 5.9`** so the package defaults to **Swift 5 language mode** even on a
  Swift 6.3 compiler. Swift 6 strict concurrency otherwise errors on the IOKit C-callback bridging
  (`Unmanaged`, global run-loop state) in `splitforge-spike`.
- Link frameworks explicitly for the IOKit target: `.linkedFramework("IOKit")`,
  `.linkedFramework("CoreFoundation")`.
- Keep `SplitForgeCore` **Foundation-free where possible** (pure logic) so it stays trivially testable
  and portable. `String(format:)` (needs Foundation) lives only in the spike, not core.

**VIA protocol**
- `get_buffer` (`0x12`) max data per report = **28 bytes** (`reportSize 32 − 4 header bytes`). Keymap
  is **16-bit big-endian keycodes**, ordered **layer-major → row-major → col**:
  `offset(layer,row,col) = (layer*ROWS*COLS + row*COLS + col) * 2`.
- `ROWS/COLS` come from the `KeyboardDefinition`, not from VIA. Layer count via `get_layer_count`
  (`0x11`) is the *dynamic keymap* max (often 16), not necessarily how many the user actually uses.
- **VialClient completion correlation (M2):** register ALL expected chunk offsets *before* sending any
  request — otherwise a synchronously-delivered response trips `filled == expected` on the first chunk
  and fires `.complete` early (a real bug caught by the duplicate-chunk test). Route inbound reports by
  `bytes[0]` (0xCC broadcast / 0x11 count / 0x12 buffer); ignore duplicate **and short/truncated**
  chunks (leave them unfilled so a host-side `timedOut()` surfaces `.incomplete` for `resync()`).
- **Bundled keyboard definitions are GENERATED, not hand-edited (M3):** run
  `python3 tools/gen_totem_definition.py <keyboard.json> macapp/Sources/SplitForgeCore/Resources/totem.json`
  (38 keys, 8×5). Regenerate if the board's layout changes — don't transcribe by hand (the right-half
  column reversal is easy to get wrong). Loaded via `Bundle.module` (`SplitForgeCore` has
  `resources: [.process("Resources")]`); `Bundle.module` binds to the module where `DefinitionLoader`
  is compiled, so it resolves the resource even when called from the test target.
- **App surfaces (M4):** one `LayerStore` (active layer + `KeyboardModel`) drives menu bar + corner
  overlay + transient HUD. HUD timing = the timer-free `HUDViewModel` (token supersede); the app owns
  the single `Timer`. Overlay panels: `.borderless`+`.nonactivatingPanel`, `level=.statusBar`,
  `ignoresMouseEvents=true` (click-through), `canJoinAllSpaces`. **Dual-function keys** draw tap
  (`decode().primary`) + a corner hold sub-label (`decode().hold`: ⌘/⌥/⌃/⌘ for MT, `L#` for LT),
  shrink-to-fit. `swift run`/direct-binary hosts the menu-bar app fine on this machine (Input Monitoring
  attaches to the binary path; grant persists across rebuilds at the same path).
- **Packaging (M6):** `tools/build_app.sh` assembles the `.app`. The SwiftPM resource bundle
  (`SplitForge_SplitForgeCore.bundle`) MUST go in **`Contents/Resources/`** (where `Bundle.module`
  resolves via `Bundle.main.resourceURL`), not `Contents/MacOS/`. It's **data-only** (no Mach-O), so it
  can't be `codesign`ed separately ("bundle format unrecognized") — sign only the `.app`, which seals it
  as a resource. Keep `codesign --verify` on **its own line**: in an `&&` list it's exempt from `set -e`,
  so a bad signature would silently install. Ad-hoc sig changes per rebuild ⇒ TCC may need
  `tccutil reset ListenEvent com.splitforge.app` to re-prompt for Input Monitoring.

**Verified on hardware (2026-07-03)**
- Totem **USB VID/PID = `0x3A3C` / `0x0002`**, product string `TOTEM`. Dynamic-keymap **layer count = 16**;
  matrix = **8×5** (split: left rows 0–3, right rows 4–7; 40 cells/layer, **38 keys**; unused `[3,1]`
  & `[7,1]` read as `KC_TRNS 0x0001`). **Right half's cols run OPPOSITE to x** (`[4,4]`@x=9 … `[4,0]`@x=13).
  Wire this VID/PID into HID matching + the KeyboardDefinition. (M2's spike used a cosmetic 4×10 — same
  1280-byte buffer, but 8×5 is the real matrix→key mapping; M3+ uses 8×5 from the definition.)
- Base keymap uses **home-row mods**: layer 0 shows `0x2804`=MT(GUI,A), `0x2416`=MT(ALT,S),
  `0x2107`=MT(CTL,D), `0x2209`=MT(SFT,F). ⇒ the M2 `KeycodeLabeler` **must** decode mod-tap (`0x2xxx`)
  and layer-tap (`0x4xxx`), not just basic keycodes. Also saw `0x5221`-style codes → keep a hex fallback.
- Live VIA keymap read works: full buffer (offsets 0…1260, 16 layers) read cleanly **while the layer
  broadcast streamed** — the two channels coexist. (Vial web app + our reads simultaneously still
  unconfirmed; mitigation: retry + manual re-sync.)

**Toolchain (this machine)**: Swift 6.3.2, Xcode at `/Applications/Xcode.app`, git 2.50.1.
Build/test: `cd macapp && swift build && swift test`. Run spike: `swift run splitforge-spike`.
