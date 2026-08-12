import XCTest
@testable import SplitForgeCore

final class LayerReportTests: XCTestCase {
    func testDecodesValidThreeByteReport() {
        XCTAssertEqual(LayerReport.decode([0xCC, 0x01, 0x03]), 3)
    }

    func testDecodesFull32ByteReport() {
        var report = [UInt8](repeating: 0, count: 32)
        report[0] = 0xCC
        report[1] = 0x01
        report[2] = 7
        XCTAssertEqual(LayerReport.decode(report), 7)
    }

    func testDecodesLayerZero() {
        XCTAssertEqual(LayerReport.decode([0xCC, 0x01, 0x00]), 0)
    }

    func testRejectsWrongMagic() {
        XCTAssertNil(LayerReport.decode([0xAB, 0x01, 0x03]))
    }

    func testRejectsWrongMessageType() {
        XCTAssertNil(LayerReport.decode([0xCC, 0x02, 0x03]))
    }

    func testRejectsTooShort() {
        XCTAssertNil(LayerReport.decode([0xCC, 0x01]))
        XCTAssertNil(LayerReport.decode([]))
    }
}
