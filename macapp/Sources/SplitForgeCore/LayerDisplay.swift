/// Resolves how a layer is labelled: a custom name if the user set one (non-blank), else a default.
/// Pure/stdlib — the one bit of real logic behind editable layer names.
public enum LayerDisplay {
    /// Full label for the overlay header, e.g. "Nav" or "Layer 2".
    public static func name(layer: Int, names: [String: String]) -> String {
        custom(layer, names) ?? "Layer \(layer)"
    }

    /// Short label for the menu bar, e.g. "Nav" or "L2".
    public static func shortName(layer: Int, names: [String: String]) -> String {
        custom(layer, names) ?? "L\(layer)"
    }

    private static func custom(_ layer: Int, _ names: [String: String]) -> String? {
        guard let name = names[String(layer)], !name.allSatisfy(\.isWhitespace) else { return nil }
        return name
    }
}
