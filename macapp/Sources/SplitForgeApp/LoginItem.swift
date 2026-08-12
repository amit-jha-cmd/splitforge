import ServiceManagement

/// Thin wrapper over `SMAppService.mainApp` for the "Launch at Login" toggle. `.status` is the source
/// of truth — we never trust the return of register()/unregister(). Works from a plain-copied install
/// in /Applications or ~/Applications (macOS 13+).
enum LoginItem {
    /// True when the app is (or is pending) a login item. `.requiresApproval` counts as on — the user
    /// has enabled it; macOS is just waiting for them to confirm in System Settings → Login Items.
    static var isEnabled: Bool {
        switch SMAppService.mainApp.status {
        case .enabled, .requiresApproval: return true
        default: return false
        }
    }

    /// Register/unregister, then report the resulting state from a fresh `.status` read.
    @discardableResult
    static func setEnabled(_ enabled: Bool) -> Bool {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // Ignore — `.status` below reflects reality, and `.requiresApproval` is not an error.
        }
        return isEnabled
    }
}
