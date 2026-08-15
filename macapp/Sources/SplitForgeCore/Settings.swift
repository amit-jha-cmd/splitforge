/// Where split-forge reads the Totem from. `.auto` prefers a directly-attached USB device and
/// falls back to the Pi bridge when none is present; `.usb`/`.piBridge` force one path.
public enum HIDSourcePolicy: String, Codable, CaseIterable { case auto, usb, piBridge }

/// User preferences persisted across launches. Pure/`Codable` (stdlib only); `SettingsStore` does the I/O.
/// Origin is stored as two optionals (both nil = default corner) — a saved origin's validity depends on
/// the current screens, so that check lives app-side.
public struct Settings: Codable, Equatable {
    public var overlayOriginX: Double?
    public var overlayOriginY: Double?
    /// Overlay opacity, kept in `[minOpacity, 1.0]` so the overlay can never become invisible.
    public var overlayOpacity: Double
    /// Custom layer names keyed by layer index (as a string). Blank entries are dropped on normalize.
    public var layerNames: [String: String]

    // Pi-bridge routing (Milestone B). All optional so pre-existing saved settings decode unchanged
    // (missing keys → nil). With no host set, `effectiveSource` behaves exactly as before (USB only).
    public var piBridgeHost: String?
    public var piBridgePort: Int?
    public var hidSource: HIDSourcePolicy?

    public static let minOpacity: Double = 0.3
    public static let defaultPiBridgePort = 8724
    public static let defaultSettings = Settings()

    public init(overlayOriginX: Double? = nil, overlayOriginY: Double? = nil,
                overlayOpacity: Double = 1.0, layerNames: [String: String] = [:],
                piBridgeHost: String? = nil, piBridgePort: Int? = nil,
                hidSource: HIDSourcePolicy? = nil) {
        self.overlayOriginX = overlayOriginX
        self.overlayOriginY = overlayOriginY
        self.overlayOpacity = overlayOpacity
        self.layerNames = layerNames
        self.piBridgeHost = piBridgeHost
        self.piBridgePort = piBridgePort
        self.hidSource = hidSource
    }

    /// Selected source, defaulting to `.auto` when unset.
    public var effectiveSource: HIDSourcePolicy { hidSource ?? .auto }
    /// Pi-bridge TCP port, defaulting to the server's port when unset.
    public var effectivePiBridgePort: Int { piBridgePort ?? Settings.defaultPiBridgePort }

    /// Clamps opacity into `[minOpacity, 1.0]` and drops blank/whitespace-only layer names so the dict
    /// can't accumulate empty entries. (Origin validity is screen-dependent → validated app-side.)
    public func normalized() -> Settings {
        var copy = self
        copy.overlayOpacity = min(1.0, max(Settings.minOpacity, overlayOpacity))
        copy.layerNames = layerNames.filter { !$0.value.allSatisfy(\.isWhitespace) }
        return copy
    }

    public var hasOrigin: Bool { overlayOriginX != nil && overlayOriginY != nil }
}
