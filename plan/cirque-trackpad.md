# Cirque 40 mm trackpad on the right half

Status: **approved 2026-09-12, implemented — awaiting hardware verification.**
Critic rounds 1–3 applied; round 3 approved the architecture unchanged. Follows [`AGENTS.md`](../AGENTS.md).

---

## Hardware (already validated — not part of this change)

- The right half's XIAO RP2040 is replaced by a **Waveshare RP2040-Zero** on a hand-wired adapter
  mapping every Totem net to the **same GPIO number** the XIAO used. 14/14 links continuity-checked;
  all 38 keys verified across both halves, so the split serial link is good.
- Because the mapping is 1:1 by GPIO, `keyboard.json` `matrix_pins`, `SERIAL_USART_*` and `EE_HANDS`
  are **unchanged**, and the left half keeps its stock XIAO.
- Cirque **TM040040**, I²C mode (R1 unpopulated), kit's 4.7 kΩ pull-ups, address `0x2A` (driver default).
- Bus: **`GP12` = SDA, `GP13` = SCL**. On RP2040 that pair is **I²C0 only** (I²C1 SDA is
  GP2/6/10/14/18/22/26), so the `RP_I2C_USE_I2C0` override below is genuinely required.

## What has to change, and where

Verified against the local `vial-qmk` checkout and its real build artifacts:

| Fact | Source |
|---|---|
| `POINTING_DEVICE_DRIVER = cirque_pinnacle_i2c` sets `I2C_DRIVER_REQUIRED = yes`, emitting `-DHAL_USE_I2C=TRUE` and pulling in `i2c_master.c` | `builddefs/common_features.mk:149, 1005–1007` |
| The common `halconf.h` guard is `#if !defined(HAL_USE_I2C)`, so that `-D` wins — **no `halconf.h` needed** | `platforms/chibios/boards/common/configs/halconf.h:88–89` |
| `RP_I2C_USE_I2C0 FALSE` is **unguarded**, so `-D` cannot override it — an `mcuconf.h` override **is** required | `platforms/chibios/boards/GENERIC_PROMICRO_RP2040/configs/mcuconf.h:99` |
| **No `MCUCONFDIR` make variable exists.** `mcuconf.h` is located purely by `-I` order, and the keymap dir is `-I` entry **#1** (board configs are #8) | `builddefs/build_keyboard.mk:538, 586`; real `cflags.txt` |
| The keymap's `config.h` is appended to `CONFIG_H` and force-included into every TU, `i2c_master.c` included | `builddefs/build_keyboard.mk:509`; real `-include` order |

**So every file stays in the keymap directory — `firmware/totem/` remains "a keymap overlay, not a
full firmware fork", and its README invariant is untouched.** In-tree precedent with this exact
driver: `keyboards/stront/keymaps/i2c/` ships `rules.mk` + `config.h` + a **keymap-level**
`mcuconf.h` using `#include_next`.

### The trap this design must avoid

The Totem builds against board **`GENERIC_PROMICRO_RP2040`**, whose `configs/config.h` supplies
*guarded* defaults `I2C_DRIVER I2CD1`, `I2C1_SDA_PIN GP2`, `I2C1_SCL_PIN GP3` — and **`GP2` and `GP3`
are Totem matrix columns 4 and 2.** Our keymap `config.h` is force-included *before* the board's
(verified in the real `-include` order), so our three defines win and the board's are skipped. But if
any one of them is dropped or lands somewhere not force-included, **I²C silently drives two live
matrix columns.** All three defines must move together. This is the Gotchas entry worth writing.

---

## Single milestone

A separate "bus-only" step was considered and rejected: `QUANTUM_LIB_SRC += i2c_master.c` sits inside
`ifeq ($(I2C_DRIVER_REQUIRED), yes)`, so without a driver requiring I²C nothing is compiled and
`i2cStart` is never called — such a build cannot discriminate the failure it would claim to isolate,
and a green result would be false confidence.

### Files

Every row below is **append/merge**, never overwrite — the real destinations already hold content
(`…/keymaps/vial/config.h` has `VIAL_KEYBOARD_UID`, `TAPPING_TERM`, `DYNAMIC_KEYMAP_LAYER_COUNT 16`;
`…/keymaps/vial/rules.mk` has `VIA_ENABLE`, `VIAL_ENABLE`, `RAW_ENABLE`, `SRC += keymap_broadcast.c`).

| File | Change | Merge into |
|---|---|---|
| `firmware/totem/mcuconf.h` | **new**, 4 lines — `#pragma once`, `#include_next <mcuconf.h>`, `#undef`/`#define RP_I2C_USE_I2C0 TRUE`. Write it; do not copy a third party's GPL header from `mini42`/`stront`. | `keyboards/geigeigeist/totem/keymaps/vial/` *(new file)* |
| `firmware/totem/config.h` | append `I2C_DRIVER I2CD0`, `I2C1_SDA_PIN GP12`, `I2C1_SCL_PIN GP13` — **all three together** | append to `…/keymaps/vial/config.h` |
| `firmware/totem/config.h` | append `SPLIT_POINTING_ENABLE`, `POINTING_DEVICE_RIGHT`, `POINTING_DEVICE_TASK_THROTTLE_MS 10`, `CIRQUE_PINNACLE_POSITION_MODE CIRQUE_PINNACLE_RELATIVE_MODE`, `CIRQUE_PINNACLE_TAP_ENABLE`, `CIRQUE_PINNACLE_SECONDARY_TAP_ENABLE` | ditto |
| `firmware/totem/rules.mk` | append `POINTING_DEVICE_ENABLE = yes`, `POINTING_DEVICE_DRIVER = cirque_pinnacle_i2c` | append to `…/keymaps/vial/rules.mk` |
| `firmware/totem/totem_vial_{left,right}.uf2` | rebuild both — the repo ships prebuilt hardware-validated images | flashed to both halves |
| `firmware/totem/README.md` | add an `mcuconf.h` row **and correct three now-false statements**: the opening sentence (`:3`, "A minimal, send-only Raw HID broadcast" — no longer all it does), the `config.h` row (`:10`, "QMK defaults; no override needed" — it now carries nine real defines, three hardware-critical), and the `rules.mk` row (`:9`, "ensures `RAW_ENABLE = yes`"). Also note the right half is now an RP2040-Zero, not a XIAO. | — |
| `docs/flashing.md` | **update the from-source recipe**, not the flashing steps. `:65–69` already covers reflashing both halves and `:52–56` already builds both handed images, so those need nothing. What goes stale is `:3` ("The only firmware change is a tiny Raw HID broadcast") and Build **step 3** (`:42–44`), which tells a rebuilder to add only `keymap_broadcast.c` + `RAW_ENABLE`. Left as-is it silently rebuilds firmware with **no trackpad**, and never mentions that `mcuconf.h` must be dropped into the **keymap** directory — the most surprising placement in this design. | — |
| `plan/PLAN.md` | status row + Gotchas (the GP2/GP3 trap; `-DHAL_USE_I2C=TRUE` comes from the driver, not a `halconf.h`) | — |
| `plan/cirque-trackpad.md` | this plan, moved out of the scratchpad on approval (repo names plans by topic: `key-highlight.md`, `shifted-legends.md`) | — |

`CIRQUE_PINNACLE_POSITION_MODE CIRQUE_PINNACLE_RELATIVE_MODE` is **load-bearing, not a preference**,
and must not be dropped by a later "remove non-default defines" pass. In *absolute* mode
`CIRQUE_PINNACLE_TAP_ENABLE` "currently only works on the master side"
(`docs/features/pointing_device.md:234`); in *relative* mode it "works on both sides of a split
keyboard" (`:246`, and `:201` — "supports taps on secondary side of split"). Checklist item 6
requires the **left** half on USB, which makes the pad the secondary side — so relative mode is what
keeps click working in that configuration. It also saves ~2 kB of flash.

Deliberately **not** set: `CIRQUE_PINNACLE_ADDR` (already `0x2A`) and `CIRQUE_PINNACLE_DIAMETER_MM`
(already `40`) — setting defaults is noise. `CIRQUE_PINNACLE_ATTENUATION` is left at its
`ADC_ATTENUATE_4X` default, correct for a flat overlay.
`CIRQUE_PINNACLE_SKIP_SENSOR_CHECK` stays undefined.
`POINTING_DEVICE_TASK_THROTTLE_MS 10` is **explicit rather than required**. `pointing_device.h`
includes `cirque_pinnacle.h` at `:54`, *before* its own `SPLIT_POINTING_ENABLE` fallback of 1 ms at
`:130–134`, and `cirque_pinnacle.h:56–57` already sets 10 under the same `#if !defined` guard — so the
1 ms fallback never fires in a cirque build. (Verified by counterfactual preprocessing: removing the
define still yields 10.) Pinned anyway so the split link's traffic budget — shared with F1's per-key
`0xCC 0x02` reports — is stated in our own config rather than inherited from driver include order.

**No host-side change.** `POINTING_DEVICE_ENABLE` forces `MOUSE_ENABLE`, and `MOUSE_SHARED_EP ?= yes`
(`tmk_core/protocol.mk:8, 21`), so the mouse report rides the **shared** HID interface — it does not
get its own. Raw HID remains a separate interface matched on usage page `0xFF60`/usage `0x61`, so
split-forge's match is untouched.

## Tests

AGENTS.md §5's carve-out applies: this milestone changes **no host code**, so there is nothing to unit
test — `macapp/` is untouched and the existing 100 tests are the post-implementation critic's §8
obligation to re-run, not a feature check for this change. Verification is therefore the build gate
below plus a hardware checklist, matching the precedent F1 set in `plan/key-highlight.md`
("Verification (by running)"). No `verify_*.sh` is committed: `tools/` holds only build/gen helpers,
and a hardware-dependent script cannot be re-run by a fresh critic anyway, which is the point of §8.

**Build gate — runs without hardware, so a critic can execute it.** From the vial-qmk checkout:

```
qmk compile -kb geigeigeist/totem -km vial
```

then assert `.build/obj_geigeigeist_totem_vial/cflags.txt` (path relative to vial-qmk) contains
`-DPOINTING_DEVICE_ENABLE` and `-DHAL_USE_I2C=TRUE`. Both are absent from the current pre-trackpad
build, so this genuinely discriminates. `cflags.txt` is regenerated every build via a `force`
dependency (`builddefs/common_rules.mk:330–331`), so it cannot pass on stale content. A missing
`RP_I2C_USE_I2C0` override fails at **compile** in `i2c_master.c` (ChibiOS never declares `I2CD0`),
so a clean build is itself part of the assertion.

Do **not** use `make …:uf2-split-right` as the gate — `platforms/chibios/flash.mk:64` makes it a
*flashing* target that blocks waiting for an `RPI-RP2` device. It is still the only route to the
**handed** images the Files table requires (`qmk compile` emits a single non-handed image, useless
under `EE_HANDS`); use the recipe already documented in `plan/PLAN.md` — run the target, take
`geigeigeist_totem_vial.uf2` from the qmk root once the log says `Copying …[OK]`, then kill it.

**Hardware checklist.** Each item discriminates a specific failure:

1. All 38 keys still register, both halves — the real catch here is the **GP2/GP3 trap**: if any of
   the three I²C defines went missing, the board defaults would put I²C on two live matrix columns
   and this item is what surfaces it.
2. `vial.rocks` connects and reads the keymap — catches a Vial handshake broken by the changed
   descriptor set.
3. split-forge overlay still tracks layer changes **and** per-key highlights — F1 shares the Raw HID
   channel with the new mouse traffic.
4. **Pointer moves in the correct direction** — up is up, right is right. A hand-mounted pad will
   likely need `POINTING_DEVICE_ROTATION_90/180/270` or `POINTING_DEVICE_INVERT_X/Y`; settle it in
   this flash cycle. This is also the item that detects a wiring fault (see Risks).
5. Tap and upper-right corner-tap register as left/right click.
6. **Both master configurations** — right half on USB (local sensor read) and left half on USB (every
   mouse delta crosses the serial link). The second is the only path that stresses the split
   transport, and is where the throttle decision bites; re-check item 3's latency there.

## Risks

| Risk | Reality / mitigation |
|---|---|
| Pad not detected | `cirque_pinnacle_i2c.c:16–33` guards every access with `if (touchpad_init)` and latches it **false** on the first I²C error, so the failure is quiet and self-limiting — *not* a stream of timeouts, and not a threat to the split link. It presents as "pointer never moves", caught by checklist item 4. |
| Mouse traffic starves F1's per-key reports or the layer broadcast | Throttle pinned to 10 ms; checklist items 3 and 6 |
| One of the three I²C defines dropped | Board defaults would silently put I²C on **GP2/GP3 — live matrix columns**. Keep the three together; Gotchas entry |
| Repo's committed `.uf2`s go stale | Both rebuilt and committed in this milestone |
| Left half runs older firmware | Both halves reflashed together, as with F1; called out in `docs/flashing.md` |

## Out of scope

Case/print work; the left half's controller; `CIRQUE_PINNACLE_CURVED_OVERLAY` (flat pad); any
split-forge host change; scroll-mode or drag-lock keymap behaviours.
