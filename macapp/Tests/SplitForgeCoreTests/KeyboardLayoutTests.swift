import XCTest
@testable import SplitForgeCore

final class KeyboardLayoutTests: XCTestCase {
    private func key(_ x: Double, _ y: Double, w: Double = 1, h: Double = 1) -> KeyboardModel.PositionedKey {
        KeyboardModel.PositionedKey(matrix: [0, 0], x: x, y: y, width: w, height: h, rotation: 0, label: "")
    }

    func testBoundsCoversAllKeys() {
        let b = KeyboardLayout.bounds(of: [key(1, 1.4), key(5, 0), key(13, 3.4)])
        XCTAssertEqual(b, .init(x: 1, y: 0, width: 13, height: 4.4)) // maxX = 13+1=14, maxY = 3.4+1=4.4
    }

    func testBoundsAccountsForWidthHeight() {
        let b = KeyboardLayout.bounds(of: [key(0, 0, w: 1.5, h: 2)])
        XCTAssertEqual(b, .init(x: 0, y: 0, width: 1.5, height: 2))
    }

    func testBoundsEmptyIsZero() {
        XCTAssertEqual(KeyboardLayout.bounds(of: []), .init(x: 0, y: 0, width: 0, height: 0))
    }
}
