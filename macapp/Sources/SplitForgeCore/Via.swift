/// VIA protocol framing for reading the live keymap (channel 2 in docs/PROTOCOL.md).
///
/// All requests/responses are 32-byte reports (report ID 0). We implement only the
/// read commands we need; we are a client of the firmware's existing Vial/VIA handler
/// and never modify it.
public enum Via {
    /// Raw HID report size for VIA/Vial.
    public static let reportSize = 32
    /// Max keymap bytes per `getBuffer` chunk (reportSize − 4 header bytes).
    public static let maxChunk = 28

    public enum Command: UInt8 {
        case getProtocolVersion = 0x01
        case getLayerCount = 0x11
        case getBuffer = 0x12
    }

    // MARK: Requests

    public static func getProtocolVersionRequest() -> [UInt8] {
        padded([Command.getProtocolVersion.rawValue])
    }

    public static func getLayerCountRequest() -> [UInt8] {
        padded([Command.getLayerCount.rawValue])
    }

    /// Request `size` (≤ `maxChunk`) keymap bytes starting at `offset`.
    public static func getBufferRequest(offset: UInt16, size: UInt8) -> [UInt8] {
        precondition(Int(size) <= maxChunk, "chunk size \(size) exceeds maxChunk \(maxChunk)")
        return padded([
            Command.getBuffer.rawValue,
            UInt8(truncatingIfNeeded: offset >> 8),
            UInt8(truncatingIfNeeded: offset & 0xFF),
            size,
        ])
    }

    // MARK: Responses

    /// Parses a `getLayerCount` response → layer count, or nil if not that response.
    public static func parseLayerCountResponse(_ bytes: [UInt8]) -> UInt8? {
        guard bytes.count >= 2, bytes[0] == Command.getLayerCount.rawValue else {
            return nil
        }
        return bytes[1]
    }

    /// Parses a `getBuffer` response → (byte offset, data bytes), or nil if not that
    /// response. The response echoes the offset and size, followed by `size` data bytes.
    public static func parseBufferResponse(_ bytes: [UInt8]) -> (offset: UInt16, data: [UInt8])? {
        guard bytes.count >= 4, bytes[0] == Command.getBuffer.rawValue else {
            return nil
        }
        let offset = (UInt16(bytes[1]) << 8) | UInt16(bytes[2])
        let size = Int(bytes[3])
        let end = min(4 + size, bytes.count)
        return (offset, Array(bytes[4..<end]))
    }

    // MARK: Helpers

    /// Pads (or truncates) a prefix to a full `reportSize` report.
    public static func padded(_ prefix: [UInt8]) -> [UInt8] {
        var report = prefix
        if report.count < reportSize {
            report.append(contentsOf: repeatElement(0, count: reportSize - report.count))
        } else if report.count > reportSize {
            report = Array(report[0..<reportSize])
        }
        return report
    }
}
