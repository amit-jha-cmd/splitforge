# firmware/totem

A minimal, send-only Raw HID broadcast of the active layer, added on top of the standard
**Vial** firmware for the Totem (wired XIAO RP2040). Vial keeps working unchanged.

| file | purpose |
|------|---------|
| `keymap_broadcast.c` | the `layer_state_set_user` / `keyboard_post_init_user` broadcast (paste into `keymap.c`, or drop in + `SRC +=`) |
| `rules.mk` | ensures `RAW_ENABLE = yes` (merge into your keymap's `rules.mk`) |
| `config.h` | documents the Raw HID usage page/usage (QMK defaults; no override needed) |

This directory is a **keymap overlay**, not a full firmware fork — you build it against a
[vial-qmk](https://github.com/vial-kb/vial-qmk) checkout. See [../../docs/flashing.md](../../docs/flashing.md)
for build + flash steps, and [../../docs/PROTOCOL.md](../../docs/PROTOCOL.md) for the wire format.

Prebuilt, hardware-validated images (built against vial-qmk for `geigeigeist/totem`, EE_HANDS):
**`totem_vial_left.uf2`** → flash to the **left** half, **`totem_vial_right.uf2`** → **right** half.
See [../../docs/flashing.md](../../docs/flashing.md).
