import Foundation

/// Loads `KeyboardDefinition`s from JSON. This is the one Core file that needs Foundation
/// (`JSONDecoder` + `Bundle`); everything else in Core stays Foundation-free.
public enum DefinitionLoader {
    public enum LoaderError: Error, Equatable { case resourceNotFound(String) }

    /// Decode and validate a definition from raw JSON bytes.
    public static func decode(_ data: Data) throws -> KeyboardDefinition {
        let definition = try JSONDecoder().decode(KeyboardDefinition.self, from: data)
        try definition.validate()
        return definition
    }

    /// Load a bundled definition resource by base name (e.g. "totem").
    public static func loadBundled(_ name: String) throws -> KeyboardDefinition {
        let url = Bundle.module.url(forResource: name, withExtension: "json")
            ?? Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Resources")
        guard let url else { throw LoaderError.resourceNotFound(name) }
        return try decode(try Data(contentsOf: url))
    }
}
