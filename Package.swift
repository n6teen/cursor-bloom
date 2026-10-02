// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CursorBloom",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "CursorBloom", targets: ["CursorBloom"])
    ],
    targets: [
        .executableTarget(
            name: "CursorBloom",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ],
            linkerSettings: [
                .linkedLibrary("sqlite3")
            ]
        )
    ]
)
