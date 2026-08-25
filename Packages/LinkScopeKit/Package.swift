// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "LinkScopeKit",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .library(name: "LinkScopeCore", targets: ["LinkScopeCore"]),
        .library(name: "LinkScopePersistence", targets: ["LinkScopePersistence"]),
        .library(name: "LinkScopeProviders", targets: ["LinkScopeProviders"]),
        .library(name: "LinkScopeUI", targets: ["LinkScopeUI"])
    ],
    targets: [
        .target(
            name: "LinkScopeCore",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .target(
            name: "LinkScopePersistence",
            dependencies: ["LinkScopeCore"],
            swiftSettings: [.swiftLanguageMode(.v6)],
            linkerSettings: [
                .linkedLibrary("sqlite3"),
                .linkedFramework("LocalAuthentication"),
                .linkedFramework("Security")
            ]
        ),
        .target(
            name: "LinkScopeProviders",
            dependencies: ["LinkScopeCore"],
            swiftSettings: [.swiftLanguageMode(.v6)],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("CoreAudio"),
                .linkedFramework("CoreBluetooth"),
                .linkedFramework("CoreHID"),
                .linkedFramework("GameController"),
                .linkedFramework("IOBluetooth"),
                .linkedFramework("IOKit")
            ]
        ),
        .target(
            name: "LinkScopeUI",
            dependencies: [
                "LinkScopeCore",
                "LinkScopePersistence",
                "LinkScopeProviders"
            ],
            resources: [.process("Resources")],
            swiftSettings: [.swiftLanguageMode(.v6)],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("AppIntents"),
                .linkedFramework("Charts"),
                .linkedFramework("CoreBluetooth"),
                .linkedFramework("ServiceManagement")
            ]
        ),
        .testTarget(
            name: "LinkScopeCoreTests",
            dependencies: ["LinkScopeCore"]
        ),
        .testTarget(
            name: "LinkScopePersistenceTests",
            dependencies: ["LinkScopeCore", "LinkScopePersistence"]
        ),
        .testTarget(
            name: "LinkScopeProviderTests",
            dependencies: ["LinkScopeCore", "LinkScopeProviders"]
        )
    ]
)
