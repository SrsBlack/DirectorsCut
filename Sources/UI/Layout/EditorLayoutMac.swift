#if canImport(UIKit)
import SwiftUI

/// Expanded editor layout for iPad and Mac — sidebar + main panel split.
public struct EditorLayoutMac: View {
    @ObservedObject var appState: AppState
    @State private var showingExport = false
    @State private var showingTextEditor = false
    @State private var editingTextClip = TextClip()
    @State private var sidebarSelection: SidebarTab = .media
    @State private var inspectorVisible = true

    enum SidebarTab: String, CaseIterable {
        case media   = "photo.on.rectangle"
        case effects = "wand.and.stars"
        case text    = "textformat"
        case ai      = "brain.head.profile"

        var label: String {
            switch self {
            case .media:   return "Media"
            case .effects: return "Effects"
            case .text:    return "Text"
            case .ai:      return "AI"
            }
        }
    }

    public init(appState: AppState) {
        self.appState = appState
    }

    public var body: some View {
        NavigationSplitView(columnVisibility: .constant(.all)) {
            sidebar
                .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 320)
        } content: {
            centreContent
                .navigationSplitViewColumnWidth(min: 500, ideal: 700)
        } detail: {
            if inspectorVisible {
                inspector
                    .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 340)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button { showingExport = true } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                Button { inspectorVisible.toggle() } label: {
                    Label("Inspector", systemImage: "sidebar.right")
                }
            }
            ToolbarItemGroup(placement: .navigation) {
                Button { appState.closeProject() } label: {
                    Label("Projects", systemImage: "chevron.left")
                }
                Button { appState.undo() } label: {
                    Label("Undo", systemImage: "arrow.uturn.backward")
                }.disabled(!appState.editHistory.canUndo)
                Button { appState.redo() } label: {
                    Label("Redo", systemImage: "arrow.uturn.forward")
                }.disabled(!appState.editHistory.canRedo)
            }
        }
        .sheet(isPresented: $showingExport) {
            ExportView(
                exportEngine: appState.exportEngine,
                onExport: { try await appState.export(preset: $0) },
                onDismiss: { showingExport = false }
            )
        }
        .sheet(isPresented: $showingTextEditor) {
            TextEditorView(
                textClip: $editingTextClip,
                onDone: {
                    appState.addTextOverlay(text: editingTextClip.text, style: editingTextClip.style)
                    editingTextClip = TextClip()
                    showingTextEditor = false
                },
                onCancel: {
                    editingTextClip = TextClip()
                    showingTextEditor = false
                }
            )
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(spacing: 0) {
            Picker("Panel", selection: $sidebarSelection) {
                ForEach(SidebarTab.allCases, id: \.self) { tab in
                    Label(tab.label, systemImage: tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(8)

            Divider()

            switch sidebarSelection {
            case .media:
                MediaBrowserView(
                    mediaLibrary: appState.mediaLibrary,
                    onAssetSelected: { appState.addClipFromAsset($0) },
                    onImportTapped: {}
                )
            case .effects:
                EffectListPanel(
                    clip: selectedClip,
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
            case .text:
                textOverlayList
            case .ai:
                AIToolPanel()
            }
        }
        .navigationTitle("Directors Cut")
    }

    // MARK: - Text overlay list

    private var textOverlayList: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Text Overlays").font(.headline)
                Spacer()
                Button { showingTextEditor = true } label: {
                    Image(systemName: "plus.circle.fill").font(.title3)
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 8)

            Divider()

            if appState.project.timeline.textOverlays.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "textformat").font(.system(size: 36)).foregroundColor(.secondary)
                    Text("No text overlays").font(.subheadline).foregroundColor(.secondary)
                    Button("Add Text") { showingTextEditor = true }
                        .buttonStyle(.borderedProminent).controlSize(.small)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                List {
                    ForEach(appState.project.timeline.textOverlays) { tc in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(tc.text).font(.subheadline).lineLimit(1)
                                Text(String(format: "%.1fs – %.1fs", tc.timelineStart, tc.timelineEnd))
                                    .font(.caption).foregroundColor(.secondary)
                            }
                            Spacer()
                            Button(role: .destructive) {
                                appState.removeTextOverlay(id: tc.id)
                            } label: {
                                Image(systemName: "trash").font(.caption)
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    // MARK: - Centre

    private var centreContent: some View {
        VStack(spacing: 0) {
            PreviewCanvas(
                player: appState.previewPlayer,
                aspectRatio: appState.project.timeline.resolution.aspectRatio
            )
            .frame(maxHeight: .infinity)

            TransportControls(player: appState.previewPlayer)
                .padding(.vertical, 6)

            Divider()

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
            .frame(height: 220)
        }
        .navigationTitle(appState.project.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Inspector

    private var inspector: some View {
        ScrollView {
            VStack(spacing: 12) {
                PropertiesPanel(
                    clip: selectedClip,
                    onUpdate: { appState.updateClip($0) }
                )
            }
            .padding(12)
        }
        .navigationTitle("Inspector")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var selectedClip: Clip? {
        guard let id = appState.selectedClipId,
              let (ti, ci) = appState.project.timeline.findClip(id: id) else { return nil }
        return appState.project.timeline.tracks[ti].clips[ci]
    }
}
#endif
