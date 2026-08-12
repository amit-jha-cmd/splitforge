import XCTest
@testable import SplitForgeCore

final class KeyPressReportTests: XCTestCase {
    func testDecodesPress() {
        XCTAssertEqual(KeyPressReport.decode([0xCC, 0x02, 1, 3, 1]),
                       .init(row: 1, col: 3, pressed: true))
    }

    func testDecodesRelease() {
        XCTAssertEqual(KeyPressReport.decode([0xCC, 0x02, 4, 0, 0]),
                       .init(row: 4, col: 0, pressed: false))
    }

    func testDecodesPadded32ByteReport() {
        var report = [UInt8](repeating: 0, count: 32)
        report[0] = 0xCC; report[1] = 0x02; report[2] = 7; report[3] = 4; report[4] = 1
        XCTAssertEqual(KeyPressReport.decode(report), .init(row: 7, col: 4, pressed: true))
    }

    func testRejectsWrongMagicOrType() {
        XCTAssertNil(KeyPressReport.decode([0xAB, 0x02, 1, 1, 1]))
        XCTAssertNil(KeyPressReport.decode([0xCC, 0x01, 1, 1, 1])) // that's a LAYER message
    }

    func testRejectsTooShort() {
        XCTAssertNil(KeyPressReport.decode([0xCC, 0x02, 1, 1]))
        XCTAssertNil(KeyPressReport.decode([]))
    }
}
