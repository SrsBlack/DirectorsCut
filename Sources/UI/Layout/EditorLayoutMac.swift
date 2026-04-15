#if canImport(UIKit)
import SwiftUI

/// Expanded editor layout for iPad and Mac — uses a sidebar + main panel split.
/// On iPhone, EditorLayout is used instead. This kicks in for larger screen sizes.
public struct EditorLayoutMac: View {
    @StateObject private var appState = AppState()
    @State private var showingExport = false
    @State private var sidebarSelection: SidebarTab = .media
    @State private var inspectorVisible = true

    enum SidebarTab: String, CaseIterable {
        case media      = "photo.on.rectangle"
        case effects    = "wand.and.stars"
        case ai         = "brain.head.profile"
        case captions   = "captions.bubble"

        var label: String {
            switch self {
            case .media:    return "Media"
            case .effects:  return "Effects"
            case .ai:       return "AI"
            case .captions: return "Captions"
            }
        }
    }

    public init() {}

    public var body: some View {
        NavigationSplitView(columnVisibility: .constant(.all)) {
            // Left sidebar — media browser / tools
            sidebar
                .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 320)
        } content: {
            // Centre — preview + timeline
            centreContent
                .navigationSplitViewColumnWidth(min: 500, ideal: 700)
        } detail: {
            // Right inspector — properties / effects
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
                Button { appState.undo() } label: {
                    Label("Undo", systemImage: "arrow.uturn.backward")
                }
                .disabled(!appState.editHistory.canUndo)
                Button { appState.redo() } label: {
                    Label("Redo", systemImage: "arrow.uturn.forward")
                }
                .disabled(!appState.editHistory.canRedo)
            }
        }
        .sheet(isPresented: $showingExport) {
            ExportView(
                exportEngine: appState.exportEngine,
                onExport: { preset in try await appState.export(preset: preset) },
                onDismiss: { showingExport = false }
            )
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(spacing: 0) {
            // Tab picker
            Picker("Panel", selection: $sidebarSelection) {
                ForEach(SidebarTab.allCases, id: \.self) { tab in
                    Label(tab.label, systemImage: tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(8)

            Divider()

            // Panel content
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
                    onAddEffect: { type in
                        appState.addEffect(type)
                    },
                    onUpdateEffect: { effectId, updated in
                        guard let clipId = appState.selectedClipId else { return }
                        appState.updateEffect(updated, on: clipId)
                    },
                    onRemoveEffect: { effectId in
                        guard let clipId = appState.selectedClipId else { return }
                        appState.removeEffect(effectId, from: clipId)
                    }
                )
            case .ai:
                AIToolPanel()
            case .captions:
                Text("Captions panel coming in Phase 3")
                    .font(.caption).foregroundColor(.secondary).padding()
            }
        }
        .navigationTitle("Directors Cut")
    }

    // MARK: - Centre

    private var centreContent: some View {
        VStack(spacing: 0) {
            // Preview
            PreviewCanvas(
                player: appState.previewPlayer,
                aspectRatio: appState.project.timeline.resolution.aspectRatio
            )
            .frame(maxHeight: .infinity)

            // Transport
            TransportControls(player: appState.previewPlayer)
                .padding(.vertical, 6)

            Divider()

            // Timeline
            TimelineView(
                viewModel: appState.timelineViewModel,
                onClipSelected: { appState.selectedClipId = $0 },
                onTimeChanged:  { appState.previewPlayer.seek(to: $0) },
                onClipMoved:    { appState.moveClip($0, toTime: $1) },
                onClipTrimmed:  { id, edge, delta in
                    let appEdge: AppState.TrimEdge = edge == .start ? .start : .end
                    appState.trimClip(id, edge: appEdge, delta: delta)
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
                    onUpdate: { updated in
                        appState.updateClip(updated)
                    }
                )
                Divider()
                if let clip = selectedClip, !clip.keyframes.isEmpty {
                    ForEach(clip.keyframes) { track in
                        KeyframeEditor(
                            track: track,
                            duration: appState.project.timeline.duration,
                            currentTime: appState.previewPlayer.currentTime,
                            onAddKeyframe: { _ in },
                            onRemoveKeyframe: { _ in },
                            onUpdateKeyframe: { _ in }
                        )
                    }
                }
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
