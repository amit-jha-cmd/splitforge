/// Decoding of the firmware's key-press broadcast (message type `0x02`; see docs/PROTOCOL.md).
///
/// The firmware sends a 32-byte Raw HID report on every key press/release:
///   byte[0] = 0xCC (magic), byte[1] = 0x02 (KEY), byte[2] = row, byte[3] = col, byte[4] = pressed.
public enum KeyPressReport {
    public static let magic: UInt8 = 0xCC
    public static let typeKey: UInt8 = 0x02

    public struct KeyPress: Equatable {
        public let row: Int
        public let col: Int
        public let pressed: Bool
        public init(row: Int, col: Int, pressed: Bool) {
            self.row = row
            self.col = col
            self.pressed = pressed
        }
    }

    /// Returns the key press if `bytes` is one of our key-press broadcasts, else `nil` (other traffic).
    public static func decode(_ bytes: [UInt8]) -> KeyPress? {
        guard bytes.count >= 5, bytes[0] == magic, bytes[1] == typeKey else {
            return nil
        }
        return KeyPress(row: Int(bytes[2]), col: Int(bytes[3]), pressed: bytes[4] != 0)
    }
}
