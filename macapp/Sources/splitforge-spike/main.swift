// M0/M2 feasibility spike (not shipped).
//
// Drives the real M2 components end-to-end: IOKitHIDTransport → VialClient (live keymap read)
// + LayerReport (passive layer broadcast), and prints decoded layer-0 legends via KeycodeLabeler.
//
// Run: `swift run splitforge-spike [--vid 0xXXXX] [--pid 0xYYYY] [--any]`
// Needs macOS Input Monitoring permission for the terminal running it.

import Foundation
import SplitForgeCore
import SplitForgeHID

private func parseHexOrDec(_ s: String) -> Int? {
    if s.lowercased().hasPrefix("0x") { return Int(s.dropFirst(2), radix: 16) }
    return Int(s)
}

// Defaults to the Totem (VID 0x3A3C / PID 0x0002); override or match-any via flags.
var vid: Int? = 0x3A3C
var pid: Int? = 0x0002
var args = Array(CommandLine.arguments.dropFirst())
var i = 0
while i < args.count {
    switch args[i] {
    case "--vid": i += 1; if i < args.count { vid = parseHexOrDec(args[i]) }
    case "--pid": i += 1; if i < args.count { pid = parseHexOrDec(args[i]) }
    case "--any": vid = nil; pid = nil
    default: break
    }
    i += 1
}

// Geometry + matrix dims come from the bundled KeyboardDefinition (Totem: 16 layers, 8×5).
let definition = try? DefinitionLoader.loadBundled("totem")
let rows = definition?.matrix.rows ?? 8
let cols = definition?.matrix.cols ?? 5

let transport = IOKitHIDTransport(vid: vid, pid: pid)
let vial = VialClient(transport: transport, layerCount: 16, rows: rows, cols: cols)

vial.onResult = { result in
    switch result {
    case .complete(let layers):
        print("🗺  Keymap read complete: \(layers.count) layers (reported: \(vial.reportedLayerCount.map(String.init) ?? "?"))")
        guard let definition else { return }
        let model = KeyboardModel.live(definition: definition, keycodes: layers)
        print("    Layer 0 (\(definition.name)) legends by position:")
        for key in model.keys(forLayer: 0).sorted(by: { ($0.y, $0.x) < ($1.y, $1.x) }) {
            print("      [\(key.matrix[0]),\(key.matrix[1])] @(\(key.x),\(key.y))  \(key.label)")
        }
    case .incomplete(let missing):
        print("⚠️  Keymap read incomplete; missing offsets: \(missing)")
    }
}

transport.onReport = { report in
    if let layer = LayerReport.decode(report) {
        print("⬆️  Active layer: \(layer)")
        return
    }
    vial.handle(report)
}
transport.onDeviceConnected = {
    print("🔌 Connected. Reading keymap…")
    do { try vial.start() } catch { FileHandle.standardError.write(Data("start failed: \(error)\n".utf8)) }
}
transport.onDeviceDisconnected = { print("🔌 Device removed") }

switch transport.start() {
case .ok:
    let who = vid.map { String(format: "0x%04X", $0) } ?? "any"
    print("✅ Listening on Raw HID usage page 0xff60 (VID \(who)). Switch layers on your keyboard…")
case .notPermitted:
    FileHandle.standardError.write(Data("""
    ❌ Input Monitoring permission denied.
       Grant it in System Settings → Privacy & Security → Input Monitoring
       (enable the terminal running this), then re-run.

    """.utf8))
    exit(1)
case .failed(let r):
    FileHandle.standardError.write(Data("❌ IOHIDManagerOpen failed: \(String(format: "0x%08X", UInt32(bitPattern: r)))\n".utf8))
    exit(1)
}

CFRunLoopRun()
