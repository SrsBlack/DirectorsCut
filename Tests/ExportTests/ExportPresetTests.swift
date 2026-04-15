import XCTest
import AVFoundation
@testable import Export

final class ExportPresetTests: XCTestCase {
    func testAllPresetsExist() {
        XCTAssertGreaterThan(ExportPreset.all.count, 0)
    }

    func test1080pPreset() {
        let preset = ExportPreset.hd1080
        XCTAssertEqual(preset.width, 1920)
        XCTAssertEqual(preset.height, 1080)
        XCTAssertFalse(preset.isHDR)
    }

    func test4KPreset() {
        let preset = ExportPreset.uhd4K
        XCTAssertEqual(preset.width, 3840)
        XCTAssertEqual(preset.height, 2160)
    }

    func test4KHDRPreset() {
        let preset = ExportPreset.uhd4KHDR
        XCTAssertTrue(preset.isHDR)
    }

    func testVerticalPreset() {
        let preset = ExportPreset.vertical1080
        XCTAssertEqual(preset.width, 1080)
        XCTAssertEqual(preset.height, 1920)
    }

    func testVideoSettingsContainCodec() {
        let preset = ExportPreset.hd1080
        let settings = preset.videoSettings
        XCTAssertNotNil(settings[AVVideoCodecKey])
    }

    func testAudioSettingsContainFormat() {
        let preset = ExportPreset.hd1080
        let settings = preset.audioSettings
        XCTAssertNotNil(settings[AVFormatIDKey])
    }
}
