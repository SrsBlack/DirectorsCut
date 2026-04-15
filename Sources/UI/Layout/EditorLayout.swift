#if canImport(UIKit)
import SwiftUI

/// Main editor layout for iPhone - vertical stack of preview, toolbar, and timeline.
public struct EditorLayout: View {
    @StateObject private var appState = AppState()
    @State private var showingImporter = false
    @State private var showingExport = false
    @State private var showingClipEditor = false

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
                hasSelection: appState.selectedClipId != nil,
                onUndo: { appState.undo() },
                onRedo: { appState.redo() },
                onSplit: { appState.splitSelectedClipAtPlayhead() },
                onDelete: { appState.deleteSelectedClip() },
                onImport: { showingImporter = true },
                onEdit: { showingClipEditor = true },
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
                },
                onClipMoved: { clipId, newStart in
                    appState.moveClip(clipId, toTime: newStart)
                },
                onClipTrimmed: { clipId, edge, delta in
                    let appEdge: AppState.TrimEdge = edge == .start ? .start : .end
                    appState.trimClip(clipId, edge: appEdge, delta: delta)
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
        .sheet(isPresented: $showingClipEditor) {
            ClipEditorSheet(appState: appState)
        }
    }
}

/// Bottom-sheet on iPhone exposing properties + effects for the selected clip.
struct ClipEditorSheet: View {
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var tab: Tab = .properties

    enum Tab: String, CaseIterable {
        case properties = "Properties"
        case effects    = "Effects"
        case ai         = "AI"
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Picker("", selection: $tab) {
                    ForEach(Tab.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(8)

                Divider()

                switch tab {
                case .properties:
                    PropertiesPanel(
                        clip: appState.selectedClip,
                        onUpdate: { updated in appState.updateClip(updated) }
                    )
                case .effects:
                    EffectListPanel(
                        clip: appState.selectedClip,
                        onAddEffect: { type in appState.addEffect(type) },
                        onUpdateEffect: { _, updated in
                            guard let cid = appState.selectedClipId else { return }
                            appState.updateEffect(updated, on: cid)
                        },
                        onRemoveEffect: { effectId in
                            guard let cid = appState.selectedClipId else { return }
                            appState.removeEffect(effectId, from: cid)
                        }
                    )
                case .ai:
                    AIToolPanel()
                }
            }
            .navigationTitle("Edit Clip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

/// Toolbar with editing actions.
struct EditorToolbar: View {
    let canUndo: Bool
    let canRedo: Bool
    let hasSelection: Bool
    let onUndo: () -> Void
    let onRedo: () -> Void
    let onSplit: () -> Void
    let onDelete: () -> Void
    let onImport: () -> Void
    let onEdit: () -> Void
    let onExport: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ToolbarButton(icon: "arrow.uturn.backward", label: "Undo", isEnabled: canUndo, action: onUndo)
                ToolbarButton(icon: "arrow.uturn.forward", label: "Redo", isEnabled: canRedo, action: onRedo)

                Divider().frame(height: 24)

                ToolbarButton(icon: "plus.rectangle", label: "Import", action: onImport)
                ToolbarButton(icon: "scissors", label: "Split", isEnabled: hasSelection, action: onSplit)
                ToolbarButton(icon: "slider.horizontal.3", label: "Edit", isEnabled: hasSelection, action: onEdit)
                ToolbarButton(icon: "trash", label: "Delete", isEnabled: hasSelection, action: onDelete)

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
