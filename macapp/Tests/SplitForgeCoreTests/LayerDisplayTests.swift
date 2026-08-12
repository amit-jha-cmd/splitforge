import XCTest
@testable import SplitForgeCore

final class LayerDisplayTests: XCTestCase {
    func testCustomNameUsedWhenSet() {
        let names = ["2": "Nav"]
        XCTAssertEqual(LayerDisplay.name(layer: 2, names: names), "Nav")
        XCTAssertEqual(LayerDisplay.shortName(layer: 2, names: names), "Nav")
    }

    func testFallbacksWhenUnset() {
        XCTAssertEqual(LayerDisplay.name(layer: 3, names: [:]), "Layer 3")
        XCTAssertEqual(LayerDisplay.shortName(layer: 3, names: [:]), "L3")
    }

    func testBlankNameFallsBack() {
        let names = ["1": "   "]
        XCTAssertEqual(LayerDisplay.name(layer: 1, names: names), "Layer 1")
        XCTAssertEqual(LayerDisplay.shortName(layer: 1, names: names), "L1")
    }
}
