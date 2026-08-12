import XCTest
import Foundation
@testable import SplitForgeCore

final class SettingsTests: XCTestCase {
    func testDefaults() {
        let d = Settings.defaultSettings
        XCTAssertNil(d.overlayOriginX)
        XCTAssertNil(d.overlayOriginY)
        XCTAssertEqual(d.overlayOpacity, 1.0)
        XCTAssertFalse(d.hasOrigin)
    }

    func testNormalizedClampsOpacity() {
        XCTAssertEqual(Settings(overlayOpacity: 0.05).normalized().overlayOpacity, 0.3)  // floor
        XCTAssertEqual(Settings(overlayOpacity: 1.5).normalized().overlayOpacity, 1.0)   // ceiling
        XCTAssertEqual(Settings(overlayOpacity: 0.6).normalized().overlayOpacity, 0.6)   // in range
    }

    func testHasOriginRequiresBothComponents() {
        XCTAssertTrue(Settings(overlayOriginX: 10, overlayOriginY: 20).hasOrigin)
        XCTAssertFalse(Settings(overlayOriginX: 10, overlayOriginY: nil).hasOrigin)
    }

    func testCodableRoundTrip() throws {
        let s = Settings(overlayOriginX: 12.5, overlayOriginY: -3, overlayOpacity: 0.6)
        let data = try JSONEncoder().encode(s)
        let back = try JSONDecoder().decode(Settings.self, from: data)
        XCTAssertEqual(back, s)
    }

    func testNormalizedDropsBlankLayerNames() {
        let s = Settings(layerNames: ["0": "Base", "1": "  ", "2": "", "3": "Nav"])
        XCTAssertEqual(s.normalized().layerNames, ["0": "Base", "3": "Nav"])
    }

    func testLayerNamesCodableRoundTrip() throws {
        let s = Settings(overlayOpacity: 0.6, layerNames: ["2": "Sym"])
        let data = try JSONEncoder().encode(s)
        XCTAssertEqual(try JSONDecoder().decode(Settings.self, from: data), s)
    }
}

final class SettingsStoreTests: XCTestCase {
    private func isolatedDefaults() -> UserDefaults {
        let suite = "splitforge.tests.\(UInt64.random(in: 0..<UInt64.max))"
        let d = UserDefaults(suiteName: suite)!
        d.removePersistentDomain(forName: suite)
        return d
    }

    func testEmptyStoreReturnsDefaults() {
        let store = SettingsStore(defaults: isolatedDefaults())
        XCTAssertEqual(store.load(), .defaultSettings)
    }

    func testSaveThenLoadRoundTrips() {
        let defaults = isolatedDefaults()
        let store = SettingsStore(defaults: defaults)
        let settings = Settings(overlayOriginX: 100, overlayOriginY: 200, overlayOpacity: 0.6)
        store.save(settings)
        XCTAssertEqual(SettingsStore(defaults: defaults).load(), settings)
    }

    func testSaveNormalizesOpacity() {
        let defaults = isolatedDefaults()
        SettingsStore(defaults: defaults).save(Settings(overlayOpacity: 0.01))
        XCTAssertEqual(SettingsStore(defaults: defaults).load().overlayOpacity, 0.3)
    }

    func testCorruptBlobReturnsDefaults() {
        let defaults = isolatedDefaults()
        let key = "settings.corrupt-test"
        defaults.set(Data([0x00, 0x01, 0x02]), forKey: key)
        XCTAssertEqual(SettingsStore(defaults: defaults, key: key).load(), .defaultSettings)
    }
}
