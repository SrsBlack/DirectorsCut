import XCTest
@testable import Editor
@testable import Effects

final class ColorGradingTests: XCTestCase {
    // MARK: - Presets

    func testNeutralPresetIsDefault() {
        let p = ColorGradingParameters.neutral
        XCTAssertEqual(p.exposure, 0)
        XCTAssertEqual(p.brightness, 0)
        XCTAssertEqual(p.contrast, 1)
        XCTAssertEqual(p.saturation, 1)
        XCTAssertEqual(p.temperature, 6500)
        XCTAssertEqual(p.tint, 0)
        XCTAssertEqual(p.highlights, 0)
        XCTAssertEqual(p.shadows, 0)
    }

    func testWarmCinematicPreset() {
        let p = ColorGradingParameters.warmCinematic
        XCTAssertGreaterThan(p.temperature, 6500, "warm preset should bump temperature above neutral")
        XCTAssertLessThan(p.exposure, 0, "warm cinematic typically pulls exposure down")
        XCTAssertGreaterThan(p.contrast, 1, "warm cinematic adds contrast")
    }

    func testCoolMoodyPreset() {
        let p = ColorGradingParameters.coolMoody
        XCTAssertLessThan(p.temperature, 6500, "cool preset should drop temperature below neutral")
        XCTAssertLessThan(p.saturation, 1, "moody preset desaturates")
    }

    func testAllPresetsHaveNames() {
        for (name, _) in ColorGradingParameters.presets {
            XCTAssertFalse(name.isEmpty, "Preset name must not be empty")
        }
    }

    func testPresetsContainNeutral() {
        let names = ColorGradingParameters.presets.map(\.name)
        XCTAssertTrue(names.contains("Neutral"))
    }

    // MARK: - Effect ↔ Parameters round-trip

    func testColorGradingEffectStoresParameters() {
        let params = ColorGradingParameters.warmCinematic
        let effect = Effect.colorGrading(params)
        XCTAssertEqual(effect.type, .colorGrading)

        let recovered = effect.colorGradingParameters
        XCTAssertNotNil(recovered)
        XCTAssertEqual(recovered?.temperature, params.temperature, accuracy: 0.001)
        XCTAssertEqual(recovered?.contrast, params.contrast, accuracy: 0.001)
        XCTAssertEqual(recovered?.saturation, params.saturation, accuracy: 0.001)
    }

    func testColorCorrectionEffectAlsoExposesParameters() {
        let effect = Effect.colorCorrection()
        let params = effect.colorGradingParameters
        XCTAssertNotNil(params, "colorCorrection type should also expose grading parameters")
        XCTAssertEqual(params?.contrast, 1)
        XCTAssertEqual(params?.saturation, 1)
    }

    func testNonGradingEffectReturnsNilParameters() {
        let effect = Effect.blur(radius: 10)
        XCTAssertNil(effect.colorGradingParameters)
    }

    // MARK: - Codable round-trip

    func testColorGradingParametersCodable() throws {
        let original = ColorGradingParameters.warmCinematic
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ColorGradingParameters.self, from: data)
        XCTAssertEqual(decoded, original)
    }
}
