import AppKit
import SplitForgeCore

/// The menu bar indicator: shows the active layer's (short) name, plus a menu — Re-sync, Opacity
/// presets, Keyboard Source, Reset Position, Preferences…, Launch at Login, Quit.
final class MenuBarController: NSObject {
    private let statusItem: NSStatusItem
    private let store: LayerStore
    private let onResync: () -> Void
    private let onOpacity: (Double) -> Void
    private let onResetPosition: () -> Void
    private let onPreferences: () -> Void
    private let onToggleLogin: () -> Void
    private let onSelectSource: (HIDSourcePolicy) -> Void
    private let onSetPiBridgeAddress: (String, Int) -> Void

    private let opacityMenu = NSMenu()
    private let opacityPercents = [100, 80, 60, 40]
    private let loginItem = NSMenuItem(title: "Launch at Login", action: nil, keyEquivalent: "")

    private let sourceMenu = NSMenu()
    private var sourceItems: [HIDSourcePolicy: NSMenuItem] = [:]
    private let addressItem = NSMenuItem(title: "Set Pi Bridge Address…", action: nil, keyEquivalent: "")
    private var piBridgeHost: String?
    private var piBridgePort: Int

    private static let sourceTitles: [(HIDSourcePolicy, String)] = [
        (.auto, "Automatic (USB, else Pi bridge)"),
        (.usb, "USB (direct)"),
        (.piBridge, "Pi bridge"),
    ]

    init(store: LayerStore,
         source: HIDSourcePolicy,
         piBridgeHost: String?,
         piBridgePort: Int,
         onResync: @escaping () -> Void,
         onOpacity: @escaping (Double) -> Void,
         onResetPosition: @escaping () -> Void,
         onPreferences: @escaping () -> Void,
         onToggleLogin: @escaping () -> Void,
         onSelectSource: @escaping (HIDSourcePolicy) -> Void,
         onSetPiBridgeAddress: @escaping (String, Int) -> Void) {
        self.store = store
        self.piBridgeHost = piBridgeHost
        self.piBridgePort = piBridgePort
        self.onResync = onResync
        self.onOpacity = onOpacity
        self.onResetPosition = onResetPosition
        self.onPreferences = onPreferences
        self.onToggleLogin = onToggleLogin
        self.onSelectSource = onSelectSource
        self.onSetPiBridgeAddress = onSetPiBridgeAddress
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        let menu = NSMenu()

        add(menu, "Re-sync keymap", #selector(resyncAction), key: "r")

        for pct in opacityPercents {
            let item = NSMenuItem(title: "\(pct)%", action: #selector(opacityAction(_:)), keyEquivalent: "")
            item.target = self
            item.tag = pct
            opacityMenu.addItem(item)
        }
        let opacityItem = NSMenuItem(title: "Overlay Opacity", action: nil, keyEquivalent: "")
        opacityItem.submenu = opacityMenu
        menu.addItem(opacityItem)

        buildSourceMenu()
        let sourceItem = NSMenuItem(title: "Keyboard Source", action: nil, keyEquivalent: "")
        sourceItem.submenu = sourceMenu
        menu.addItem(sourceItem)
        reflectSource(source)

        add(menu, "Reset Overlay Position", #selector(resetAction))
        menu.addItem(.separator())

        add(menu, "Preferences…", #selector(preferencesAction), key: ",")
        loginItem.target = self
        loginItem.action = #selector(toggleLoginAction)
        menu.addItem(loginItem)

        menu.addItem(.separator())
        add(menu, "Quit split-forge", #selector(quitAction), key: "q")

        statusItem.menu = menu
        refresh()
    }

    private func buildSourceMenu() {
        for (policy, title) in Self.sourceTitles {
            let item = NSMenuItem(title: title, action: #selector(sourceAction(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = policy.rawValue
            sourceMenu.addItem(item)
            sourceItems[policy] = item
        }
        sourceMenu.addItem(.separator())
        addressItem.target = self
        addressItem.action = #selector(setAddressAction)
        addressItem.title = addressTitle()
        sourceMenu.addItem(addressItem)
        let note = NSMenuItem(title: "Source/address changes apply after relaunch", action: nil, keyEquivalent: "")
        note.isEnabled = false
        sourceMenu.addItem(note)
    }

    func refresh() {
        statusItem.button?.title = "⌨ \(store.activeLayerShortName)"
    }

    func showPermissionNeeded() {
        statusItem.button?.title = "⌨ ⚠"
    }

    /// Checkmark the opacity preset matching `opacity` (if any).
    func reflectOpacity(_ opacity: Double) {
        let pct = Int((opacity * 100).rounded())
        for item in opacityMenu.items { item.state = (item.tag == pct) ? .on : .off }
    }

    /// Checkmark "Launch at Login" per the current registration state.
    func reflectLoginEnabled(_ enabled: Bool) {
        loginItem.state = enabled ? .on : .off
    }

    /// Checkmark the selected keyboard source.
    func reflectSource(_ policy: HIDSourcePolicy) {
        for (p, item) in sourceItems { item.state = (p == policy) ? .on : .off }
    }

    private func add(_ menu: NSMenu, _ title: String, _ action: Selector, key: String = "") {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        menu.addItem(item)
    }

    private func addressTitle() -> String {
        if let host = piBridgeHost, !host.isEmpty { return "Pi Bridge: \(host):\(piBridgePort)" }
        return "Set Pi Bridge Address…"
    }

    /// Parses "host" or "host:port" → (host, port). Returns nil host for empty input.
    static func parseAddress(_ input: String, defaultPort: Int) -> (host: String?, port: Int) {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return (nil, defaultPort) }
        if let colon = trimmed.lastIndex(of: ":") {
            let host = String(trimmed[..<colon])
            let port = Int(trimmed[trimmed.index(after: colon)...]) ?? defaultPort
            return (host.isEmpty ? nil : host, port)
        }
        return (trimmed, defaultPort)
    }

    @objc private func resyncAction() { onResync() }
    @objc private func resetAction() { onResetPosition() }
    @objc private func preferencesAction() { onPreferences() }
    @objc private func toggleLoginAction() { onToggleLogin() }
    @objc private func quitAction() { NSApp.terminate(nil) }

    @objc private func opacityAction(_ sender: NSMenuItem) {
        let opacity = Double(sender.tag) / 100.0
        onOpacity(opacity)
        reflectOpacity(opacity)
    }

    @objc private func sourceAction(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let policy = HIDSourcePolicy(rawValue: raw) else { return }
        onSelectSource(policy)
        reflectSource(policy)
    }

    @objc private func setAddressAction() {
        let alert = NSAlert()
        alert.messageText = "Pi Bridge Address"
        alert.informativeText = "Host or host:port of the Pi running rawhid_server "
            + "(e.g. 192.168.1.45 or 192.168.1.45:\(Settings.defaultPiBridgePort))."
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 24))
        if let host = piBridgeHost, !host.isEmpty { field.stringValue = "\(host):\(piBridgePort)" }
        field.placeholderString = "192.168.1.45:\(Settings.defaultPiBridgePort)"
        alert.accessoryView = field
        alert.window.initialFirstResponder = field
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let (host, port) = Self.parseAddress(field.stringValue, defaultPort: piBridgePort)
        guard let host else { return }
        piBridgeHost = host
        piBridgePort = port
        addressItem.title = addressTitle()
        onSetPiBridgeAddress(host, port)
    }
}
