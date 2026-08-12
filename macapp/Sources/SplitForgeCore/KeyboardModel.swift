/// A render-ready keyboard: geometry from a `KeyboardDefinition` combined with per-layer legends
/// (read live over VIA, or from static definition legends). Pure — no Foundation/IOKit — so M4's
/// renderer just iterates `keys(forLayer:)`.
public struct KeyboardModel: Equatable {
    /// A key positioned for drawing, with its label on a given layer. `hold` is the secondary
    /// (hold) function for dual-function keys — a modifier glyph or `L{n}` — or nil. `shifted` is the
    /// US-ANSI Shift symbol for the tap key (e.g. `1`→`!`), or nil for keys with no distinct one.
    public struct PositionedKey: Equatable {
        public let matrix: [Int]
        public let x, y, width, height, rotation: Double
        public let label: String
        public let hold: String?
        public let shifted: String?

        public init(matrix: [Int], x: Double, y: Double, width: Double, height: Double,
                    rotation: Double, label: String, hold: String? = nil, shifted: String? = nil) {
            self.matrix = matrix
            self.x = x; self.y = y
            self.width = width; self.height = height; self.rotation = rotation
            self.label = label; self.hold = hold; self.shifted = shifted
        }
    }

    public let definition: KeyboardDefinition
    /// `[layer][row][col]` labels (tap + optional hold). Row/col index the definition's matrix.
    private let layerLabels: [[[KeycodeLabeler.KeyLabel]]]

    public var matrixRows: Int { definition.matrix.rows }
    public var matrixCols: Int { definition.matrix.cols }
    public var layerCount: Int { layerLabels.count }

    public init(definition: KeyboardDefinition, layerLabels: [[[KeycodeLabeler.KeyLabel]]]) {
        self.definition = definition
        self.layerLabels = layerLabels
    }

    /// Build from live keycodes (`[[[UInt16]]]` from `VialClient`), decoding each cell to tap + hold.
    public static func live(definition: KeyboardDefinition, keycodes: [[[UInt16]]]) -> KeyboardModel {
        let labels = keycodes.map { layer in layer.map { row in row.map(KeycodeLabeler.decode) } }
        return KeyboardModel(definition: definition, layerLabels: labels)
    }

    /// Build from the definition's `staticLegends` (non-VIA boards). Produces `layerCount` layers,
    /// each label tap-only (no hold).
    public static func staticLegends(definition: KeyboardDefinition, layerCount: Int) -> KeyboardModel {
        let rows = definition.matrix.rows, cols = definition.matrix.cols
        let empty = KeycodeLabeler.KeyLabel(primary: "")
        var labels = Array(
            repeating: Array(repeating: Array(repeating: empty, count: cols), count: rows),
            count: max(0, layerCount)
        )
        for (layerKey, cells) in definition.staticLegends ?? [:] {
            guard let layer = Int(layerKey), layer >= 0, layer < labels.count else { continue }
            for (cell, text) in cells {
                let parts = cell.split(separator: ",")
                guard parts.count == 2, let r = Int(parts[0]), let c = Int(parts[1]),
                      r >= 0, r < rows, c >= 0, c < cols else { continue }
                labels[layer][r][c] = KeycodeLabeler.KeyLabel(primary: text)
            }
        }
        return KeyboardModel(definition: definition, layerLabels: labels)
    }

    /// The keys to draw for `layer`, each carrying its own geometry, tap label, and hold label.
    /// Iterates the definition's keys only, so matrix cells with no physical key aren't drawn.
    public func keys(forLayer layer: Int) -> [PositionedKey] {
        definition.keys.map { key in
            let kl = labelAt(layer: layer, row: key.row, col: key.col)
            return PositionedKey(
                matrix: key.matrix, x: key.x, y: key.y,
                width: key.width, height: key.height, rotation: key.rot,
                label: kl.primary, hold: kl.hold, shifted: kl.shifted
            )
        }
    }

    /// Bounds-safe lookup — anything out of range yields an empty label instead of crashing.
    private func labelAt(layer: Int, row: Int, col: Int) -> KeycodeLabeler.KeyLabel {
        let empty = KeycodeLabeler.KeyLabel(primary: "")
        guard layer >= 0, layer < layerLabels.count else { return empty }
        let rows = layerLabels[layer]
        guard row >= 0, row < rows.count else { return empty }
        let cols = rows[row]
        guard col >= 0, col < cols.count else { return empty }
        return cols[col]
    }
}
