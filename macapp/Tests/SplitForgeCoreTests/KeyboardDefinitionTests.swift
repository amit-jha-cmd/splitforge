import XCTest
import Foundation
@testable import SplitForgeCore

final class KeyboardDefinitionTests: XCTestCase {
    private func def(matrix: KeyboardDefinition.Matrix, keys: [KeyboardDefinition.Key],
                     staticLegends: [String: [String: String]]? = nil) -> KeyboardDefinition {
        KeyboardDefinition(id: "x", name: "X", usbVendorId: 1, usbProductId: 2,
                           matrix: matrix, keys: keys, staticLegends: staticLegends)
    }

    func testDecodesFromJSON() throws {
        let json = """
        { "id": "x", "name": "X", "usbVendorId": 15004, "usbProductId": 2,
          "matrix": { "rows": 2, "cols": 2 },
          "keys": [ { "matrix": [0, 0], "x": 0, "y": 0 },
                    { "matrix": [1, 1], "x": 1.5, "y": 1, "w": 1.5, "rotation": 15 } ] }
        """
        let d = try JSONDecoder().decode(KeyboardDefinition.self, from: Data(json.utf8))
        XCTAssertEqual(d.usbVendorId, 15004)
        XCTAssertEqual(d.matrix, .init(rows: 2, cols: 2))
        XCTAssertEqual(d.keys.count, 2)
        XCTAssertEqual(d.keys[0].width, 1)          // default when omitted
        XCTAssertEqual(d.keys[0].rot, 0)
        XCTAssertEqual(d.keys[1].width, 1.5)        // from JSON
        XCTAssertEqual(d.keys[1].rot, 15)
    }

    func testValidateAcceptsValid() {
        let d = def(matrix: .init(rows: 2, cols: 2),
                    keys: [.init(matrix: [0, 0], x: 0, y: 0), .init(matrix: [1, 1], x: 1, y: 1)])
        XCTAssertNoThrow(try d.validate())
    }

    func testValidateRejectsOutOfRange() {
        let d = def(matrix: .init(rows: 2, cols: 2), keys: [.init(matrix: [2, 0], x: 0, y: 0)])
        XCTAssertThrowsError(try d.validate()) {
            XCTAssertEqual($0 as? KeyboardDefinition.ValidationError, .matrixOutOfRange(row: 2, col: 0))
        }
    }

    func testValidateRejectsDuplicateMatrix() {
        let d = def(matrix: .init(rows: 2, cols: 2),
                    keys: [.init(matrix: [0, 0], x: 0, y: 0), .init(matrix: [0, 0], x: 1, y: 0)])
        XCTAssertThrowsError(try d.validate()) {
            XCTAssertEqual($0 as? KeyboardDefinition.ValidationError, .duplicateMatrix(row: 0, col: 0))
        }
    }

    func testValidateRejectsEmptyKeys() {
        let d = def(matrix: .init(rows: 2, cols: 2), keys: [])
        XCTAssertThrowsError(try d.validate()) {
            XCTAssertEqual($0 as? KeyboardDefinition.ValidationError, .emptyKeys)
        }
    }

    func testValidateRejectsBadDims() {
        let d = def(matrix: .init(rows: 0, cols: 2), keys: [.init(matrix: [0, 0], x: 0, y: 0)])
        XCTAssertThrowsError(try d.validate()) {
            XCTAssertEqual($0 as? KeyboardDefinition.ValidationError, .invalidMatrixDims)
        }
    }

    func testValidateRejectsMalformedMatrix() {
        let key = KeyboardDefinition.Key(matrix: [0], x: 0, y: 0) // needs [row, col]
        let d = def(matrix: .init(rows: 2, cols: 2), keys: [key])
        XCTAssertThrowsError(try d.validate()) {
            XCTAssertEqual($0 as? KeyboardDefinition.ValidationError, .malformedMatrix(key))
        }
    }
}
