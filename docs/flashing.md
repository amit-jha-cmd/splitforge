# Flashing the split-forge firmware (Totem, wired XIAO RP2040)

The only firmware change is a tiny Raw HID broadcast of the active layer (see `firmware/totem/`).
It builds on top of the standard **Vial** firmware for the Totem, so Vial keeps working.

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

# 3. Add the broadcast to keyboards/<totem-path>/keymaps/vial/ (see firmware/totem/README.md):
#    paste the two functions from keymap_broadcast.c into keymap.c, OR drop the file in and add
#    `SRC += keymap_broadcast.c` to that keymap's rules.mk. Ensure `RAW_ENABLE = yes`.

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
