import AppKit
import SplitForgeCore
import SplitForgeHID

/// Wires the HID transport + VialClient into the LayerStore, drives the menu bar + overlay, and
/// persists overlay position/opacity/layer-names via SettingsStore.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = LayerStore()
    private let settingsStore = SettingsStore()
    private var settings = Settings.defaultSettings

    private var transport: IOKitHIDTransport?
    private var vial: VialClient?
    private var definition: KeyboardDefinition?

    private var menuBar: MenuBarController?
    private var overlay: OverlayController?
    private var preferences: PreferencesWindowController?   // retained so it survives close

    func applicationDidFinishLaunching(_ notification: Notification) {
        settings = settingsStore.load()

        definition = try? DefinitionLoader.loadBundled("totem")
        if definition == nil {
            FileHandle.standardError.write(Data("split-forge: could not load bundled 'totem' definition\n".utf8))
        }
        let rows = definition?.matrix.rows ?? 8
        let cols = definition?.matrix.cols ?? 5

        let transport = IOKitHIDTransport(vid: 0x3A3C, pid: 0x0002)
        let vial = VialClient(transport: transport, layerCount: 16, rows: rows, cols: cols)
        self.transport = transport
        self.vial = vial

        let overlay = OverlayController(store: store)
        self.overlay = overlay

        overlay.onOriginChanged = { [weak self] origin in
            guard let self else { return }
            self.settings.overlayOriginX = Double(origin.x)
            self.settings.overlayOriginY = Double(origin.y)
            self.settingsStore.save(self.settings)
        }

        let menuBar = MenuBarController(
            store: store,
            onResync: { [weak vial] in try? vial?.start() },
            onOpacity: { [weak self] opacity in
                guard let self else { return }
                self.settings.overlayOpacity = opacity
                self.settingsStore.save(self.settings)
                self.overlay?.setOpacity(opacity)
            },
            onResetPosition: { [weak self] in self?.overlay?.resetPosition() },
            onPreferences: { [weak self] in self?.openPreferences() },
            onToggleLogin: { [weak self] in self?.toggleLogin() }
        )
        self.menuBar = menuBar

        store.onChange = { [weak menuBar, weak overlay] in
            menuBar?.refresh()
            overlay?.refresh()
        }

        vial.onResult = { [weak self] result in
            guard let self, let def = self.definition else { return }
            if case .complete(let layers) = result {
                self.store.setModel(KeyboardModel.live(definition: def, keycodes: layers))
                self.overlay?.clearPressed()   // drop any orphaned highlight from before the read
            }
        }

        transport.onReport = { [weak self] report in
            // IOHIDManager is scheduled on the main run loop (see IOKitHIDTransport.start), so this
            // callback runs on the main thread — safe to mutate the store and drive AppKit here.
            guard let self else { return }
            if let layer = LayerReport.decode(report) {
                let newLayer = Int(layer)
                let changed = newLayer != self.store.activeLayer
                self.store.setActiveLayer(newLayer)
                // Glow when entering a layer — not when returning to the base layer (0).
                if changed && newLayer != 0 { self.overlay?.flashGlow() }
                return
            }
            if let press = KeyPressReport.decode(report) {
                self.overlay?.setKeyPressed(row: press.row, col: press.col, down: press.pressed)
                return
            }
            self.vial?.handle(report)
        }
        transport.onDeviceConnected = { [weak vial] in try? vial?.start() }

        // Apply persisted settings (layer-names set fires onChange → repaint surfaces).
        store.layerNames = settings.layerNames
        overlay.applyOrigin(x: settings.overlayOriginX, y: settings.overlayOriginY)
        overlay.setOpacity(settings.overlayOpacity)
        menuBar.reflectOpacity(settings.overlayOpacity)
        menuBar.reflectLoginEnabled(LoginItem.isEnabled)

        switch transport.start() {
        case .ok:
            break
        case .notPermitted:
            menuBar.showPermissionNeeded()
        case .failed:
            break
        }
    }

    private func openPreferences() {
        if preferences == nil {
            preferences = PreferencesWindowController(names: settings.layerNames) { [weak self] names in
                guard let self else { return }
                self.settings.layerNames = names
                self.settingsStore.save(self.settings)
                self.store.layerNames = names   // didSet → onChange → repaint overlay + menu bar
            }
        }
        preferences?.show()
    }

    private func toggleLogin() {
        let result = LoginItem.setEnabled(!LoginItem.isEnabled)
        menuBar?.reflectLoginEnabled(result)
    }
}
