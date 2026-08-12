// Generates tools/AppIcon.icns — a dark-blue squircle with a white keyboard glyph.
// Run from the repo root:  swift tools/make_icon.swift
import AppKit
import Foundation

func iconPNG(px: Int) -> Data {
    let s = CGFloat(px)
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    rep.size = NSSize(width: px, height: px)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    // Dark-blue squircle background with a subtle vertical gradient.
    let bg = NSRect(x: s * 0.045, y: s * 0.045, width: s * 0.91, height: s * 0.91)
    let gradient = NSGradient(colors: [
        NSColor(red: 0.16, green: 0.20, blue: 0.31, alpha: 1),
        NSColor(red: 0.05, green: 0.06, blue: 0.11, alpha: 1),
    ])!
    gradient.draw(in: NSBezierPath(roundedRect: bg, xRadius: s * 0.22, yRadius: s * 0.22), angle: -90)

    // Centered white keyboard glyph.
    let config = NSImage.SymbolConfiguration(pointSize: s * 0.5, weight: .regular)
        .applying(NSImage.SymbolConfiguration(paletteColors: [.white]))
    if let symbol = NSImage(systemSymbolName: "keyboard", accessibilityDescription: nil)?
        .withSymbolConfiguration(config) {
        let w = symbol.size.width, h = symbol.size.height
        symbol.draw(in: NSRect(x: (s - w) / 2, y: (s - h) / 2, width: w, height: h))
    }

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let outDir = "tools"
let iconset = "\(outDir)/AppIcon.iconset"
let fm = FileManager.default
try? fm.removeItem(atPath: iconset)
try! fm.createDirectory(atPath: iconset, withIntermediateDirectories: true)

let entries: [(String, Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]
for (name, px) in entries {
    try! iconPNG(px: px).write(to: URL(fileURLWithPath: "\(iconset)/\(name).png"))
}

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset, "-o", "\(outDir)/AppIcon.icns"]
try! iconutil.run()
iconutil.waitUntilExit()
try? fm.removeItem(atPath: iconset) // keep only the .icns
print("wrote \(outDir)/AppIcon.icns (iconutil exit \(iconutil.terminationStatus))")
