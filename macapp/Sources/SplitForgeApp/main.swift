import AppKit

// Menu-bar agent app: no dock icon, panels + status item only.
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory) // before run(): agent (accessory) activation
app.run()
