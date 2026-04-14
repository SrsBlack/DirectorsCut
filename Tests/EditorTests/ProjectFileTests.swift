import XCTest
@testable import Editor

final class ProjectFileTests: XCTestCase {
    func testProjectSaveAndLoad() throws {
        let project = Project(name: "Test Project")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_project")
            .appendingPathExtension(ProjectFile.fileExtension)

        try ProjectFile.save(project, to: url)
        let loaded = try ProjectFile.load(from: url)

        XCTAssertEqual(loaded.id, project.id)
        XCTAssertEqual(loaded.name, "Test Project")
        XCTAssertEqual(loaded.timeline.tracks.count, project.timeline.tracks.count)

        // Cleanup
        try? FileManager.default.removeItem(at: url)
    }

    func testProjectWithClips() throws {
        var project = Project(name: "Clip Test")
        let clip = Clip(
            sourceURL: URL(string: "file:///test.mp4")!,
            mediaType: .video,
            timelineStart: 2.0,
            duration: 10.0,
            sourceDuration: 30.0,
            speed: 1.5,
            name: "My Clip"
        )
        project.timeline.tracks[0].addClip(clip)

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_clips")
            .appendingPathExtension(ProjectFile.fileExtension)

        try ProjectFile.save(project, to: url)
        let loaded = try ProjectFile.load(from: url)

        XCTAssertEqual(loaded.timeline.tracks[0].clips.count, 1)
        let loadedClip = loaded.timeline.tracks[0].clips[0]
        XCTAssertEqual(loadedClip.name, "My Clip")
        XCTAssertEqual(loadedClip.speed, 1.5)
        XCTAssertEqual(loadedClip.timelineStart, 2.0)
        XCTAssertEqual(loadedClip.duration, 10.0)

        try? FileManager.default.removeItem(at: url)
    }

    func testProjectWithEffects() throws {
        var project = Project(name: "Effect Test")
        var clip = Clip(
            sourceURL: URL(string: "file:///test.mp4")!,
            mediaType: .video,
            duration: 10.0,
            sourceDuration: 30.0
        )
        clip.effects = [.colorCorrection(), .blur(radius: 15)]
        project.timeline.tracks[0].addClip(clip)

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_effects")
            .appendingPathExtension(ProjectFile.fileExtension)

        try ProjectFile.save(project, to: url)
        let loaded = try ProjectFile.load(from: url)

        let loadedClip = loaded.timeline.tracks[0].clips[0]
        XCTAssertEqual(loadedClip.effects.count, 2)
        XCTAssertEqual(loadedClip.effects[0].type, .colorCorrection)
        XCTAssertEqual(loadedClip.effects[1].type, .gaussianBlur)

        try? FileManager.default.removeItem(at: url)
    }

    func testFileExtension() {
        XCTAssertEqual(ProjectFile.fileExtension, "dcut")
    }
}
