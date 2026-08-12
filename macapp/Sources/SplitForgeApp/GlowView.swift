import AppKit

/// A blue glow drawn above the keyboard: an inner blue rounded-rect border plus a faint blue tint.
/// The controller fades it in (alpha 1) on a layer change and animates it out. It never intercepts
/// the mouse, so background-drag of the overlay still works.
final class GlowView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true          // needed so alpha fades are layer-backed / smooth
        alphaValue = 0
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    // Transparent to the mouse — let clicks/drags reach the panel background.
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func draw(_ dirtyRect: NSRect) {
        // Faint inner tint.
        NSColor.systemBlue.withAlphaComponent(0.14).setFill()
        NSBezierPath(roundedRect: bounds, xRadius: 16, yRadius: 16).fill()

        // Inner border stroke (inset so it never depends on the panel shadow bleeding outward).
        let rect = bounds.insetBy(dx: 2.5, dy: 2.5)
        let border = NSBezierPath(roundedRect: rect, xRadius: 15, yRadius: 15)
        border.lineWidth = 3
        NSColor.systemBlue.setStroke()
        border.stroke()
    }
}
