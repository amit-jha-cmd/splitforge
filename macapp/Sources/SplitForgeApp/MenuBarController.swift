import AppKit
import SplitForgeCore

/// The menu bar indicator: shows the active layer's (short) name, plus a menu — Re-sync, Opacity
/// presets, Reset Position, Preferences…, Launch at Login, Quit.
final class MenuBarController: NSObject {
    private let statusItem: NSStatusItem
    private let store: LayerStore
    private let onResync: () -> Void
    private let onOpacity: (Double) -> Void
    private let onResetPosition: () -> Void
    private let onPreferences: () -> Void
    private let onToggleLogin: () -> Void

    private let opacityMenu = NSMenu()
    private let opacityPercents = [100, 80, 60, 40]
    private let loginItem = NSMenuItem(title: "Launch at Login", action: nil, keyEquivalent: "")

    init(store: LayerStore,
         onResync: @escaping () -> Void,
         onOpacity: @escaping (Double) -> Void,
         onResetPosition: @escaping () -> Void,
         onPreferences: @escaping () -> Void,
         onToggleLogin: @escaping () -> Void) {
        self.store = store
        self.onResync = onResync
        self.onOpacity = onOpacity
        self.onResetPosition = onResetPosition
        self.onPreferences = onPreferences
        self.onToggleLogin = onToggleLogin
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

    private func add(_ menu: NSMenu, _ title: String, _ action: Selector, key: String = "") {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        menu.addItem(item)
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
}
