import XCTest
@testable import SplitForgeCore

final class KeyboardModelTests: XCTestCase {
    // A 2×2 matrix but only 3 physical keys — cell [1,1] has no key (phantom-cell guard).
    private func def3(staticLegends: [String: [String: String]]? = nil) -> KeyboardDefinition {
        KeyboardDefinition(
            id: "t", name: "T", usbVendorId: 1, usbProductId: 1,
            matrix: .init(rows: 2, cols: 2),
            keys: [.init(matrix: [0, 0], x: 0, y: 0),
                   .init(matrix: [0, 1], x: 1, y: 0),
                   .init(matrix: [1, 0], x: 0, y: 1)],
            staticLegends: staticLegends
        )
    }

    func testLiveAssemblyLabelsKeysAndSkipsPhantomCells() {
        let keycodes: [[[UInt16]]] = [[[0x0014, 0x001A], [0x0008, 0x0001]]] // Q W / E ▽
        let model = KeyboardModel.live(definition: def3(), keycodes: keycodes)

        let keys = model.keys(forLayer: 0)
        XCTAssertEqual(keys.count, 3, "must not emit the phantom [1,1] cell")
        let byMatrix = Dictionary(uniqueKeysWithValues: keys.map { ($0.matrix, $0) })
        XCTAssertEqual(byMatrix[[0, 0]]?.label, "Q")
        XCTAssertEqual(byMatrix[[0, 1]]?.label, "W")
        XCTAssertEqual(byMatrix[[1, 0]]?.label, "E")
        XCTAssertNil(byMatrix[[1, 1]]) // phantom cell absent
    }

    func testLiveAssemblyCarriesHoldLabel() {
        let def = KeyboardDefinition(
            id: "t", name: "T", usbVendorId: 1, usbProductId: 1,
            matrix: .init(rows: 1, cols: 2),
            keys: [.init(matrix: [0, 0], x: 0, y: 0), .init(matrix: [0, 1], x: 1, y: 0)]
        )
        // [0,0] = MT(⌘, A) 0x2804 ; [0,1] = Q 0x0014 (plain)
        let model = KeyboardModel.live(definition: def, keycodes: [[[0x2804, 0x0014]]])
        let byMatrix = Dictionary(uniqueKeysWithValues: model.keys(forLayer: 0).map { ($0.matrix, $0) })
        XCTAssertEqual(byMatrix[[0, 0]]?.label, "A")
        XCTAssertEqual(byMatrix[[0, 0]]?.hold, "⌘")
        XCTAssertEqual(byMatrix[[0, 1]]?.label, "Q")
        XCTAssertNil(byMatrix[[0, 1]]?.hold)
    }

    func testLiveAssemblyCarriesShiftedLabel() {
        let def = KeyboardDefinition(
            id: "t", name: "T", usbVendorId: 1, usbProductId: 1,
            matrix: .init(rows: 1, cols: 2),
            keys: [.init(matrix: [0, 0], x: 0, y: 0), .init(matrix: [0, 1], x: 1, y: 0)]
        )
        // [0,0] = KC_1 0x001E (shifted "!") ; [0,1] = Q 0x0014 (no distinct shifted symbol)
        let model = KeyboardModel.live(definition: def, keycodes: [[[0x001E, 0x0014]]])
        let byMatrix = Dictionary(uniqueKeysWithValues: model.keys(forLayer: 0).map { ($0.matrix, $0) })
        XCTAssertEqual(byMatrix[[0, 0]]?.label, "1")
        XCTAssertEqual(byMatrix[[0, 0]]?.shifted, "!")
        XCTAssertEqual(byMatrix[[0, 1]]?.label, "Q")
        XCTAssertNil(byMatrix[[0, 1]]?.shifted)
    }

    func testStaticLegendKeysHaveNoShiftedLabel() {
        // Static definition legends are literal text — never an implicit US-ANSI shift.
        let model = KeyboardModel.staticLegends(
            definition: def3(staticLegends: ["0": ["0,0": "1", "1,0": "Lo"]]),
            layerCount: 1
        )
        XCTAssertTrue(model.keys(forLayer: 0).allSatisfy { $0.shifted == nil })
    }

    func testStaticLegendAssembly() {
        let model = KeyboardModel.staticLegends(
            definition: def3(staticLegends: ["0": ["0,0": "Hi", "1,0": "Lo"]]),
            layerCount: 1
        )
        let byMatrix = Dictionary(uniqueKeysWithValues: model.keys(forLayer: 0).map { ($0.matrix, $0.label) })
        XCTAssertEqual(byMatrix[[0, 0]], "Hi")
        XCTAssertEqual(byMatrix[[1, 0]], "Lo")
        XCTAssertEqual(byMatrix[[0, 1]], "") // no legend supplied -> empty
    }

    func testOutOfRangeLayerYieldsEmptyLabelsNoCrash() {
        let model = KeyboardModel.live(definition: def3(), keycodes: [[[0x0014, 0x001A], [0x0008, 0x0009]]])
        let keys = model.keys(forLayer: 5) // only 1 layer exists
        XCTAssertEqual(keys.count, 3)
        XCTAssertTrue(keys.allSatisfy { $0.label.isEmpty })
    }
}
