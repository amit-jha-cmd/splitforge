import AppKit

/// A small preferences window for editing layer names. One text field per layer (0…7); a blank field
/// means "use the default (Layer N)". Saves on end-editing and on window close, reporting the updated
/// names dict to `onNamesChanged`.
final class PreferencesWindowController: NSWindowController, NSTextFieldDelegate, NSWindowDelegate {
    private let layerCount = 8
    private var fields: [NSTextField] = []
    private var names: [String: String]
    private let onNamesChanged: ([String: String]) -> Void

    init(names: [String: String], onNamesChanged: @escaping ([String: String]) -> Void) {
        self.names = names
        self.onNamesChanged = onNamesChanged

        let height = CGFloat(40 + layerCount * 30 + 16)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: height),
            styleMask: [.titled, .closable], backing: .buffered, defer: false
        )
        window.title = "SplitForge Preferences"
        super.init(window: window)
        window.delegate = self
        buildUI()
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    func show() {
        // Reflect current names each time it's shown.
        for field in fields { field.stringValue = names[String(field.tag)] ?? "" }
        window?.center()
        showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    private func buildUI() {
        guard let content = window?.contentView else { return }
        let top = content.bounds.height - 28

        let header = NSTextField(labelWithString: "Layer names")
        header.font = .boldSystemFont(ofSize: 13)
        header.frame = NSRect(x: 16, y: top, width: 200, height: 18)
        content.addSubview(header)

        for layer in 0..<layerCount {
            let y = top - CGFloat(layer + 1) * 30
            let label = NSTextField(labelWithString: "Layer \(layer):")
            label.alignment = .right
            label.frame = NSRect(x: 12, y: y, width: 70, height: 20)
            content.addSubview(label)

            let field = NSTextField(frame: NSRect(x: 92, y: y - 2, width: 208, height: 22))
            field.placeholderString = "Layer \(layer)"
            field.stringValue = names[String(layer)] ?? ""
            field.delegate = self
            field.tag = layer
            content.addSubview(field)
            fields.append(field)
        }
    }

    /// Save when a field commits (Return or focus-loss).
    func controlTextDidEndEditing(_ obj: Notification) { commit() }

    /// Force-commit any in-progress edit when the window closes while a field is still first responder.
    func windowWillClose(_ notification: Notification) {
        window?.makeFirstResponder(nil)
        commit()
    }

    private func commit() {
        var updated = names
        for field in fields {
            let key = String(field.tag)
            let value = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if value.isEmpty { updated.removeValue(forKey: key) } else { updated[key] = value }
        }
        guard updated != names else { return }
        names = updated
        onNamesChanged(updated)
    }
}
