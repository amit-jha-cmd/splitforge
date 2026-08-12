/// Translates 16-bit QMK keycodes into short, human-readable labels for the overlay.
///
/// Covers the common/observed keycode families with a raw-hex fallback so an unrecognized
/// code degrades to a less-pretty label instead of crashing or blocking a render. Bit layouts
/// differ per family (see the QMK quantum-keycode ranges), so each is decoded separately:
///   - QK_MODS   `0x0100–0x1FFF`  modified keycode  → base key
///   - MT        `0x2000–0x3FFF`  mod-tap           → tap key (e.g. home-row mods)
///   - LT        `0x4000–0x4FFF`  layer-tap         → tap key, or `L{n}` if no tap key
///   - TO/MO/DF/TG/OSL/TT `0x5200–0x52DF` layer switches → `L{n}`
public enum KeycodeLabeler {
    /// A key's label(s): the tap `primary`, plus an optional `hold` (modifier or layer) for
    /// dual-function keys (mod-taps, layer-taps, modified keycodes), plus an optional `shifted`
    /// legend (the US-ANSI Shift symbol for the tap key, e.g. `1`→`!`) — shown like Vial does.
    public struct KeyLabel: Equatable {
        public let primary: String
        public let hold: String?
        public let shifted: String?
        public init(primary: String, hold: String? = nil, shifted: String? = nil) {
            self.primary = primary
            self.hold = hold
            self.shifted = shifted
        }
    }

    /// The tap label only (back-compat; equals `decode(_:).primary`).
    public static func label(_ keycode: UInt16) -> String { decode(keycode).primary }

    /// Full decode: tap `primary` plus optional `hold` for mod-taps / layer-taps / modified keycodes.
    public static func decode(_ keycode: UInt16) -> KeyLabel {
        switch keycode {
        case 0x0000:
            return KeyLabel(primary: "")            // KC_NO
        case 0x0001:
            return KeyLabel(primary: "▽")           // KC_TRNS
        case 0x0002...0x00FF:
            let kc = UInt8(keycode & 0xFF)
            return KeyLabel(primary: basicLabel(kc) ?? hex(keycode), shifted: shiftedSymbol(kc))
        case 0x0100...0x1FFF:    // QK_MODS: base key sent with a modifier chord
            let kc = UInt8(keycode & 0xFF)
            return KeyLabel(primary: basicLabel(kc) ?? hex(keycode),
                            hold: modGlyphs(UInt8((keycode >> 8) & 0x1F)),
                            shifted: shiftedSymbol(kc))
        case 0x2000...0x3FFF:    // MT(mod, kc): tap key / hold modifier
            let kc = UInt8(keycode & 0xFF)
            return KeyLabel(primary: basicLabel(kc) ?? hex(keycode),
                            hold: modGlyphs(UInt8((keycode >> 8) & 0x1F)),
                            shifted: shiftedSymbol(kc))
        case 0x4000...0x4FFF:    // LT(layer, kc): tap key / hold layer
            let layer = (keycode >> 8) & 0x0F
            let kc = UInt8(keycode & 0xFF)
            let primary = kc == 0 ? "L\(layer)" : (basicLabel(kc) ?? hex(keycode))
            // Only a real tap key carries a shifted legend; the bare `L{n}` form (kc == 0) doesn't.
            return KeyLabel(primary: primary, hold: "L\(layer)",
                            shifted: kc == 0 ? nil : shiftedSymbol(kc))
        case 0x5200...0x529F, 0x52C0...0x52DF:   // TO/MO/DF/TG/OSL (0x5200–0x529F) and TT (0x52C0–0x52DF)
            return KeyLabel(primary: layerLabel(keycode))
        default:
            return KeyLabel(primary: hex(keycode))
        }
    }

    /// Layer for the 0x20-aligned layer-switch ranges = low 5 bits.
    private static func layerLabel(_ keycode: UInt16) -> String {
        "L\(keycode & 0x1F)"
    }

    /// Modifier glyph(s) for a 5-bit mod field, in fixed order `⌃⇧⌥⌘`. Bit 0x10 (right-hand) ignored.
    private static func modGlyphs(_ mod: UInt8) -> String? {
        let mask = mod & 0x0F
        guard mask != 0 else { return nil }
        var glyphs = ""
        if mask & 0x01 != 0 { glyphs += "⌃" }   // ctrl
        if mask & 0x02 != 0 { glyphs += "⇧" }   // shift
        if mask & 0x04 != 0 { glyphs += "⌥" }   // alt
        if mask & 0x08 != 0 { glyphs += "⌘" }   // gui
        return glyphs.isEmpty ? nil : glyphs
    }

    /// Basic HID keycodes (`0x00–0xFF`). Returns nil for codes not worth a pretty label
    /// (caller falls back to hex).
    private static func basicLabel(_ code: UInt8) -> String? {
        switch code {
        case 0x04...0x1D:                       // A–Z
            return String(Character(UnicodeScalar(UInt8(0x41 + Int(code) - 0x04))))
        case 0x1E...0x26:                       // 1–9
            return String(Int(code) - 0x1D)
        case 0x27: return "0"
        case 0x28: return "↵"
        case 0x29: return "Esc"
        case 0x2A: return "⌫"
        case 0x2B: return "⇥"
        case 0x2C: return "Spc"
        case 0x2D: return "-"
        case 0x2E: return "="
        case 0x2F: return "["
        case 0x30: return "]"
        case 0x31: return "\\"
        case 0x32: return "#"
        case 0x33: return ";"
        case 0x34: return "'"
        case 0x35: return "`"
        case 0x36: return ","
        case 0x37: return "."
        case 0x38: return "/"
        case 0x39: return "Caps"
        case 0x3A...0x45: return "F\(Int(code) - 0x39)"        // F1–F12
        case 0x46: return "PrtSc"
        case 0x47: return "ScrLk"
        case 0x48: return "Pause"
        case 0x49: return "Ins"
        case 0x4A: return "Home"
        case 0x4B: return "PgUp"
        case 0x4C: return "Del"
        case 0x4D: return "End"
        case 0x4E: return "PgDn"
        case 0x4F: return "→"
        case 0x50: return "←"
        case 0x51: return "↓"
        case 0x52: return "↑"
        case 0x53: return "Num"
        case 0x54: return "KP/"
        case 0x55: return "KP*"
        case 0x56: return "KP-"
        case 0x57: return "KP+"
        case 0x58: return "KP↵"
        case 0x59...0x61: return "KP\(Int(code) - 0x58)"       // KP1–KP9
        case 0x62: return "KP0"
        case 0x63: return "KP."
        case 0x65: return "App"
        case 0x68...0x73: return "F\(Int(code) - 0x68 + 13)"   // F13–F24
        case 0xE0, 0xE4: return "Ctrl"
        case 0xE1, 0xE5: return "Shift"
        case 0xE2, 0xE6: return "Alt"
        case 0xE3, 0xE7: return "Cmd"
        default: return nil
        }
    }

    /// The **US-ANSI** shifted symbol for a basic HID keycode (`1`→`!`, `;`→`:`, …), matching what
    /// Vial shows. Returns nil for keys with no distinct shifted glyph: letters (their primary already
    /// renders uppercase), space/enter/nav/F-keys, and `KC_NONUS_HASH` (`0x32`, absent on US-ANSI).
    private static func shiftedSymbol(_ code: UInt8) -> String? {
        switch code {
        case 0x1E: return "!"   // 1
        case 0x1F: return "@"   // 2
        case 0x20: return "#"   // 3
        case 0x21: return "$"   // 4
        case 0x22: return "%"   // 5
        case 0x23: return "^"   // 6
        case 0x24: return "&"   // 7
        case 0x25: return "*"   // 8
        case 0x26: return "("   // 9
        case 0x27: return ")"   // 0
        case 0x2D: return "_"   // -
        case 0x2E: return "+"   // =
        case 0x2F: return "{"   // [
        case 0x30: return "}"   // ]
        case 0x31: return "|"   // backslash
        case 0x33: return ":"   // ;
        case 0x34: return "\""  // '
        case 0x35: return "~"   // grave
        case 0x36: return "<"   // ,
        case 0x37: return ">"   // .
        case 0x38: return "?"   // /
        default: return nil
        }
    }

    private static func hex(_ v: UInt16) -> String {
        let digits = Array("0123456789ABCDEF")
        var out = "0x"
        var shift = 12
        while shift >= 0 {
            out.append(digits[Int((v >> UInt16(shift)) & 0x0F)])
            shift -= 4
        }
        return out
    }
}
