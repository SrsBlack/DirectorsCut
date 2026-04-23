#if canImport(UIKit)
import SwiftUI
import Editor

/// Home screen — lists saved projects with create / open / delete.
public struct ProjectBrowserView: View {
    @State private var projects: [ProjectEntry] = []
    @State private var showingNewProject = false
    @State private var newProjectName = ""
    @State private var selectedAspect: Project.AspectRatioPreset = .portrait9x16
    @State private var projectToDelete: ProjectEntry?

    @State private var showingSettings = false

    let onOpenProject: (URL) -> Void
    let onNewProject: (Project) -> Void

    public struct ProjectEntry: Identifiable {
        public let id = UUID()
        public let url: URL
        public let name: String
        public let modifiedDate: Date
        public let fileSize: Int64

        public var formattedDate: String {
            let f = RelativeDateTimeFormatter()
            f.unitsStyle = .short
            return f.localizedString(for: modifiedDate, relativeTo: Date())
        }

        public var formattedSize: String {
            ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
        }
    }

    public init(
        onOpenProject: @escaping (URL) -> Void,
        onNewProject: @escaping (Project) -> Void
    ) {
        self.onOpenProject = onOpenProject
        self.onNewProject = onNewProject
    }

    public var body: some View {
        NavigationView {
            Group {
                if projects.isEmpty {
                    emptyState
                } else {
                    projectList
                }
            }
            .navigationTitle("Directors Cut")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { showingSettings = true } label: {
                        Image(systemName: "gearshape")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { showingNewProject = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .onAppear { loadProjects() }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .alert("New Project", isPresented: $showingNewProject) {
                TextField("Project Name", text: $newProjectName)
                Button("Create") { createProject() }
                Button("Cancel", role: .cancel) { newProjectName = "" }
            } message: {
                Text("Enter a name for your new project")
            }
            .confirmationDialog(
                "Delete Project?",
                isPresented: .init(
                    get: { projectToDelete != nil },
                    set: { if !$0 { projectToDelete = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    if let entry = projectToDelete {
                        deleteProject(entry)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                if let entry = projectToDelete {
                    Text("Delete \"\(entry.name)\"? This cannot be undone.")
                }
            }
        }
    }

    // MARK: - Subviews

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "film.stack")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            Text("No Projects Yet")
                .font(.title2).fontWeight(.semibold)
            Text("Create your first project to start editing")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Button {
                showingNewProject = true
            } label: {
                Label("New Project", systemImage: "plus.circle.fill")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            Spacer()
        }
    }

    private var projectList: some View {
        List {
            // Quick-create row
            Section {
                Button { showingNewProject = true } label: {
                    Label("New Project", systemImage: "plus.circle.fill")
                }
            }

            // Existing projects
            Section("Recent Projects") {
                ForEach(projects) { entry in
                    Button {
                        onOpenProject(entry.url)
                    } label: {
                        ProjectRow(entry: entry)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            projectToDelete = entry
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }

    // MARK: - Logic

    private func loadProjects() {
        guard let urls = try? ProjectFile.listProjects() else { return }
        projects = urls.compactMap { url in
            guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path) else { return nil }
            let date = attrs[.modificationDate] as? Date ?? .distantPast
            let size = attrs[.size] as? Int64 ?? 0
            let name = url.deletingPathExtension().lastPathComponent
            return ProjectEntry(url: url, name: name, modifiedDate: date, fileSize: size)
        }
    }

    private func createProject() {
        let name = newProjectName.isEmpty ? "Untitled" : newProjectName
        let project = Project(name: name, aspectRatioPreset: selectedAspect)
        newProjectName = ""
        onNewProject(project)
    }

    private func deleteProject(_ entry: ProjectEntry) {
        try? ProjectFile.delete(at: entry.url)
        projectToDelete = nil
        loadProjects()
    }
}

/// A row in the project list.
struct ProjectRow: View {
    let entry: ProjectBrowserView.ProjectEntry

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.accentColor.opacity(0.15))
                .frame(width: 56, height: 42)
                .overlay(
                    Image(systemName: "film")
                        .foregroundColor(.accentColor)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(entry.name)
                    .font(.subheadline).fontWeight(.medium)
                    .foregroundColor(.primary)
                HStack(spacing: 8) {
                    Text(entry.formattedDate)
                    Text("·")
                    Text(entry.formattedSize)
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}
#endif
