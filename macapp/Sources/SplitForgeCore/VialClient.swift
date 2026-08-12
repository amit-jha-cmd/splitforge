/// Reads the live keymap from a VIA/Vial keyboard over `HIDTransport` (channel 2 in
/// docs/PROTOCOL.md). Pure orchestration — no IOKit — so it is fully unit-testable with a
/// mock transport.
///
/// Usage: the owner wires `transport.onReport` to route inbound reports — layer broadcasts
/// (`0xCC`) to `LayerReport.decode`, everything else to `handle(_:)` — then calls `start()`.
/// A host-side timeout should call `timedOut()` so a lost chunk surfaces as `.incomplete`
/// instead of hanging forever.
public final class VialClient {
    public enum ReadResult: Equatable {
        case complete(layers: [[[UInt16]]])
        case incomplete(missingOffsets: [Int])
    }

    private let transport: HIDTransport
    private let layerCount: Int
    private let rows: Int
    private let cols: Int
    private let totalBytes: Int

    private var buffer: [UInt8]
    private var filled: Set<Int> = []           // offsets received
    private var expected: [Int: Int] = [:]      // offset -> expected size

    /// Emitted once when the read finishes (all chunks in) or is declared incomplete.
    public var onResult: ((ReadResult) -> Void)?
    /// The layer count the device reports (from `get_layer_count`), for sanity-checking.
    public private(set) var reportedLayerCount: UInt8?

    public init(transport: HIDTransport, layerCount: Int, rows: Int, cols: Int) {
        self.transport = transport
        self.layerCount = layerCount
        self.rows = rows
        self.cols = cols
        self.totalBytes = KeymapBuffer.totalSize(layers: layerCount, rows: rows, cols: cols)
        self.buffer = [UInt8](repeating: 0, count: totalBytes)
    }

    /// Begin a one-shot keymap read: request the layer count, then every keymap chunk.
    public func start() throws {
        filled.removeAll()
        expected.removeAll()
        for i in 0..<buffer.count { buffer[i] = 0 }

        // Register every expected offset BEFORE sending, so the completion check
        // (`filled == expected`) can't pass prematurely when a response arrives
        // synchronously between sends.
        let chunks = KeymapBuffer.chunks(total: totalBytes, chunk: Via.maxChunk)
        for chunk in chunks { expected[chunk.offset] = chunk.size }

        try transport.setReport(Via.getLayerCountRequest())
        for chunk in chunks {
            try transport.setReport(Via.getBufferRequest(offset: UInt16(chunk.offset), size: UInt8(chunk.size)))
        }
    }

    /// Re-run the read (e.g. after a remap or an incomplete read).
    public func resync() throws { try start() }

    /// Route one inbound report. Ignores anything that isn't a VIA read response (e.g. the
    /// `0xCC` layer broadcast), and idempotently ignores duplicate/unexpected buffer chunks.
    public func handle(_ report: [UInt8]) {
        if let count = Via.parseLayerCountResponse(report) {
            reportedLayerCount = count
            return
        }
        guard let (offset, data) = Via.parseBufferResponse(report) else { return }
        let off = Int(offset)
        guard let size = expected[off], !filled.contains(off) else { return } // unexpected or duplicate
        // Reject a short/truncated response — leave the offset unfilled so timedOut() surfaces it,
        // rather than completing the read with a silently zero-padded (corrupt) chunk.
        guard data.count >= size else { return }

        let n = min(size, totalBytes - off)
        for i in 0..<n { buffer[off + i] = data[i] }
        filled.insert(off)

        if filled.count == expected.count {
            let flat = KeymapBuffer.parse(buffer)
            let layers = KeymapBuffer.reshape(flat, layers: layerCount, rows: rows, cols: cols)
            onResult?(.complete(layers: layers))
        }
    }

    /// Call from a host-side timeout. If the read hasn't completed, emits `.incomplete` with
    /// the still-missing offsets so the caller can `resync()`.
    public func timedOut() {
        guard !expected.isEmpty, filled.count < expected.count else { return }
        let missing = expected.keys.filter { !filled.contains($0) }.sorted()
        onResult?(.incomplete(missingOffsets: missing))
    }
}
