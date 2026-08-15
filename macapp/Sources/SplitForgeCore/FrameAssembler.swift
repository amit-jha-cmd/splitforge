/// Reassembles a byte stream (e.g. TCP from the Pi bridge) into fixed-size HID reports.
///
/// The Pi's `rawhid_server` sends 32-byte raw-HID frames, but TCP may split or coalesce them,
/// so a consumer can't assume one `recv` == one report. This buffers partial data and yields
/// only complete `frameSize`-byte frames, in order. Pure/stdlib-only, so it is unit-tested
/// without a socket (per the repo's "pure logic in Core" convention).
public struct FrameAssembler {
    private let frameSize: Int
    private var buffer: [UInt8] = []

    public init(frameSize: Int) {
        precondition(frameSize > 0, "frameSize must be positive")
        self.frameSize = frameSize
    }

    /// Appends `bytes` and returns every complete frame now available, in order.
    public mutating func push(_ bytes: [UInt8]) -> [[UInt8]] {
        buffer.append(contentsOf: bytes)
        var frames: [[UInt8]] = []
        while buffer.count >= frameSize {
            frames.append(Array(buffer[0..<frameSize]))
            buffer.removeFirst(frameSize)
        }
        return frames
    }

    /// Bytes buffered but not yet forming a complete frame.
    public var pending: Int { buffer.count }

    /// Drops any partial data — call on reconnect so a half-frame from a dropped link can't
    /// corrupt the next stream.
    public mutating func reset() { buffer.removeAll(keepingCapacity: true) }
}
