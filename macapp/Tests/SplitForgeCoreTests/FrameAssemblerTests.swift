import XCTest

@testable import SplitForgeCore

final class FrameAssemblerTests: XCTestCase {
    func testExactFrameYieldsOne() {
        var a = FrameAssembler(frameSize: 4)
        XCTAssertEqual(a.push([1, 2, 3, 4]), [[1, 2, 3, 4]])
        XCTAssertEqual(a.pending, 0)
    }

    func testPartialThenCompletes() {
        var a = FrameAssembler(frameSize: 4)
        XCTAssertEqual(a.push([1, 2]), [])
        XCTAssertEqual(a.pending, 2)
        XCTAssertEqual(a.push([3, 4]), [[1, 2, 3, 4]])
        XCTAssertEqual(a.pending, 0)
    }

    func testMultipleFramesInOnePush() {
        var a = FrameAssembler(frameSize: 2)
        XCTAssertEqual(a.push([1, 2, 3, 4, 5, 6]), [[1, 2], [3, 4], [5, 6]])
        XCTAssertEqual(a.pending, 0)
    }

    func testFrameAndAHalfKeepsRemainder() {
        var a = FrameAssembler(frameSize: 4)
        XCTAssertEqual(a.push([1, 2, 3, 4, 5, 6]), [[1, 2, 3, 4]])
        XCTAssertEqual(a.pending, 2)
        XCTAssertEqual(a.push([7, 8]), [[5, 6, 7, 8]])
        XCTAssertEqual(a.pending, 0)
    }

    func testResetDropsPartial() {
        var a = FrameAssembler(frameSize: 4)
        _ = a.push([1, 2, 3])
        XCTAssertEqual(a.pending, 3)
        a.reset()
        XCTAssertEqual(a.pending, 0)
        XCTAssertEqual(a.push([9, 9, 9, 9]), [[9, 9, 9, 9]])
    }

    func testByteAtATime() {
        var a = FrameAssembler(frameSize: 3)
        XCTAssertEqual(a.push([1]), [])
        XCTAssertEqual(a.push([2]), [])
        XCTAssertEqual(a.push([3]), [[1, 2, 3]])
    }

    func testReportSizedFrames() {
        var a = FrameAssembler(frameSize: 32)
        let f1 = Array(repeating: UInt8(0xAA), count: 32)
        let f2 = Array(repeating: UInt8(0xBB), count: 32)
        XCTAssertEqual(a.push(f1 + f2), [f1, f2])
    }
}
