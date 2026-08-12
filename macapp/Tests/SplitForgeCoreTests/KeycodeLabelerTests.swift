import XCTest
@testable import SplitForgeCore

final class KeycodeLabelerTests: XCTestCase {
    func testBasicLettersAndDigits() {
        XCTAssertEqual(KeycodeLabeler.label(0x0014), "Q")   // KC_Q
        XCTAssertEqual(KeycodeLabeler.label(0x001A), "W")   // KC_W
        XCTAssertEqual(KeycodeLabeler.label(0x0004), "A")   // KC_A
        XCTAssertEqual(KeycodeLabeler.label(0x001E), "1")   // KC_1
        XCTAssertEqual(KeycodeLabeler.label(0x0027), "0")   // KC_0
    }

    func testWhitespaceAndNavGlyphs() {
        XCTAssertEqual(KeycodeLabeler.label(0x0028), "↵")   // Enter
        XCTAssertEqual(KeycodeLabeler.label(0x002B), "⇥")   // Tab
        XCTAssertEqual(KeycodeLabeler.label(0x002A), "⌫")   // Backspace
        XCTAssertEqual(KeycodeLabeler.label(0x004F), "→")   // Right
        XCTAssertEqual(KeycodeLabeler.label(0x0052), "↑")   // Up
        XCTAssertEqual(KeycodeLabeler.label(0x003A), "F1")
    }

    func testNoAndTransparent() {
        XCTAssertEqual(KeycodeLabeler.label(0x0000), "")    // KC_NO
        XCTAssertEqual(KeycodeLabeler.label(0x0001), "▽")   // KC_TRNS
    }

    func testModTapShowsTapKey() {
        // The Totem's real home-row mods (captured on hardware).
        XCTAssertEqual(KeycodeLabeler.label(0x2804), "A")   // MT(GUI, A)
        XCTAssertEqual(KeycodeLabeler.label(0x2416), "S")   // MT(ALT, S)
        XCTAssertEqual(KeycodeLabeler.label(0x2107), "D")   // MT(CTL, D)
        XCTAssertEqual(KeycodeLabeler.label(0x2209), "F")   // MT(SFT, F)
    }

    func testLayerTapShowsTapKeyOrLayer() {
        XCTAssertEqual(KeycodeLabeler.label(0x422B), "⇥")   // LT(2, Tab) -> tap key
        XCTAssertEqual(KeycodeLabeler.label(0x4300), "L3")  // LT(3, KC_NO) -> layer
    }

    func testLayerSwitchesUseLayerLabel() {
        XCTAssertEqual(KeycodeLabeler.label(0x5221), "L1")  // MO(1)  (real capture)
        XCTAssertEqual(KeycodeLabeler.label(0x5224), "L4")  // MO(4)  (real capture)
        XCTAssertEqual(KeycodeLabeler.label(0x5220), "L0")  // MO(0)
    }

    func testModifiedKeycodeShowsBaseKey() {
        // QK_MODS range, e.g. RALT(A) observed as 0x1404 -> base key A.
        XCTAssertEqual(KeycodeLabeler.label(0x1404), "A")
    }

    func testUnknownFallsBackToHex() {
        XCTAssertEqual(KeycodeLabeler.label(0x7C55), "0x7C55")
        XCTAssertEqual(KeycodeLabeler.label(0x7E41), "0x7E41")
    }

    // MARK: decode — tap + hold

    func testDecodeModTapPrimaryAndHoldGlyph() {
        // The Totem's real home-row mods (GACS).
        XCTAssertEqual(KeycodeLabeler.decode(0x2804), .init(primary: "A", hold: "⌘"))
        XCTAssertEqual(KeycodeLabeler.decode(0x2416), .init(primary: "S", hold: "⌥"))
        XCTAssertEqual(KeycodeLabeler.decode(0x2107), .init(primary: "D", hold: "⌃"))
        XCTAssertEqual(KeycodeLabeler.decode(0x2209), .init(primary: "F", hold: "⇧"))
    }

    func testDecodeLayerTapPrimaryAndLayerHold() {
        XCTAssertEqual(KeycodeLabeler.decode(0x422B), .init(primary: "⇥", hold: "L2")) // LT(2, Tab)
        XCTAssertEqual(KeycodeLabeler.decode(0x4300), .init(primary: "L3", hold: "L3")) // LT(3, KC_NO)
    }

    func testDecodeMultiBitModConcatenatesInFixedOrder() {
        // MT with Ctrl+Shift+Alt+Gui (mask 0x0F) on KC_A → glyphs in ⌃⇧⌥⌘ order.
        XCTAssertEqual(KeycodeLabeler.decode(0x2F04).hold, "⌃⇧⌥⌘")
    }

    func testDecodeTwoBitModOrdering() {
        // MT(Ctrl+Shift, A): mask 0x03 → "⌃⇧" (ctrl before shift).
        XCTAssertEqual(KeycodeLabeler.decode(0x2304).hold, "⌃⇧")
    }

    func testDecodeModifiedKeycodeHold() {
        // QK_MODS: RALT(A) 0x1404 → base A, hold ⌥ (right-hand bit ignored for the glyph).
        XCTAssertEqual(KeycodeLabeler.decode(0x1404), .init(primary: "A", hold: "⌥"))
    }

    func testDecodePlainKeysHaveNoHold() {
        XCTAssertNil(KeycodeLabeler.decode(0x0014).hold) // Q
        XCTAssertNil(KeycodeLabeler.decode(0x5221).hold) // MO(1)
        XCTAssertNil(KeycodeLabeler.decode(0x0001).hold) // TRNS
        XCTAssertNil(KeycodeLabeler.decode(0x0000).hold) // NO
        XCTAssertNil(KeycodeLabeler.decode(0x7C55).hold) // hex fallback
    }

    // MARK: decode — shifted legend (US-ANSI, like Vial)

    /// Every one of the 21 US-ANSI shifted pairs, keyed by base HID code.
    func testShiftedLegendForAllSymbolKeys() {
        let pairs: [(UInt16, String)] = [
            (0x1E, "!"), (0x1F, "@"), (0x20, "#"), (0x21, "$"), (0x22, "%"),
            (0x23, "^"), (0x24, "&"), (0x25, "*"), (0x26, "("), (0x27, ")"),
            (0x2D, "_"), (0x2E, "+"), (0x2F, "{"), (0x30, "}"), (0x31, "|"),
            (0x33, ":"), (0x34, "\""), (0x35, "~"), (0x36, "<"), (0x37, ">"), (0x38, "?"),
        ]
        XCTAssertEqual(pairs.count, 21)
        for (code, symbol) in pairs {
            XCTAssertEqual(KeycodeLabeler.decode(code).shifted, symbol, "keycode 0x\(String(code, radix: 16))")
        }
    }

    func testShiftedLegendNilForNonSymbolKeys() {
        XCTAssertNil(KeycodeLabeler.decode(0x0004).shifted) // KC_A — primary already uppercase
        XCTAssertNil(KeycodeLabeler.decode(0x001D).shifted) // KC_Z
        XCTAssertNil(KeycodeLabeler.decode(0x002C).shifted) // Space
        XCTAssertNil(KeycodeLabeler.decode(0x0028).shifted) // Enter
        XCTAssertNil(KeycodeLabeler.decode(0x003A).shifted) // F1
        XCTAssertNil(KeycodeLabeler.decode(0x0032).shifted) // KC_NONUS_HASH — absent on US-ANSI
        XCTAssertNil(KeycodeLabeler.decode(0x0000).shifted) // KC_NO
        XCTAssertNil(KeycodeLabeler.decode(0x7C55).shifted) // hex fallback
        XCTAssertNil(KeycodeLabeler.decode(0x5221).shifted) // MO(1) layer switch
    }

    func testShiftedLegendThroughDualFunctionFamilies() {
        // MT(SFT, KC_1): taps 1 → shifted !, and still holds ⇧.
        XCTAssertEqual(KeycodeLabeler.decode(0x221E), .init(primary: "1", hold: "⇧", shifted: "!"))
        // MT(SFT, KC_A): a Shift mod-tap on a LETTER → shifted stays nil (letter exclusion holds).
        XCTAssertEqual(KeycodeLabeler.decode(0x2204), .init(primary: "A", hold: "⇧", shifted: nil))
        // QK_MODS on a symbol key (Ctrl+KC_1 = 0x011E) → shifted ! via the 0x0100–0x1FFF branch.
        XCTAssertEqual(KeycodeLabeler.decode(0x011E).shifted, "!")
        // LT(2, KC_SCLN): taps ; → shifted :, holds L2.
        XCTAssertEqual(KeycodeLabeler.decode(0x4233), .init(primary: ";", hold: "L2", shifted: ":"))
        // Bare LT(2, KC_NO): no tap key → shifted nil.
        XCTAssertNil(KeycodeLabeler.decode(0x4200).shifted)
    }
}
