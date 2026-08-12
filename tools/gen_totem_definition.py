#!/usr/bin/env python3
"""Generate a split-forge KeyboardDefinition JSON from a QMK keyboard.json.

Usage:
    python3 tools/gen_totem_definition.py <path/to/keyboard.json> <out.json> [--id totem]

Derives matrix dims from the layout's max row/col (so a split's doubled rows are captured),
converts the USB vid/pid hex strings to integers, and copies each key's matrix + x/y verbatim
(preserving the right-half column reversal — do NOT sort). w/h/rotation are omitted (defaults).
"""
import argparse
import json


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("keyboard_json")
    ap.add_argument("out")
    ap.add_argument("--id", default="totem")
    ap.add_argument("--layout", default="LAYOUT")
    args = ap.parse_args()

    with open(args.keyboard_json) as f:
        kb = json.load(f)

    layout = kb["layouts"][args.layout]["layout"]
    rows = max(k["matrix"][0] for k in layout) + 1
    cols = max(k["matrix"][1] for k in layout) + 1

    definition = {
        "id": args.id,
        "name": kb.get("keyboard_name", args.id.upper()),
        "usbVendorId": int(str(kb["usb"]["vid"]), 16),
        "usbProductId": int(str(kb["usb"]["pid"]), 16),
        "matrix": {"rows": rows, "cols": cols},
        "keys": [{"matrix": k["matrix"], "x": k["x"], "y": k["y"]} for k in layout],
    }

    with open(args.out, "w") as f:
        json.dump(definition, f, indent=2)
        f.write("\n")

    print(f"wrote {args.out}: {len(definition['keys'])} keys, "
          f"matrix {rows}x{cols}, vid={definition['usbVendorId']:#06x} pid={definition['usbProductId']:#06x}")


if __name__ == "__main__":
    main()
