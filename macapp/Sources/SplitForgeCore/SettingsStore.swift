import Foundation

/// Persists `Settings` as a single JSON blob in `UserDefaults`. Foundation lives here (like
/// `DefinitionLoader`); the `UserDefaults` instance is injectable so it is unit-testable in isolation.
public final class SettingsStore {
    private let defaults: UserDefaults
    private let key: String

    public init(defaults: UserDefaults = .standard, key: String = "settings.v1") {
        self.defaults = defaults
        self.key = key
    }

    /// Loads settings, returning `.defaultSettings` on missing or corrupt data. Always normalized.
    public func load() -> Settings {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode(Settings.self, from: data) else {
            return .defaultSettings
        }
        return decoded.normalized()
    }

    public func save(_ settings: Settings) {
        guard let data = try? JSONEncoder().encode(settings.normalized()) else { return }
        defaults.set(data, forKey: key)
    }
}
