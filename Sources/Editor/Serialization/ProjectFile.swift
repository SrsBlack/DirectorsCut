import Foundation

/// Handles saving and loading .dcut project files.
public struct ProjectFile {
    /// File extension for Directors Cut projects
    public static let fileExtension = "dcut"

    /// Save a project to a URL
    public static func save(_ project: Project, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(project)
        try data.write(to: url, options: .atomic)
    }

    /// Load a project from a URL
    public static func load(from url: URL) throws -> Project {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Project.self, from: data)
    }

    /// Get the default projects directory (Documents/DirectorsCut/)
    public static var projectsDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dir = docs.appendingPathComponent("DirectorsCut", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Auto-save directory
    public static var autosaveDirectory: URL {
        let dir = projectsDirectory.appendingPathComponent(".autosave", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Generate a URL for a new project
    public static func urlForNewProject(named name: String) -> URL {
        let safeName = name.replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        return projectsDirectory
            .appendingPathComponent(safeName)
            .appendingPathExtension(fileExtension)
    }

    /// Generate an auto-save URL for a project
    public static func autosaveURL(for project: Project) -> URL {
        autosaveDirectory
            .appendingPathComponent(project.id.uuidString)
            .appendingPathExtension(fileExtension)
    }

    /// List all saved projects
    public static func listProjects() throws -> [URL] {
        let contents = try FileManager.default.contentsOfDirectory(
            at: projectsDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )
        return contents
            .filter { $0.pathExtension == fileExtension }
            .sorted { a, b in
                let dateA = (try? a.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let dateB = (try? b.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return dateA > dateB
            }
    }

    /// Delete a project file
    public static func delete(at url: URL) throws {
        try FileManager.default.removeItem(at: url)
    }
}
