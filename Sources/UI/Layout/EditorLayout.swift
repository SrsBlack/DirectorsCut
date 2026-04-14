#if canImport(UIKit)
import SwiftUI

/// Main editor layout for iPhone - vertical stack of preview, toolbar, and timeline.
public struct EditorLayout: View {
    @StateObject private var appState = AppState()
    @State private var showingImporter = false
    @State private var showingExport = false
    @State private var activePanel: SidePanel = .media

    enum SidePanel {
        case media, properties, effects, ai
    }

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Preview area
            PreviewCanvas(
                player: appState.previewPlayer,
                aspectRatio: appState.project.timeline.resolution.aspectRatio
            )
            .frame(maxHeight: .infinity)

            // Transport controls
            TransportControls(player: appState.previewPlayer)

            Divider()

            // Editing toolbar
            EditorToolbar(
                canUndo: appState.editHistory.canUndo,
                canRedo: appState.editHistory.canRedo,
                onUndo: { appState.undo() },
                onRedo: { appState.redo() },
                onSplit: { appState.timelineViewModel.splitAtPlayhead() },
                onDelete: { appState.timelineViewModel.deleteSelectedClip() },
                onImport: { showingImporter = true },
                onExport: { showingExport = true }
            )

            Divider()

            // Timeline
            TimelineView(
                viewModel: appState.timelineViewModel,
                onClipSelected: { clipId in
                    appState.selectedClipId = clipId
                },
                onTimeChanged: { time in
                    appState.previewPlayer.seek(to: time)
                }
            )
            .frame(height: 200)
        }
        .background(Color(uiColor: .systemBackground))
        .sheet(isPresented: $showingImporter) {
            MediaImporterSheet(
                mediaLibrary: appState.mediaLibrary,
                onAssetImported: { asset in
                    appState.addClipFromAsset(asset)
                }
            )
        }
        .sheet(isPresented: $showingExport) {
            ExportView(
                exportEngine: appState.exportEngine,
                onExport: { preset in
                    try await appState.export(preset: preset)
                },
                onDismiss: { showingExport = false }
            )
        }
    }
}

/// Toolbar with editing actions.
struct EditorToolbar: View {
    let canUndo: Bool
    let canRedo: Bool
    let onUndo: () -> Void
    let onRedo: () -> Void
    let onSplit: () -> Void
    let onDelete: () -> Void
    let onImport: () -> Void
    let onExport: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ToolbarButton(icon: "arrow.uturn.backward", label: "Undo", isEnabled: canUndo, action: onUndo)
                ToolbarButton(icon: "arrow.uturn.forward", label: "Redo", isEnabled: canRedo, action: onRedo)

                Divider().frame(height: 24)

                ToolbarButton(icon: "plus.rectangle", label: "Import", action: onImport)
                ToolbarButton(icon: "scissors", label: "Split", action: onSplit)
                ToolbarButton(icon: "trash", label: "Delete", action: onDelete)

                Divider().frame(height: 24)

                ToolbarButton(icon: "square.and.arrow.up", label: "Export", action: onExport)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
        }
    }
}

struct ToolbarButton: View {
    let icon: String
    let label: String
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                Text(label)
                    .font(.system(size: 10))
            }
            .foregroundColor(isEnabled ? .primary : .secondary.opacity(0.5))
        }
        .disabled(!isEnabled)
    }
}

/// Sheet for importing media
struct MediaImporterSheet: View {
    @ObservedObject var mediaLibrary: MediaLibrary
    let onAssetImported: (MediaLibrary.MediaAsset) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            MediaBrowserView(
                mediaLibrary: mediaLibrary,
                onAssetSelected: { asset in
                    onAssetImported(asset)
                    dismiss()
                },
                onImportTapped: {
                    // PHPicker will be presented
                }
            )
            .navigationTitle("Import Media")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
#endif
