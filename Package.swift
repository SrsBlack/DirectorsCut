// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "DirectorsCut",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "DirectorsCutEditor",
            targets: ["Editor"]
        ),
        .library(
            name: "DirectorsCutRender",
            targets: ["Render"]
        ),
        .library(
            name: "DirectorsCutEffects",
            targets: ["Effects"]
        ),
        .library(
            name: "DirectorsCutAI",
            targets: ["AI"]
        ),
        .library(
            name: "DirectorsCutExport",
            targets: ["Export"]
        ),
        .library(
            name: "DirectorsCutMedia",
            targets: ["Media"]
        ),
        .library(
            name: "DirectorsCutUI",
            targets: ["UI"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/argmaxinc/WhisperKit.git", from: "0.9.0"),
    ],
    targets: [
        // Core editor engine: timeline model, undo/redo, serialization
        .target(
            name: "Editor",
            dependencies: [],
            path: "Sources/Editor"
        ),

        // Video render pipeline: AVComposition builder, Metal compositor, preview
        .target(
            name: "Render",
            dependencies: ["Editor", "Effects"],
            path: "Sources/Render"
        ),

        // Metal GPU effects: shaders, color grading, transitions
        .target(
            name: "Effects",
            dependencies: [],
            path: "Sources/Effects",
            resources: [
                .process("Shaders")
            ]
        ),

        // AI features: WhisperKit captions, Vision segmentation, tracking
        .target(
            name: "AI",
            dependencies: [
                "Editor",
                .product(name: "WhisperKit", package: "WhisperKit"),
            ],
            path: "Sources/AI"
        ),

        // Export engine: AVAssetWriter, quality presets, share
        .target(
            name: "Export",
            dependencies: ["Editor", "Render"],
            path: "Sources/Export"
        ),

        // Asset management: import, thumbnails, waveforms
        .target(
            name: "Media",
            dependencies: ["Editor"],
            path: "Sources/Media"
        ),

        // UI components: timeline, preview, panels, layout
        .target(
            name: "UI",
            dependencies: ["Editor", "Render", "Effects", "Media", "Export", "AI"],
            path: "Sources/UI"
        ),

        // App entry point
        .target(
            name: "App",
            dependencies: ["UI", "Editor", "Render", "Effects", "Media", "Export", "AI"],
            path: "Sources/App"
        ),

        // Tests
        .testTarget(
            name: "EditorTests",
            dependencies: ["Editor"],
            path: "Tests/EditorTests"
        ),
        .testTarget(
            name: "RenderTests",
            dependencies: ["Render", "Editor"],
            path: "Tests/RenderTests"
        ),
        .testTarget(
            name: "ExportTests",
            dependencies: ["Export", "Editor", "Render"],
            path: "Tests/ExportTests"
        ),
    ]
)
