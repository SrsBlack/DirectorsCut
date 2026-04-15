import XCTest
@testable import Editor

final class EffectTests: XCTestCase {
    // MARK: - Factory methods

    func testColorCorrectionFactory() {
        let effect = Effect.colorCorrection()
        XCTAssertEqual(effect.type, .colorCorrection)
        XCTAssertTrue(effect.isEnabled)

        // Defaults: brightness 0, contrast 1, saturation 1, temperature 6500
        XCTAssertEqual(effect.parameters["brightness"]?.floatValue, 0)
        XCTAssertEqual(effect.parameters["contrast"]?.floatValue, 1)
        XCTAssertEqual(effect.parameters["saturation"]?.floatValue, 1)
        XCTAssertEqual(effect.parameters["temperature"]?.floatValue, 6500)
    }

    func testBlurFactory() {
        let effect = Effect.blur(radius: 25)
        XCTAssertEqual(effect.type, .gaussianBlur)
        XCTAssertEqual(effect.parameters["radius"]?.floatValue, 25)
    }

    func testChromaKeyFactory() {
        let effect = Effect.chromaKey()
        XCTAssertEqual(effect.type, .chromaKey)
        XCTAssertEqual(effect.parameters["threshold"]?.floatValue, 0.4)
        XCTAssertEqual(effect.parameters["smoothing"]?.floatValue, 0.1)
    }

    func testVignetteFactory() {
        let effect = Effect.vignette(intensity: 0.7)
        XCTAssertEqual(effect.type, .vignette)
        XCTAssertEqual(effect.parameters["intensity"]?.floatValue, 0.7)
    }

    // MARK: - EffectParameter

    func testEffectParameterFloatValue() {
        let p = EffectParameter.float(3.14)
        XCTAssertEqual(p.floatValue, 3.14)
        XCTAssertNil(p.intValue)
        XCTAssertNil(p.boolValue)
    }

    func testEffectParameterIntValue() {
        let p = EffectParameter.int(42)
        XCTAssertEqual(p.intValue, 42)
        XCTAssertNil(p.floatValue)
    }

    func testEffectParameterBoolValue() {
        let p = EffectParameter.bool(true)
        XCTAssertEqual(p.boolValue, true)
        XCTAssertNil(p.floatValue)
    }

    // MARK: - Codable round-trip

    func testEffectCodableRoundTrip() throws {
        let original = Effect.colorCorrection()
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Effect.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testEffectWithDisabledFlag() throws {
        var effect = Effect.blur(radius: 10)
        effect.isEnabled = false
        let data = try JSONEncoder().encode(effect)
        let decoded = try JSONDecoder().decode(Effect.self, from: data)
        XCTAssertFalse(decoded.isEnabled)
    }
}
