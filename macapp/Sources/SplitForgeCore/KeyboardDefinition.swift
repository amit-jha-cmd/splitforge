/// A data-driven description of a keyboard: physical geometry + matrix map + USB identity.
/// Adding support for another keyboard means adding one of these as JSON — no code.
///
/// `Codable` is in the standard library, so this type stays Foundation-free; the actual JSON
/// decoding (which needs Foundation) lives in `DefinitionLoader`.
public struct KeyboardDefinition: Codable, Equatable {
    public struct Matrix: Codable, Equatable {
        public let rows: Int
        public let cols: Int
        public init(rows: Int, cols: Int) { self.rows = rows; self.cols = cols }
    }

    /// One physical key. `matrix` is `[row, col]` into the (whole, split-doubled) matrix; `x`/`y`
    /// are KLE-ish positions. `w`/`h`/`rotation` default to 1/1/0 when omitted.
    public struct Key: Codable, Equatable {
        public let matrix: [Int]
        public let x: Double
        public let y: Double
        public let w: Double?
        public let h: Double?
        public let rotation: Double?

        public var row: Int { matrix.count > 0 ? matrix[0] : -1 }
        public var col: Int { matrix.count > 1 ? matrix[1] : -1 }
        public var width: Double { w ?? 1 }
        public var height: Double { h ?? 1 }
        public var rot: Double { rotation ?? 0 }

        public init(matrix: [Int], x: Double, y: Double, w: Double? = nil, h: Double? = nil, rotation: Double? = nil) {
            self.matrix = matrix; self.x = x; self.y = y; self.w = w; self.h = h; self.rotation = rotation
        }
    }

    public let id: String
    public let name: String
    public let usbVendorId: Int
    public let usbProductId: Int
    public let matrix: Matrix
    public let keys: [Key]
    /// Optional per-layer, per-cell labels for boards we can't read live over VIA.
    public let staticLegends: [String: [String: String]]?

    public init(id: String, name: String, usbVendorId: Int, usbProductId: Int,
                matrix: Matrix, keys: [Key], staticLegends: [String: [String: String]]? = nil) {
        self.id = id; self.name = name
        self.usbVendorId = usbVendorId; self.usbProductId = usbProductId
        self.matrix = matrix; self.keys = keys; self.staticLegends = staticLegends
    }

    public enum ValidationError: Error, Equatable {
        case invalidMatrixDims
        case emptyKeys
        case malformedMatrix(Key)
        case matrixOutOfRange(row: Int, col: Int)
        case duplicateMatrix(row: Int, col: Int)
    }

    /// Rejects definitions that would produce a broken model: bad dims, empty keys, a key whose
    /// `[row,col]` is outside THIS definition's own matrix, or two keys sharing a matrix cell.
    public func validate() throws {
        guard matrix.rows > 0, matrix.cols > 0 else { throw ValidationError.invalidMatrixDims }
        guard !keys.isEmpty else { throw ValidationError.emptyKeys }
        var seen = Set<[Int]>()
        for key in keys {
            guard key.matrix.count == 2 else { throw ValidationError.malformedMatrix(key) }
            let r = key.row, c = key.col
            guard r >= 0, r < matrix.rows, c >= 0, c < matrix.cols else {
                throw ValidationError.matrixOutOfRange(row: r, col: c)
            }
            if !seen.insert([r, c]).inserted {
                throw ValidationError.duplicateMatrix(row: r, col: c)
            }
        }
    }
}
