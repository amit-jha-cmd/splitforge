# firmware/totem

Two additions on top of the standard **Vial** firmware for the Totem: a minimal, send-only
**Raw HID broadcast** of the active layer and pressed keys, and a **40 mm Cirque GlidePoint
trackpad** on the right half. Vial keeps working unchanged.

The right half's controller is an **RP2040-Zero** (wired to the Totem's XIAO footprint through an
adapter that maps every net to the same GPIO number the XIAO used, so the matrix and split-serial
pin definitions are untouched). The left half is still a stock **XIAO RP2040**.

| file | purpose |
|------|---------|
| `keymap_broadcast.c` | the `layer_state_set_user` / `keyboard_post_init_user` / `process_record_kb` broadcast (paste into `keymap.c`, or drop in + `SRC +=`) |
| `rules.mk` | `RAW_ENABLE = yes` plus `POINTING_DEVICE_ENABLE` / `POINTING_DEVICE_DRIVER = cirque_pinnacle_i2c` (merge into your keymap's `rules.mk`) |
| `config.h` | documents the Raw HID usage page/usage, **and** carries the live trackpad config: the I²C bus pins and the pointing-device / Cirque defines (merge into your keymap's `config.h`) |
| `mcuconf.h` | enables RP2040 **I²C0**, which the board config ships disabled and unguarded (drop into your keymap directory) |

> **The three I²C defines in `config.h` must travel together.** The board config
> (`GENERIC_PROMICRO_RP2040`) supplies *guarded* fallbacks `I2CD1` / `GP2` / `GP3` — and `GP2` and
> `GP3` are Totem matrix columns 4 and 2. Our `config.h` is force-included first so ours win; drop
> any one of them and I²C silently drives two live matrix columns.

Every file here lands in the **keymap** directory, so this directory is still a **keymap overlay**,
not a full firmware fork — you build it against a
[vial-qmk](https://github.com/vial-kb/vial-qmk) checkout. (`mcuconf.h` works from the keymap
directory because there is no `MCUCONFDIR` make variable: it is located purely by `-I` order, and
the keymap directory is `-I` entry #1.) See [../../docs/flashing.md](../../docs/flashing.md) for
build + flash steps, [../../docs/PROTOCOL.md](../../docs/PROTOCOL.md) for the wire format, and
[../../plan/cirque-trackpad.md](../../plan/cirque-trackpad.md) for why the trackpad is wired this way.

Prebuilt images (built against vial-qmk for `geigeigeist/totem`, EE_HANDS). **The current pair
carries the trackpad change and is not yet hardware-verified** — see the F3 row in
[`../../plan/PLAN.md`](../../plan/PLAN.md):
**`totem_vial_left.uf2`** → flash to the **left** half, **`totem_vial_right.uf2`** → **right** half.
**Both halves must be reflashed together.**
See [../../docs/flashing.md](../../docs/flashing.md).
