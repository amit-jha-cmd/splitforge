import XCTest
@testable import SplitForgeCore

final class ViaTests: XCTestCase {
    func testGetLayerCountRequestIsPadded() {
        let req = Via.getLayerCountRequest()
        XCTAssertEqual(req.count, Via.reportSize)
        XCTAssertEqual(req[0], 0x11)
        XCTAssertTrue(req.dropFirst().allSatisfy { $0 == 0 })
    }

    func testGetBufferRequestEncoding() {
        let req = Via.getBufferRequest(offset: 0x0102, size: 28)
        XCTAssertEqual(req.count, Via.reportSize)
        XCTAssertEqual(Array(req[0...3]), [0x12, 0x01, 0x02, 28])
    }

    func testGetBufferRequestMaxOffsetEncoding() {
        let req = Via.getBufferRequest(offset: 0xFFFF, size: 1)
        XCTAssertEqual(Array(req[0...3]), [0x12, 0xFF, 0xFF, 1])
    }

    func testParseLayerCountResponse() {
        XCTAssertEqual(Via.parseLayerCountResponse([0x11, 6]), 6)
    }

    func testParseLayerCountRejectsWrongCommand() {
        XCTAssertNil(Via.parseLayerCountResponse([0x12, 6]))
        XCTAssertNil(Via.parseLayerCountResponse([0x11]))
    }

    func testParseBufferResponseExtractsData() {
        let response: [UInt8] = [0x12, 0x00, 0x04, 3, 0xAA, 0xBB, 0xCC, 0x00, 0x00]
        let parsed = Via.parseBufferResponse(response)
        XCTAssertEqual(parsed?.offset, 4)
        XCTAssertEqual(parsed?.data, [0xAA, 0xBB, 0xCC])
    }

    func testParseBufferResponseClampsToAvailableBytes() {
        // Header claims size 10 but only 2 data bytes are present.
        let response: [UInt8] = [0x12, 0x00, 0x00, 10, 0xDE, 0xAD]
        XCTAssertEqual(Via.parseBufferResponse(response)?.data, [0xDE, 0xAD])
    }

    func testParseBufferResponseRejectsWrongCommand() {
        XCTAssertNil(Via.parseBufferResponse([0x11, 0, 0, 0]))
        XCTAssertNil(Via.parseBufferResponse([0x12, 0, 0]))
    }

    func testPaddedTruncatesOverlongInput() {
        let padded = Via.padded(Array(repeating: 0xFF, count: 40))
        XCTAssertEqual(padded.count, Via.reportSize)
    }
}
