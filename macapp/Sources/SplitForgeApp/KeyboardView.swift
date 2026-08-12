import AppKit
import SplitForgeCore

/// Draws the keyboard's split shape with each key's label for the current layer. Scales the
/// definition's key-unit geometry to fit the view (via `KeyboardLayout.bounds`). Non-flipped
/// coordinates; KLE `y` (top-down) is inverted so the top row renders at the top.
final class KeyboardView: NSView {
    var keys: [KeyboardModel.PositionedKey] = []
    var layerLabel: String = ""
    /// Matrix positions ([row, col]) currently held down — drawn highlighted.
    var pressedMatrix: Set<[Int]> = []

    override func draw(_ dirtyRect: NSRect) {
        NSColor(calibratedWhite: 0.08, alpha: 0.86).setFill()
        NSBezierPath(roundedRect: bounds, xRadius: 16, yRadius: 16).fill()

        let headerH: CGFloat = 24
        let pad: CGFloat = 14

        if !layerLabel.isEmpty {
            draw(layerLabel, at: NSPoint(x: pad, y: bounds.height - 20),
                 font: .systemFont(ofSize: 13, weight: .semibold), color: .white.withAlphaComponent(0.9))
        }

        guard !keys.isEmpty else {
            drawCentered("Reading keymap…", font: .systemFont(ofSize: 12),
                         color: .white.withAlphaComponent(0.6))
            return
        }

        let b = KeyboardLayout.bounds(of: keys)
        guard b.width > 0, b.height > 0 else { return }

        let area = NSRect(x: pad, y: pad, width: bounds.width - pad * 2, height: bounds.height - headerH - pad)
        guard area.width > 0, area.height > 0 else { return } // panel too small to draw into
        let scale = min(area.width / CGFloat(b.width), area.height / CGFloat(b.height))
        let drawnW = CGFloat(b.width) * scale, drawnH = CGFloat(b.height) * scale
        let ox = area.minX + (area.width - drawnW) / 2
        let oy = area.minY + (area.height - drawnH) / 2

        for key in keys {
            let kw = CGFloat(key.width) * scale, kh = CGFloat(key.height) * scale
            let kx = ox + CGFloat(key.x - b.x) * scale
            // Invert y: KLE grows downward, AppKit grows upward.
            let ky = oy + drawnH - CGFloat(key.y - b.y) * scale - kh
            let gap = scale * 0.09
            let r = NSRect(x: kx + gap / 2, y: ky + gap / 2, width: kw - gap, height: kh - gap)

            let isPressed = pressedMatrix.contains(key.matrix)
            (isPressed ? NSColor.systemBlue : NSColor(calibratedWhite: 0.24, alpha: 1)).setFill()
            NSBezierPath(roundedRect: r, xRadius: 4, yRadius: 4).fill()

            let hasHold = (key.hold?.isEmpty == false)
            let hasShifted = (key.shifted?.isEmpty == false)

            if !key.label.isEmpty {
                // Slightly smaller primary when a top-corner sub-label (hold or shifted) shares the
                // key, so the flanking glyphs have room; shrink to fit width.
                let base = min(r.height * 0.42, 15)
                let start = max(7, (hasHold || hasShifted) ? base * 0.86 : base)
                let s = fitted(key.label, weight: .medium, color: .white,
                               startSize: start, maxWidth: r.width - 4, floor: 6)
                let sz = s.size()
                s.draw(at: NSPoint(x: r.midX - sz.width / 2, y: r.midY - sz.height / 2))
            }

            if let shifted = key.shifted, !shifted.isEmpty {
                // US-ANSI Shift symbol: small dimmed glyph in the top-LEFT corner — a mirror of the
                // hold sub-label (top-right). It's always a single character (see KeycodeLabeler.
                // shiftedSymbol), so it stays narrow and won't collide with the top-right hold glyph.
                // Skip if it still won't fit rather than clip.
                let s = fitted(shifted, weight: .semibold, color: .white.withAlphaComponent(0.55),
                               startSize: max(5, r.height * 0.26), maxWidth: r.width * 0.7, floor: 5)
                let sz = s.size()
                if sz.width <= r.width && sz.height <= r.height {
                    s.draw(at: NSPoint(x: r.minX + 2, y: r.maxY - sz.height - 2))
                }
            }

            if let hold = key.hold, !hold.isEmpty {
                // Small dimmed sub-label in the top-right corner; shrink to fit rather than skip.
                let s = fitted(hold, weight: .semibold, color: .white.withAlphaComponent(0.55),
                               startSize: max(5, r.height * 0.26), maxWidth: r.width * 0.7, floor: 5)
                let sz = s.size()
                if sz.width <= r.width && sz.height <= r.height {
                    s.draw(at: NSPoint(x: r.maxX - sz.width - 2, y: r.maxY - sz.height - 2))
                }
            }
        }
    }

    private func attributed(_ text: String, font: NSFont, color: NSColor) -> NSAttributedString {
        NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: color])
    }

    /// Builds the string at `startSize`, shrinking the font (down to `floor`) until it fits `maxWidth`.
    private func fitted(_ text: String, weight: NSFont.Weight, color: NSColor,
                        startSize: CGFloat, maxWidth: CGFloat, floor: CGFloat) -> NSAttributedString {
        var size = startSize
        var string = attributed(text, font: .systemFont(ofSize: size, weight: weight), color: color)
        while string.size().width > maxWidth && size > floor {
            size -= 0.5
            string = attributed(text, font: .systemFont(ofSize: size, weight: weight), color: color)
        }
        return string
    }

    private func draw(_ text: String, at point: NSPoint, font: NSFont, color: NSColor) {
        attributed(text, font: font, color: color).draw(at: point)
    }

    private func drawCentered(_ text: String, font: NSFont, color: NSColor) {
        let s = attributed(text, font: font, color: color)
        let sz = s.size()
        s.draw(at: NSPoint(x: bounds.midX - sz.width / 2, y: bounds.midY - sz.height / 2))
    }
}
