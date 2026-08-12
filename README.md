# split-forge

A native macOS app that renders your **Totem** split keyboard on screen and shows **what each key does
on the currently active layer**, in real time — so you build a mental map of your layers over time.
Home-row mods and layer-taps show both their tap and hold functions. Data-driven, so other keyboards
can be added via a JSON definition (no code).

## The two pieces

The active layer lives inside the keyboard firmware — neither macOS nor stock Vial exposes live
layer-change events. So split-forge is:

1. **Firmware** — a tiny addition to your Totem Vial/QMK keymap that broadcasts the active layer over
   Raw HID on every change (`firmware/`). See [docs/flashing.md](docs/flashing.md).
2. **macOS app** — listens for that broadcast and reads your keymap live over the Vial/VIA protocol,
   then draws the Totem shape with the active layer's legends (`macapp/`). See
   [docs/PROTOCOL.md](docs/PROTOCOL.md).

## Install the app

1. **Flash the firmware** to your Totem — see [docs/flashing.md](docs/flashing.md).
2. **Build & install** the app:
   ```sh
   ./tools/build_app.sh
   ```
   This release-builds, packages `SplitForge.app` (a menu-bar agent — no dock icon), ad-hoc signs it,
   and installs it to `/Applications` (falls back to `~/Applications` if that isn't writable).
3. **Launch "SplitForge"** from Spotlight/Launchpad. It appears in the menu bar (`⌨ L0`).
4. **Grant Input Monitoring** on first run: System Settings → Privacy & Security → Input Monitoring →
   enable SplitForge. (This is required to read the keyboard over HID.)

Once connected, the overlay draws your Totem with the active layer's legends. Switch layers and the
overlay glows blue. **Drag** the overlay to reposition it; set its **opacity** and **Reset Position**
from the menu bar.

> **If a rebuild/reinstall stops reading the keyboard** (ad-hoc signatures change per build, and macOS
> may not re-prompt): reset its Input Monitoring entry and relaunch —
> `tccutil reset ListenEvent com.splitforge.app`, then re-grant.

## Development

```sh
cd macapp
swift build
swift test                 # SplitForgeCore unit tests (no hardware needed)
swift run splitforge-spike # end-to-end HID spike; needs Input Monitoring
```

`splitforge-spike` matches a Raw HID device on usage page `0xFF60` / usage `0x61` (defaults to the
Totem's VID/PID; pass `--vid 0xXXXX --pid 0xYYYY` or `--any` to override).

## Contributing

All changes follow [AGENTS.md](AGENTS.md) — plan → simplicity-critic loop → approval → implement with
tests → fresh-critic-per-round review until every file is approved. The living plan and milestone
status are in [plan/PLAN.md](plan/PLAN.md).
