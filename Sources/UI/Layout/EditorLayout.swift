#if canImport(UIKit)
import SwiftUI
import Editor
import Render
import Media
import Export
import AI

/// Main editor layout for iPhone — preview, toolbar, timeline.
public struct EditorLayout: View {
    @ObservedObject var appState: AppState
    @State private var showingImporter = false
    @State private var showingExport = false
    @State private var showingClipEditor = false
    @State private var showingAspectPicker = false
    @State private var showingTextEditor = false
    @State private var showingTransitionPicker = false
    @State private var editingTextClip = TextClip()

    public init(appState: AppState) {
        self.appState = appState
    }

    public var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Preview
                PreviewCanvas(
                    player: appState.previewPlayer,
                    aspectRatio: appState.project.timeline.resolution.aspectRatio
                )
                .frame(maxHeight: .infinity)

                // Transport controls
                TransportControls(player: appState.previewPlayer)

                Divider()

                // Toolbar
                EditorToolbar(
                    canUndo: appState.editHistory.canUndo,
                    canRedo: appState.editHistory.canRedo,
                    hasSelection: appState.selectedClipId != nil,
                    onUndo: { appState.undo() },
                    onRedo: { appState.redo() },
                    onSplit: { appState.splitSelectedClipAtPlayhead() },
                    onDelete: { appState.deleteSelectedClip() },
                    onImport: { showingImporter = true },
                    onText: { showingTextEditor = true },
                    onTransition: { showingTransitionPicker = true },
                    onEdit: { showingClipEditor = true },
                    onExport: { showingExport = true }
                )

                Divider()

                // Timeline
                TimelineView(
                    viewModel: appState.timelineViewModel,
                    onClipSelected: { appState.selectedClipId = $0 },
                    onTimeChanged:  { appState.previewPlayer.seek(to: $0) },
                    onClipMoved:    { appState.moveClip($0, toTime: $1) },
                    onClipTrimmed:  { id, edge, delta in
                        let e: AppState.TrimEdge = edge == .start ? .start : .end
                        appState.trimClip(id, edge: e, delta: delta)
                    }
                )
                .frame(height: 200)
            }
            .background(Color(uiColor: .systemBackground))
            .navigationTitle(appState.project.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { appState.closeProject() } label: {
                        Label("Projects", systemImage: "chevron.left")
                    }
                }
                ToolbarItemGroup(placement: .primaryAction) {
                    Button { showingAspectPicker = true } label: {
                        Label("Aspect Ratio", systemImage: "aspectratio")
                    }
                }
            }
            .sheet(isPresented: $showingImporter) {
                MediaImporterSheet(
                    mediaLibrary: appState.mediaLibrary,
                    onAssetImported: { appState.addClipFromAsset($0) }
                )
            }
            .sheet(isPresented: $showingExport) {
                ExportView(
                    exportEngine: appState.exportEngine,
                    onExport: { try await appState.export(preset: $0) },
                    onDismiss: { showingExport = false }
                )
            }
            .sheet(isPresented: $showingClipEditor) {
                ClipEditorSheet(appState: appState)
            }
            .sheet(isPresented: $showingTextEditor) {
                TextEditorView(
                    textClip: $editingTextClip,
                    onDone: {
                        appState.addTextOverlay(
                            text: editingTextClip.text,
                            style: editingTextClip.style
                        )
                        editingTextClip = TextClip()
                        showingTextEditor = false
                    },
                    onCancel: {
                        editingTextClip = TextClip()
                        showingTextEditor = false
                    }
                )
            }
            .sheet(isPresented: $showingTransitionPicker) {
                TransitionPickerView(
                    onApply: { transition in
                        // Find two adjacent clips to place the transition between
                        let tracks = appState.project.timeline.videoTracks
                        if let track = tracks.first,
                           track.clips.count >= 2 {
                            let sorted = track.clips.sorted { $0.timelineStart < $1.timelineStart }
                            // Find the pair closest to the playhead
                            let time = appState.previewPlayer.currentTime
                            for i in 0..<(sorted.count - 1) {
                                let gap = sorted[i + 1].timelineStart - sorted[i].timelineEnd
                                if abs(gap) < 1.0 || time >= sorted[i].timelineStart && time <= sorted[i + 1].timelineEnd {
                                    appState.addTransition(
                                        transition,
                                        from: sorted[i].id,
                                        to: sorted[i + 1].id
                                    )
                                    break
                                }
                            }
                        }
                        showingTransitionPicker = false
                    },
                    onCancel: { showingTransitionPicker = false }
                )
            }
            .confirmationDialog("Aspect Ratio", isPresented: $showingAspectPicker, titleVisibility: .visible) {
                ForEach(Project.AspectRatioPreset.allCases.filter { $0 != .custom }, id: \.self) { preset in
                    Button(preset.displayName) {
                        appState.setAspectRatio(preset)
                    }
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }
}

// MARK: - Toolbar

struct EditorToolbar: View {
    let canUndo: Bool
    let canRedo: Bool
    let hasSelection: Bool
    let onUndo: () -> Void
    let onRedo: () -> Void
    let onSplit: () -> Void
    let onDelete: () -> Void
    let onImport: () -> Void
    let onText: () -> Void
    let onTransition: () -> Void
    let onEdit: () -> Void
    let onExport: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ToolbarButton(icon: "arrow.uturn.backward", label: "Undo",   isEnabled: canUndo, action: onUndo)
                ToolbarButton(icon: "arrow.uturn.forward",  label: "Redo",   isEnabled: canRedo, action: onRedo)
                Divider().frame(height: 24)
                ToolbarButton(icon: "plus.rectangle",       label: "Import", action: onImport)
                ToolbarButton(icon: "textformat",           label: "Text",   action: onText)
                ToolbarButton(icon: "arrow.triangle.swap",  label: "Trans.",  action: onTransition)
                ToolbarButton(icon: "scissors",             label: "Split",  isEnabled: hasSelection, action: onSplit)
                ToolbarButton(icon: "slider.horizontal.3",  label: "Edit",   isEnabled: hasSelection, action: onEdit)
                ToolbarButton(icon: "trash",                label: "Delete", isEnabled: hasSelection, action: onDelete)
                Divider().frame(height: 24)
                ToolbarButton(icon: "square.and.arrow.up",  label: "Export", action: onExport)
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
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon).font(.system(size: 18))
                Text(label).font(.system(size: 10))
            }
            .foregroundColor(isEnabled ? .primary : .secondary.opacity(0.5))
        }
        .disabled(!isEnabled)
    }
}

// MARK: - Clip editor sheet (iPhone)

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
                    PropertiesPanel(clip: appState.selectedClip,
                                    onUpdate: { appState.updateClip($0) })
                case .effects:
                    EffectListPanel(
                        clip: appState.selectedClip,
                        onAddEffect: { appState.addEffect($0) },
                        onUpdateEffect: { _, updated in
                            guard let cid = appState.selectedClipId else { return }
                            appState.updateEffect(updated, on: cid)
                        },
                        onRemoveEffect: { eid in
                            guard let cid = appState.selectedClipId else { return }
                            appState.removeEffect(eid, from: cid)
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

// MARK: - Media importer sheet

struct MediaImporterSheet: View {
    @ObservedObject var mediaLibrary: MediaLibrary
    let onAssetImported: (MediaLibrary.MediaAsset) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            MediaBrowserView(
                mediaLibrary: mediaLibrary,
                onAssetSelected: { onAssetImported($0); dismiss() },
                onImportTapped: {}
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
