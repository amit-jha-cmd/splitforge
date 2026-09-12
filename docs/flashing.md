# Flashing the split-forge firmware (Totem, wired — XIAO RP2040 left / RP2040-Zero right)

There are two firmware changes on top of the standard **Vial** firmware (see `firmware/totem/`):
a tiny Raw HID broadcast of the active layer and pressed keys, and a **40 mm Cirque trackpad**
on the right half. Vial keeps working either way.

## Prerequisites (one-time): QMK CLI + ARM toolchain

Building for the RP2040 needs the `qmk` CLI and `arm-none-eabi-gcc`. On macOS with Homebrew it all
comes from the official QMK tap — but modern Homebrew blocks untrusted taps, and the `qmk` formula
pulls its ARM + AVR compilers from the `osx-cross/*` taps, so **trust all three first**:

```sh
brew trust qmk/qmk
brew tap osx-cross/arm && brew trust osx-cross/arm
brew tap osx-cross/avr && brew trust osx-cross/avr
brew install qmk/qmk/qmk           # qmk CLI + arm-none-eabi-gcc@8 + avr-gcc@8
qmk --version                      # sanity check (should print 1.1.8)
```

Two quirks of this setup:
- The `qmk` CLI only shows `config/clone/console/env/setup` **until** you point it at a firmware repo
  (next section). `compile`, `git-submodule`, `list-keyboards`, `doctor` appear only after that.
- `arm-none-eabi-gcc@8` is **keg-only** (not on PATH). Add it to PATH before building:
  ```sh
  export PATH="/opt/homebrew/opt/arm-none-eabi-gcc@8/bin:/opt/homebrew/opt/arm-none-eabi-binutils/bin:$PATH"
  ```

## Build

```sh
# 1. Clone Vial's QMK fork (once) and point qmk at it — this unlocks compile/git-submodule/etc.
git clone https://github.com/vial-kb/vial-qmk.git
cd vial-qmk
qmk config user.qmk_home="$PWD"
qmk git-submodule                  # the step that was failing; == git submodule update --init --recursive

# 2. Find your Totem's exact keyboard path
qmk list-keyboards | grep -i totem
#    If nothing prints, the Totem isn't in your vial-qmk — add its keyboard folder from the
#    GEIST TOTEM repo (https://github.com/GEIGEIGEIST/TOTEM) first.

# 3. Merge ALL FOUR overlay files into keyboards/<totem-path>/keymaps/vial/
#    (see firmware/totem/README.md — every one lands in the KEYMAP directory):
#      keymap_broadcast.c -> drop in, and add `SRC += keymap_broadcast.c` to rules.mk
#                            (or paste its functions into keymap.c)
#      rules.mk           -> append: RAW_ENABLE, POINTING_DEVICE_ENABLE, POINTING_DEVICE_DRIVER
#      config.h           -> append: the I2C pins + pointing-device/Cirque defines
#      mcuconf.h          -> copy in as-is; enables RP2040 I2C0, which the board ships off
#
#    The three I2C defines in config.h must be merged TOGETHER. The board config supplies
#    guarded fallbacks on GP2/GP3, which are Totem matrix columns 4 and 2 — omit one and
#    I2C quietly drives two live matrix columns.

# 4. Build (ensure the ARM compiler is on PATH — see Prerequisites)
export PATH="/opt/homebrew/opt/arm-none-eabi-gcc@8/bin:/opt/homebrew/opt/arm-none-eabi-binutils/bin:$PATH"

#    Single-controller board — one image:
qmk compile -kb <totem-path> -km vial

#    TWO controllers with EE_HANDS (e.g. geigeigeist/totem) — build a left- AND right-handed image
#    (handedness is baked into each; a plain flash can leave EEPROM handedness ambiguous). Output
#    lands in the qmk root as <kb-with-underscores>_vial.uf2, so copy each out before the next build:
make <totem-path>:vial:uf2-split-left  && cp geigeigeist_totem_vial.uf2 ~/totem_left.uf2
make <totem-path>:vial:uf2-split-right && cp geigeigeist_totem_vial.uf2 ~/totem_right.uf2
```

## Flash

Enter bootloader on a half: connect **that half** to USB, then **hold `B`/BOOT and tap `R`/RESET**
(or plug it in while holding BOOT). It mounts as an `RPI-RP2` drive; **drag the `.uf2` on** and it
reboots automatically.

- **Single controller:** flash the one `.uf2`.
- **Two controllers + EE_HANDS (this Totem):** flash **`totem_left.uf2` → the left half** and
  **`totem_right.uf2` → the right half**, connecting each half to USB in turn. During normal use,
  plug **one** half into the Mac — that half becomes the master and is the one that sends the layer
  broadcast (the slave's key/layer state is synced to the master over the split link).

## Verify

- The keyboard types normally and **Vial web (vial.rocks) still connects**.
- Run the host spike and switch layers:
  ```sh
  cd macapp && swift run splitforge-spike
  ```
  Grant **Input Monitoring** when macOS prompts (System Settings → Privacy & Security → Input
  Monitoring). You should see `⬆️ Active layer: N` on layer changes and a `🗺 Keymap @0: …` dump,
  and note the VID/PID the spike prints on connect.

### Trackpad (right half)

- **All 38 keys still register, both halves.** This is the check that catches the I²C pins having
  fallen back to the board defaults on `GP2`/`GP3` — Totem matrix columns 4 and 2 — which presents as
  a dead or erratic column, not as an I²C error.
- **The pointer moves in the correct direction** — up is up, right is right. A hand-mounted pad will
  often need `POINTING_DEVICE_ROTATION_90/180/270` or `POINTING_DEVICE_INVERT_X/Y`; settle it in the
  same flash cycle. A pad that is wired wrong or not detected presents as "pointer never moves": the
  driver latches itself off after the first I²C error rather than retrying.
- **Tap and upper-right corner-tap** register as left and right click.
- **Both master configurations.** Plug in the **right** half (pad read locally), then the **left**
  half (every mouse delta crosses the split link alongside the per-key reports). The second is the
  only case that stresses the split transport — re-check layer/key-highlight latency there.

> **Flashing resets your Vial keymap.** Under `VIAL_ENABLE` the VIA EEPROM magic is derived from
> Vial's `BUILD_ID`, which changes on every build (`quantum/via.c`), so a new image invalidates the
> stored dynamic keymap and it reverts to defaults. Export your layout from vial.rocks first — the
> repo keeps a copy at [`../my_totem.vil`](../my_totem.vil) — and re-import after flashing. This has
> always been true of a rebuild, not just of this change.
