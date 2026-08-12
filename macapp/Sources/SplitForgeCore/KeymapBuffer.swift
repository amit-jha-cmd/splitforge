/// Helpers for the VIA dynamic-keymap buffer layout (see docs/PROTOCOL.md).
///
/// The keymap is a flat array of 16-bit big-endian keycodes, ordered
/// layer-major, then row-major, then column.
public enum KeymapBuffer {
    /// Parses a raw byte buffer into 16-bit big-endian keycodes.
    /// A trailing odd byte (if any) is ignored.
    public static func parse(_ bytes: [UInt8]) -> [UInt16] {
        var out: [UInt16] = []
        out.reserveCapacity(bytes.count / 2)
        var i = 0
        while i + 1 < bytes.count {
            out.append((UInt16(bytes[i]) << 8) | UInt16(bytes[i + 1]))
            i += 2
        }
        return out
    }

    /// Byte offset of the (layer, row, col) cell in the dynamic keymap.
    public static func cellOffset(layer: Int, row: Int, col: Int, rows: Int, cols: Int) -> Int {
        (layer * rows * cols + row * cols + col) * 2
    }

    /// Total byte size of the keymap for the given dimensions.
    public static func totalSize(layers: Int, rows: Int, cols: Int) -> Int {
        layers * rows * cols * 2
    }

    /// Splits a `total` byte count into (offset, size) chunks of at most `chunk` bytes each.
    public static func chunks(total: Int, chunk: Int) -> [(offset: Int, size: Int)] {
        precondition(chunk > 0, "chunk must be positive")
        var result: [(offset: Int, size: Int)] = []
        var offset = 0
        while offset < total {
            let size = min(chunk, total - offset)
            result.append((offset, size))
            offset += size
        }
        return result
    }

    /// Reshapes a flat keycode array (layer-major, then row-major, then column) into
    /// `[layer][row][col]`. Missing trailing cells are padded with `0` (KC_NO); extra
    /// entries are ignored. Inverse of `cellOffset`.
    public static func reshape(_ flat: [UInt16], layers: Int, rows: Int, cols: Int) -> [[[UInt16]]] {
        var result: [[[UInt16]]] = []
        result.reserveCapacity(layers)
        for layer in 0..<max(0, layers) {
            var layerRows: [[UInt16]] = []
            layerRows.reserveCapacity(rows)
            for row in 0..<max(0, rows) {
                var rowCols: [UInt16] = []
                rowCols.reserveCapacity(cols)
                for col in 0..<max(0, cols) {
                    let index = layer * rows * cols + row * cols + col
                    rowCols.append(index < flat.count ? flat[index] : 0)
                }
                layerRows.append(rowCols)
            }
            result.append(layerRows)
        }
        return result
    }
}
