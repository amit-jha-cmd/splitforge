/// Single source of truth for the UI: the active layer plus the current `KeyboardModel`.
/// Drives all three surfaces via `onChange`. Pure — no AppKit — so it is unit-testable.
public final class LayerStore {
    public private(set) var activeLayer: Int
    public private(set) var model: KeyboardModel?

    /// Custom layer names (layer-index string → name). Setting it repaints via `onChange` — a rename
    /// doesn't change the active layer, so nothing else would trigger a refresh.
    public var layerNames: [String: String] = [:] {
        didSet { onChange?() }
    }

    /// Called whenever the active layer, model, or layer names change.
    public var onChange: (() -> Void)?

    /// The active layer's display name, e.g. "Nav" or "Layer 2".
    public var activeLayerName: String { LayerDisplay.name(layer: activeLayer, names: layerNames) }
    /// The active layer's short name for the menu bar, e.g. "Nav" or "L2".
    public var activeLayerShortName: String { LayerDisplay.shortName(layer: activeLayer, names: layerNames) }

    public init(activeLayer: Int = 0, model: KeyboardModel? = nil) {
        self.activeLayer = activeLayer
        self.model = model
    }

    /// Update the active layer. Notifies only on an actual change.
    public func setActiveLayer(_ layer: Int) {
        guard layer != activeLayer else { return }
        activeLayer = layer
        onChange?()
    }

    /// Update the keymap model (e.g. after a VIA read completes). Always notifies.
    public func setModel(_ model: KeyboardModel?) {
        self.model = model
        onChange?()
    }

    /// The positioned keys to draw for the current active layer (empty if no model yet).
    public func keysForActiveLayer() -> [KeyboardModel.PositionedKey] {
        model?.keys(forLayer: activeLayer) ?? []
    }
}
