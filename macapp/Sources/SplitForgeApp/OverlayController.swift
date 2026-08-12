import AppKit
import QuartzCore
import SplitForgeCore

/// The always-visible corner overlay: a compact keyboard the user can drag to reposition and dim.
/// Refreshed whenever the store changes; glows blue on a layer change; reports drags for persistence.
final class OverlayController {
    private let store: LayerStore
    private let panel: NSPanel
    private let view = KeyboardView()
    private let glow = GlowView()
    private var moveObserver: NSObjectProtocol?
    /// The user's selected opacity — the value the overlay dims back to after a glow.
    private var currentOpacity: Double = 1.0
    private let glowDuration: CFTimeInterval = 0.7
    private let glowFadeKey = "glowFade"

    /// Called with the panel's new origin whenever it moves (user drag or a heal-to-corner).
    var onOriginChanged: ((CGPoint) -> Void)?

    init(store: LayerStore) {
        self.store = store
        let size = NSSize(width: 380, height: 165)

        let container = NSView(frame: NSRect(origin: .zero, size: size))
        container.autoresizingMask = [.width, .height]
        view.frame = container.bounds
        view.autoresizingMask = [.width, .height]
        glow.frame = container.bounds
        glow.autoresizingMask = [.width, .height]
        container.addSubview(view)
        container.addSubview(glow, positioned: .above, relativeTo: view)

        panel = OverlayPanel.make(size: size, content: container)
        refresh()
        positionCorner()
        panel.orderFrontRegardless()

        moveObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification, object: panel, queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.onOriginChanged?(self.panel.frame.origin)
        }
    }

    deinit {
        if let moveObserver { NotificationCenter.default.removeObserver(moveObserver) }
    }

    func refresh() {
        view.keys = store.keysForActiveLayer()
        view.layerLabel = store.activeLayerName
        view.needsDisplay = true
    }

    /// Flash on a layer switch: snap to full brightness + blue glow, then ease both out to the user's
    /// opacity. The glow uses an **explicit `CABasicAnimation`** (added straight to the layer) rather
    /// than the implicit `animator()` proxy: on a momentary key the release (`→0`) triggers an overlay
    /// refresh in the same run loop, and that would coalesce away an implicit fade set up on the press —
    /// which is exactly the "only glows on a fast double-press" bug. An explicit animation is immune.
    func flashGlow() {
        if let glowLayer = glow.layer {
            glowLayer.removeAnimation(forKey: glowFadeKey)
            glow.alphaValue = 0                       // rest state (invisible)
            let fade = CABasicAnimation(keyPath: "opacity")
            fade.fromValue = 1.0
            fade.toValue = 0.0
            fade.duration = glowDuration
            fade.timingFunction = CAMediaTimingFunction(name: .easeOut)
            glowLayer.add(fade, forKey: glowFadeKey)
        }
        // Pop the whole overlay to full opacity, then dim back to the user's selected opacity.
        panel.alphaValue = 1.0
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = glowDuration
            panel.animator().alphaValue = CGFloat(currentOpacity)
        }
    }

    /// Applies a saved origin only if it still lands (mostly) on some screen; otherwise heals to the
    /// corner and persists that, so an off-screen saved position can never strand the overlay.
    func applyOrigin(x: Double?, y: Double?) {
        if let x, let y, isOnScreen(CGPoint(x: x, y: y)) {
            panel.setFrameOrigin(CGPoint(x: x, y: y))
        } else {
            positionCorner()
            onOriginChanged?(panel.frame.origin)
        }
    }

    func setOpacity(_ opacity: Double) {
        currentOpacity = opacity
        panel.alphaValue = CGFloat(opacity)
    }

    /// Highlight/unhighlight the key at a matrix position as it is pressed/released.
    func setKeyPressed(row: Int, col: Int, down: Bool) {
        if down { view.pressedMatrix.insert([row, col]) } else { view.pressedMatrix.remove([row, col]) }
        view.needsDisplay = true
    }

    /// Clear all held-key highlights (used on a keymap re-sync to drop any orphaned press).
    func clearPressed() {
        guard !view.pressedMatrix.isEmpty else { return }
        view.pressedMatrix.removeAll()
        view.needsDisplay = true
    }

    func resetPosition() {
        positionCorner()
        onOriginChanged?(panel.frame.origin)
    }

    /// True if at least half the panel's frame at `origin` is visible on some screen — a lone
    /// on-screen sliver doesn't count, so a barely-visible saved position still heals to the corner.
    private func isOnScreen(_ origin: CGPoint) -> Bool {
        let frame = NSRect(origin: origin, size: panel.frame.size)
        let area = frame.width * frame.height
        guard area > 0 else { return false }
        return NSScreen.screens.contains { screen in
            let visible = screen.visibleFrame.intersection(frame)
            return visible.width * visible.height >= area * 0.5
        }
    }

    private func positionCorner() {
        guard let screen = NSScreen.main else { return }
        let vf = screen.visibleFrame
        let size = panel.frame.size
        panel.setFrameOrigin(NSPoint(x: vf.maxX - size.width - 18, y: vf.maxY - size.height - 18))
    }
}
