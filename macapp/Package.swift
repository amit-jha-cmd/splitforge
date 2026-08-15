// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SplitForge",
    platforms: [.macOS(.v13)],
    targets: [
        // Pure logic — no IOKit/AppKit imports, fully unit-testable. Bundles keyboard
        // definitions (e.g. totem.json) as resources, loaded via DefinitionLoader.
        .target(name: "SplitForgeCore", resources: [.process("Resources")]),

        // HID boundary: the concrete HIDTransport implementations — IOKit (local USB) and the
        // Pi-bridge (network). Kept separate so Core stays pure and depends on neither.
        .target(
            name: "SplitForgeHID",
            dependencies: ["SplitForgeCore"],
            linkerSettings: [.linkedFramework("IOKit"), .linkedFramework("Network")]
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
