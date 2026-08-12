// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SplitForge",
    platforms: [.macOS(.v13)],
    targets: [
        // Pure logic — no IOKit/AppKit imports, fully unit-testable. Bundles keyboard
        // definitions (e.g. totem.json) as resources, loaded via DefinitionLoader.
        .target(name: "SplitForgeCore", resources: [.process("Resources")]),

        // IOKit boundary: the concrete HIDTransport implementation. Kept separate so Core
        // stays pure and the app/spike/tests depend on IOKit only where they must.
        .target(
            name: "SplitForgeHID",
            dependencies: ["SplitForgeCore"],
            linkerSettings: [.linkedFramework("IOKit")]
        ),

        // M0 feasibility spike, now driving the real VialClient over IOKitHIDTransport.
        .executableTarget(
            name: "splitforge-spike",
            dependencies: ["SplitForgeCore", "SplitForgeHID"],
            linkerSettings: [.linkedFramework("IOKit")]
        ),

        // The menu-bar app: renders the Totem shape + live legends across three surfaces.
        .executableTarget(
            name: "SplitForgeApp",
            dependencies: ["SplitForgeCore", "SplitForgeHID"],
            linkerSettings: [.linkedFramework("AppKit"), .linkedFramework("ServiceManagement")]
        ),

        .testTarget(
            name: "SplitForgeCoreTests",
            dependencies: ["SplitForgeCore"]
        ),
    ]
)
