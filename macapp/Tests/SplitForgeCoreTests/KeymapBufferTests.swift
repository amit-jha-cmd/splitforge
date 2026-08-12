import XCTest
@testable import SplitForgeCore

final class KeymapBufferTests: XCTestCase {
    func testParsesBigEndianKeycodes() {
        XCTAssertEqual(KeymapBuffer.parse([0x00, 0x04, 0x7A, 0x01]), [0x0004, 0x7A01])
    }

    func testParseIgnoresTrailingOddByte() {
        XCTAssertEqual(KeymapBuffer.parse([0x00, 0x04, 0xFF]), [0x0004])
    }

    func testParseEmpty() {
        XCTAssertEqual(KeymapBuffer.parse([]), [])
    }

    func testCellOffset() {
        // (1*4*6 + 2*6 + 3) * 2 = (24 + 12 + 3) * 2 = 78
        XCTAssertEqual(KeymapBuffer.cellOffset(layer: 1, row: 2, col: 3, rows: 4, cols: 6), 78)
    }

    func testTotalSize() {
        XCTAssertEqual(KeymapBuffer.totalSize(layers: 5, rows: 4, cols: 6), 240)
    }

    func testChunksCoverTotalWithoutExceedingChunkSize() {
        let chunks = KeymapBuffer.chunks(total: 240, chunk: 28)
        XCTAssertEqual(chunks.map(\.size).reduce(0, +), 240)
        XCTAssertTrue(chunks.allSatisfy { $0.size <= 28 })
        XCTAssertEqual(chunks.first?.offset, 0)
        XCTAssertEqual(chunks.last!.offset, 224)
        XCTAssertEqual(chunks.last!.size, 16)
        XCTAssertEqual(chunks.count, 9)
    }

    func testChunksExactMultiple() {
        let chunks = KeymapBuffer.chunks(total: 28, chunk: 28)
        XCTAssertEqual(chunks.count, 1)
        XCTAssertEqual(chunks[0].offset, 0)
        XCTAssertEqual(chunks[0].size, 28)
    }

    func testChunksSmallerThanChunkSize() {
        let chunks = KeymapBuffer.chunks(total: 16, chunk: 28)
        XCTAssertEqual(chunks.count, 1)
        XCTAssertEqual(chunks[0].offset, 0)
        XCTAssertEqual(chunks[0].size, 16)
    }

    func testChunksZeroTotal() {
        XCTAssertTrue(KeymapBuffer.chunks(total: 0, chunk: 28).isEmpty)
    }

    func testReshapeLayerMajorRowMajor() {
        let flat: [UInt16] = [0, 1, 2, 3, 4, 5, 6, 7]
        let shaped = KeymapBuffer.reshape(flat, layers: 2, rows: 2, cols: 2)
        XCTAssertEqual(shaped, [[[0, 1], [2, 3]], [[4, 5], [6, 7]]])
    }

    func testReshapePadsMissingTrailingCellsWithZero() {
        let shaped = KeymapBuffer.reshape([10, 11, 12], layers: 1, rows: 2, cols: 2)
        XCTAssertEqual(shaped, [[[10, 11], [12, 0]]])
    }

    func testReshapeMatchesCellOffsetIndexing() {
        // Build flat where each cell equals its own flat index, then confirm reshape places
        // (layer,row,col) at cellOffset/2.
        let layers = 3, rows = 4, cols = 5
        let flat = (0..<(layers * rows * cols)).map { UInt16($0) }
        let shaped = KeymapBuffer.reshape(flat, layers: layers, rows: rows, cols: cols)
        for l in 0..<layers {
            for r in 0..<rows {
                for c in 0..<cols {
                    XCTAssertEqual(Int(shaped[l][r][c]), KeymapBuffer.cellOffset(layer: l, row: r, col: c, rows: rows, cols: cols) / 2)
                }
            }
        }
    }
}
