/// Pure geometry helper: the bounding box of positioned keys in key-units, so a renderer can
/// scale-to-fit into any target rect. Foundation-free (plain `Double`).
public enum KeyboardLayout {
    public struct Bounds: Equatable {
        public let x: Double
        public let y: Double
        public let width: Double
        public let height: Double
        public init(x: Double, y: Double, width: Double, height: Double) {
            self.x = x; self.y = y; self.width = width; self.height = height
        }
    }

    /// Bounding box covering every key's `x,y,width,height`. Empty input → zero bounds.
    public static func bounds(of keys: [KeyboardModel.PositionedKey]) -> Bounds {
        guard let first = keys.first else { return Bounds(x: 0, y: 0, width: 0, height: 0) }
        var minX = first.x, minY = first.y
        var maxX = first.x + first.width, maxY = first.y + first.height
        for key in keys.dropFirst() {
            minX = min(minX, key.x)
            minY = min(minY, key.y)
            maxX = max(maxX, key.x + key.width)
            maxY = max(maxY, key.y + key.height)
        }
        return Bounds(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}
