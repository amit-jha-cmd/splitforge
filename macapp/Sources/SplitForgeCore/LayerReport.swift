/// Decoding of the firmware's active-layer broadcast (channel 1 in docs/PROTOCOL.md).
///
/// The firmware sends a 32-byte Raw HID report on every layer change:
///   byte[0] = 0xCC (magic), byte[1] = 0x01 (LAYER), byte[2] = active layer.
public enum LayerReport {
    /// Magic first byte marking a "relay from device" report.
    public static let magic: UInt8 = 0xCC
    /// Message type for an active-layer update.
    public static let typeLayer: UInt8 = 0x01

    /// Returns the active layer index if `bytes` is one of our layer broadcasts,
    /// or `nil` if it is any other traffic on the interface (e.g. a VIA response).
    public static func decode(_ bytes: [UInt8]) -> UInt8? {
        guard bytes.count >= 3, bytes[0] == magic, bytes[1] == typeLayer else {
            return nil
        }
        return bytes[2]
    }
}
