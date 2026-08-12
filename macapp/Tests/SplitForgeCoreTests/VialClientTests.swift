import XCTest
@testable import SplitForgeCore

/// Test double for HIDTransport: records sent reports and, via `responder`, synchronously
/// delivers scripted responses back through `onReport`.
private final class MockHIDTransport: HIDTransport {
    var onReport: (([UInt8]) -> Void)?
    private(set) var sent: [[UInt8]] = []
    var responder: (([UInt8]) -> [[UInt8]])?

    func setReport(_ bytes: [UInt8]) throws {
        sent.append(bytes)
        if let responder, let onReport {
            for report in responder(bytes) { onReport(report) }
        }
    }
}

final class VialClientTests: XCTestCase {
    // Totem geometry observed on hardware.
    private let layers = 16, rows = 4, cols = 10
    private var totalBytes: Int { layers * rows * cols * 2 } // 1280

    // Real captured layer-0 keycodes (first two rows include the home-row mods).
    private let realLayer0: [UInt16] = [
        0x0014, 0x001A, 0x0008, 0x0015, 0x0017, 0x2804, 0x2416, 0x2107, 0x2209, 0x000A,
        0x001D, 0x001B, 0x0006, 0x0019, 0x0005, 0x0014, 0x0000, 0x5221, 0x422B, 0x002C,
        0x0013, 0x0012, 0x000C, 0x0018, 0x001C, 0x2833, 0x240F, 0x210E, 0x320D, 0x000B,
        0x0038, 0x0037, 0x0036, 0x0010, 0x0011, 0x0013, 0x0000, 0x002A, 0x4329, 0x0028,
    ]

    private func keymapBytes(layer0: [UInt16]) -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: totalBytes)
        for (i, kc) in layer0.enumerated() where (i * 2 + 1) < bytes.count {
            bytes[i * 2] = UInt8(kc >> 8)
            bytes[i * 2 + 1] = UInt8(kc & 0xFF)
        }
        return bytes
    }

    private func responder(keymap: [UInt8], layerCount: UInt8,
                           skip: Set<Int> = [], duplicate: Bool = false) -> ([UInt8]) -> [[UInt8]] {
        return { req in
            guard let cmd = req.first else { return [] }
            switch cmd {
            case 0x11:
                return [Via.padded([0x11, layerCount])]
            case 0x12:
                let offset = (Int(req[1]) << 8) | Int(req[2])
                if skip.contains(offset) { return [] }
                let size = Int(req[3])
                var resp: [UInt8] = [0x12, req[1], req[2], req[3]]
                for k in 0..<size { resp.append(offset + k < keymap.count ? keymap[offset + k] : 0) }
                let one = Via.padded(resp)
                return duplicate ? [one, one] : [one]
            default:
                return []
            }
        }
    }

    func testRequestsCoverWholeKeymapNoGapsOrOverlap() throws {
        let mock = MockHIDTransport() // no responder: never completes, just record requests
        let client = VialClient(transport: mock, layerCount: layers, rows: rows, cols: cols)
        try client.start()

        let bufferReqs = mock.sent.filter { $0.first == 0x12 }
            .map { (offset: Int($0[1]) << 8 | Int($0[2]), size: Int($0[3])) }
            .sorted { $0.offset < $1.offset }
        var pos = 0
        for req in bufferReqs {
            XCTAssertEqual(req.offset, pos, "gap/overlap at offset \(req.offset)")
            XCTAssertLessThanOrEqual(req.size, Via.maxChunk)
            pos += req.size
        }
        XCTAssertEqual(pos, totalBytes)
        XCTAssertEqual(mock.sent.first?.first, 0x11) // asks for layer count first
    }

    func testDecodesRealCapturedLayerZero() throws {
        let mock = MockHIDTransport()
        mock.responder = responder(keymap: keymapBytes(layer0: realLayer0), layerCount: 16)
        let client = VialClient(transport: mock, layerCount: layers, rows: rows, cols: cols)

        var result: VialClient.ReadResult?
        client.onResult = { result = $0 }
        transportRoute(mock, to: client)
        try client.start()

        guard case .complete(let grid)? = result else { return XCTFail("expected complete, got \(String(describing: result))") }
        XCTAssertEqual(grid.count, layers)
        XCTAssertEqual(grid[0].count, rows)
        XCTAssertEqual(grid[0][0].count, cols)
        XCTAssertEqual(grid[0][0], Array(realLayer0[0..<10]))
        XCTAssertEqual(grid[0][0].map(KeycodeLabeler.label), ["Q", "W", "E", "R", "T", "A", "S", "D", "F", "G"])
        XCTAssertEqual(client.reportedLayerCount, 16)
    }

    func testDuplicateChunksAreIgnoredIdempotently() throws {
        let mock = MockHIDTransport()
        mock.responder = responder(keymap: keymapBytes(layer0: realLayer0), layerCount: 16, duplicate: true)
        let client = VialClient(transport: mock, layerCount: layers, rows: rows, cols: cols)

        var completions = 0
        var grid: [[[UInt16]]]?
        client.onResult = { if case .complete(let g) = $0 { completions += 1; grid = g } }
        transportRoute(mock, to: client)
        try client.start()

        XCTAssertEqual(completions, 1, "duplicate chunks must not fire completion twice")
        XCTAssertEqual(grid?[0][0], Array(realLayer0[0..<10]))
    }

    func testMissingChunkReportsIncomplete() throws {
        let mock = MockHIDTransport()
        // Withhold the first chunk (offset 0).
        mock.responder = responder(keymap: keymapBytes(layer0: realLayer0), layerCount: 16, skip: [0])
        let client = VialClient(transport: mock, layerCount: layers, rows: rows, cols: cols)

        var result: VialClient.ReadResult?
        client.onResult = { result = $0 }
        transportRoute(mock, to: client)
        try client.start()

        XCTAssertNil(result, "should not complete while a chunk is missing")
        client.timedOut()
        XCTAssertEqual(result, .incomplete(missingOffsets: [0]))
    }

    func testOutOfOrderChunksStillComplete() throws {
        let keymap = keymapBytes(layer0: realLayer0)
        let mock = MockHIDTransport() // no responder; deliver manually, out of order
        let client = VialClient(transport: mock, layerCount: layers, rows: rows, cols: cols)
        var result: VialClient.ReadResult?
        client.onResult = { result = $0 }
        try client.start()

        let responses: [[UInt8]] = mock.sent.filter { $0.first == 0x12 }.map { req in
            let offset = Int(req[1]) << 8 | Int(req[2]); let size = Int(req[3])
            var r: [UInt8] = [0x12, req[1], req[2], req[3]]
            for k in 0..<size { r.append(offset + k < keymap.count ? keymap[offset + k] : 0) }
            return Via.padded(r)
        }
        for r in responses.reversed() { client.handle(r) } // reverse order

        guard case .complete(let grid)? = result else { return XCTFail("expected complete") }
        XCTAssertEqual(grid[0][0], Array(realLayer0[0..<10]))
    }

    func testShortResponseIsRejectedAndReportedIncomplete() throws {
        let keymap = keymapBytes(layer0: realLayer0)
        let mock = MockHIDTransport()
        let client = VialClient(transport: mock, layerCount: layers, rows: rows, cols: cols)
        var result: VialClient.ReadResult?
        client.onResult = { result = $0 }
        try client.start()

        for (i, req) in mock.sent.filter({ $0.first == 0x12 }).enumerated() {
            let offset = Int(req[1]) << 8 | Int(req[2]); let size = Int(req[3])
            if i == 0 {
                // Truncated report: declares `size` but carries only 10 data bytes.
                client.handle([0x12, req[1], req[2], req[3]] + Array(repeating: 0xAB, count: 10))
            } else {
                var r: [UInt8] = [0x12, req[1], req[2], req[3]]
                for k in 0..<size { r.append(offset + k < keymap.count ? keymap[offset + k] : 0) }
                client.handle(Via.padded(r))
            }
        }
        XCTAssertNil(result, "a short/truncated chunk must not complete the read")
        client.timedOut()
        XCTAssertEqual(result, .incomplete(missingOffsets: [0]))
    }

    /// Wires the mock's inbound reports to the client, as the app/spike does.
    private func transportRoute(_ transport: MockHIDTransport, to client: VialClient) {
        transport.onReport = { [weak client] report in client?.handle(report) }
    }
}
