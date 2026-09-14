# firmware/totem

A minimal, send-only Raw HID broadcast of the active layer, added on top of the standard
**Vial** firmware for the Totem (wired XIAO RP2040). Vial keeps working unchanged.

> **This board's split link runs HALF-DUPLEX on `D7`/`GP1`, not the stock full-duplex pair.**
> `D6`'s path is dead (pin, trace, jack pin or cable conductor — never isolated). Full duplex needs
> both `D6` and `D7` in *both* roles, so one dead line kills the link whichever half is plugged in —
> each half still types perfectly on its own, which makes it look like a firmware fault and isn't.
> The override lives in `config.h` as `#undef`s, so this stays a keymap overlay rather than a fork.
> **Do not restore the stock full-duplex lines.**

| file | purpose |
|------|---------|
| `keymap_broadcast.c` | the `layer_state_set_user` / `keyboard_post_init_user` broadcast (paste into `keymap.c`, or drop in + `SRC +=`) |
| `rules.mk` | ensures `RAW_ENABLE = yes` (merge into your keymap's `rules.mk`) |
| `config.h` | documents the Raw HID usage page/usage, **and overrides the split link to half-duplex on `D7`/`GP1`** (merge into your keymap's `config.h`) |

This directory is a **keymap overlay**, not a full firmware fork — you build it against a
[vial-qmk](https://github.com/vial-kb/vial-qmk) checkout. See [../../docs/flashing.md](../../docs/flashing.md)
for build + flash steps, and [../../docs/PROTOCOL.md](../../docs/PROTOCOL.md) for the wire format.

Prebuilt, hardware-validated images (built against vial-qmk for `geigeigeist/totem`, EE_HANDS):
**`totem_vial_left.uf2`** → flash to the **left** half, **`totem_vial_right.uf2`** → **right** half.
See [../../docs/flashing.md](../../docs/flashing.md).
