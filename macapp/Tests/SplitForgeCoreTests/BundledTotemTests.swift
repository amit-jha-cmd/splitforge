import XCTest
@testable import SplitForgeCore

final class BundledTotemTests: XCTestCase {
    func testBundledTotemLoadsAndValidates() throws {
        let d = try DefinitionLoader.loadBundled("totem")
        XCTAssertEqual(d.name, "TOTEM")
        XCTAssertEqual(d.usbVendorId, 0x3A3C)
        XCTAssertEqual(d.usbProductId, 0x0002)
        XCTAssertEqual(d.matrix, .init(rows: 8, cols: 5))
        XCTAssertEqual(d.keys.count, 38)
        XCTAssertNoThrow(try d.validate()) // in-range, no duplicate matrix coords
    }

    /// Guards the sharpest correctness trap: the right half's matrix columns run OPPOSITE to x.
    /// Each key must carry its own matrix AND its own x, so a live keycode lands on the right key.
    func testRightHalfColumnReversalMapping() throws {
        let d = try DefinitionLoader.loadBundled("totem")
        // Layer 0 keycodes reshaped to the real 8×5 matrix.
        let layer0 = KeymapBuffer.reshape(TestFixtures.realLayer0, layers: 1, rows: 8, cols: 5)
        let model = KeyboardModel.live(definition: d, keycodes: layer0)

        let byMatrix = Dictionary(uniqueKeysWithValues: model.keys(forLayer: 0).map { ($0.matrix, $0) })

        // Left top-left key.
        XCTAssertEqual(byMatrix[[0, 0]]?.label, "Q")
        XCTAssertEqual(byMatrix[[0, 0]]?.x, 1)

        // Right half: matrix col 4 is the INNER (leftmost, x=9) key; col 0 is the OUTER (x=13) key.
        XCTAssertEqual(byMatrix[[4, 4]]?.x, 9)
        XCTAssertEqual(byMatrix[[4, 4]]?.label, "Y")   // keycode 0x001C at matrix [4,4]
        XCTAssertEqual(byMatrix[[4, 0]]?.x, 13)
        XCTAssertEqual(byMatrix[[4, 0]]?.label, "P")   // keycode 0x0013 at matrix [4,0]
    }

    func testHomeRowModsCarryHoldGlyph() throws {
        let d = try DefinitionLoader.loadBundled("totem")
        let layer0 = KeymapBuffer.reshape(TestFixtures.realLayer0, layers: 1, rows: 8, cols: 5)
        let model = KeyboardModel.live(definition: d, keycodes: layer0)
        let byMatrix = Dictionary(uniqueKeysWithValues: model.keys(forLayer: 0).map { ($0.matrix, $0) })

        // Home row (matrix row 1): A/S/D/F carry ⌘/⌥/⌃/⇧ on hold.
        XCTAssertEqual(byMatrix[[1, 0]]?.label, "A"); XCTAssertEqual(byMatrix[[1, 0]]?.hold, "⌘")
        XCTAssertEqual(byMatrix[[1, 1]]?.label, "S"); XCTAssertEqual(byMatrix[[1, 1]]?.hold, "⌥")
        XCTAssertEqual(byMatrix[[1, 2]]?.label, "D"); XCTAssertEqual(byMatrix[[1, 2]]?.hold, "⌃")
        XCTAssertEqual(byMatrix[[1, 3]]?.label, "F"); XCTAssertEqual(byMatrix[[1, 3]]?.hold, "⇧")
        // A plain key (Q) has no hold.
        XCTAssertNil(byMatrix[[0, 0]]?.hold)
    }
}
