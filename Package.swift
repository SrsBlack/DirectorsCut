// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "DirectorsCut",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "DirectorsCutEditor",  targets: ["Editor"]),
        .library(name: "DirectorsCutRender",  targets: ["Render"]),
        .library(name: "DirectorsCutEffects", targets: ["Effects"]),
        .library(name: "DirectorsCutAI",      targets: ["AI"]),
        .library(name: "DirectorsCutExport",  targets: ["Export"]),
        .library(name: "DirectorsCutMedia",   targets: ["Media"]),
        .library(name: "DirectorsCutUI",      targets: ["UI"]),
    ],
    // NOTE: WhisperKit will be added back in Phase 3 when AI features are implemented.
    // To add it: .package(url: "https://github.com/argmaxinc/WhisperKit.git", from: "0.9.0")
    dependencies: [],
    targets: [
        // Core editor engine: timeline model, undo/redo, serialization
        .target(
            name: "Editor",
            dependencies: [],
            path: "Sources/Editor"
        ),

        // Metal GPU effects: shaders, color grading, transitions
        // Depends on Editor for Effect/Transition types used in extensions.
        .target(
            name: "Effects",
            dependencies: ["Editor"],
            path: "Sources/Effects",
            resources: [
                .process("Shaders")
            ]
        ),

        // Video render pipeline: AVComposition builder, Metal compositor, preview
        .target(
            name: "Render",
            dependencies: ["Editor", "Effects"],
            path: "Sources/Render"
        ),

        // AI features: stubs for Phase 1, full implementation in Phase 3
        // (Vision, Core ML, WhisperKit — no external deps until Phase 3)
        .target(
            name: "AI",
            dependencies: ["Editor"],
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
        // Note: the Xcode app target (DirectorsCut.xcodeproj) links against UI
        // and provides the @main entry point — see docs/XcodeSetup.md
        .target(
            name: "UI",
            dependencies: ["Editor", "Render", "Effects", "Media", "Export", "AI"],
            path: "Sources/UI"
        ),

        // App coordinator: AppState, ContentView, DirectorsCutApp entry point
        // FIX(audit-2026-05-09 #A1): Sources/App/ was orphaned — SwiftPM never compiled it.
        // Adding this target makes the 549 LOC visible to the compiler. Latent compile
        // errors in AppState.swift will now surface (that is intentional).
        .target(
            name: "App",
            dependencies: ["UI", "Editor", "Render", "Export", "Effects", "Media"],
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
        .testTarget(
            name: "EffectsTests",
            dependencies: ["Effects", "Editor"],
            path: "Tests/EffectsTests"
        ),
    ]
)
