import AppKit

/// Factory for the overlay panel: a draggable (background-movable), always-on-top, non-activating
/// panel that shows on every Space. It is NOT click-through — dragging its background repositions it.
enum OverlayPanel {
    static func make(size: NSSize, content: NSView) -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .statusBar
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = false           // accepts mouse so it can be dragged
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]

        content.frame = NSRect(origin: .zero, size: size)
        content.autoresizingMask = [.width, .height]
        panel.contentView = content
        return panel
    }
}
