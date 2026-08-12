import XCTest
@testable import SplitForgeCore

final class LayerStoreTests: XCTestCase {
    private func model() -> KeyboardModel {
        let def = KeyboardDefinition(
            id: "t", name: "T", usbVendorId: 1, usbProductId: 1,
            matrix: .init(rows: 1, cols: 2),
            keys: [.init(matrix: [0, 0], x: 0, y: 0), .init(matrix: [0, 1], x: 1, y: 0)]
        )
        // Two layers: layer 0 = Q,W ; layer 1 = A,S
        return KeyboardModel.live(definition: def, keycodes: [[[0x0014, 0x001A]], [[0x0004, 0x0016]]])
    }

    func testSetActiveLayerNotifiesOnlyOnChange() {
        let store = LayerStore()
        var notifications = 0
        store.onChange = { notifications += 1 }

        store.setActiveLayer(2)
        store.setActiveLayer(2) // same → no notify
        store.setActiveLayer(0)

        XCTAssertEqual(store.activeLayer, 0)
        XCTAssertEqual(notifications, 2)
    }

    func testSetModelNotifies() {
        let store = LayerStore()
        var notifications = 0
        store.onChange = { notifications += 1 }
        store.setModel(model())
        XCTAssertEqual(notifications, 1)
        XCTAssertNotNil(store.model)
    }

    func testKeysForActiveLayerReflectsActiveLayer() {
        let store = LayerStore()
        store.setModel(model())
        XCTAssertEqual(store.keysForActiveLayer().map(\.label), ["Q", "W"])
        store.setActiveLayer(1)
        XCTAssertEqual(store.keysForActiveLayer().map(\.label), ["A", "S"])
    }

    func testKeysEmptyWithoutModel() {
        XCTAssertTrue(LayerStore().keysForActiveLayer().isEmpty)
    }

    func testDisplayNameFollowsNamesAndActiveLayer() {
        let store = LayerStore()
        store.layerNames = ["2": "Nav"]
        store.setActiveLayer(2)
        XCTAssertEqual(store.activeLayerName, "Nav")
        XCTAssertEqual(store.activeLayerShortName, "Nav")
        store.setActiveLayer(3)
        XCTAssertEqual(store.activeLayerName, "Layer 3")
        XCTAssertEqual(store.activeLayerShortName, "L3")
    }

    func testSettingLayerNamesNotifies() {
        let store = LayerStore()
        var notifications = 0
        store.onChange = { notifications += 1 }
        store.layerNames = ["0": "Base"]
        XCTAssertEqual(notifications, 1)
    }
}
