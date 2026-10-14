import XCTest
@testable import MacGlintCore
final class PreferencesTests: XCTestCase {
    func testPreferencesRoundTripAndFilterInvalidRules() throws {
        let suite = "MacGlint.tests.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        var prefs = Preferences(); prefs.appearance = .dark; prefs.menuCPU = false; prefs.menuNetwork = true
        prefs.excludedApps = ["editor"]
        prefs.rules.append(.init(name: "invalid", metric: .cpu, threshold: 500))
        prefs.save(to: defaults)
        let loaded = Preferences.load(from: defaults)
        XCTAssertEqual(loaded.appearance, .dark); XCTAssertFalse(loaded.menuCPU); XCTAssertTrue(loaded.menuNetwork)
        XCTAssertEqual(loaded.excludedApps, ["editor"])
        XCTAssertTrue(loaded.rules.allSatisfy(\.isValid))
    }
    func testCorruptPreferencesFallback() throws {
        let suite = "MacGlint.tests.\(UUID())"; let d = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { d.removePersistentDomain(forName: suite) }
        d.set(Data("oops".utf8), forKey: "preferences")
        XCTAssertEqual(Preferences.load(from: d).appearance, .system)
    }
    func testGroupingDoesNotInventSafariTabOrDoubleCount() {
        let a = ProcessSample(identity: .init(pid: 1, startMicroseconds: 1, uid: 501), name: "Editor", appKey: "editor", cpu: 3, memoryBytes: 100)
        let b = ProcessSample(identity: .init(pid: 2, startMicroseconds: 1, uid: 501), name: "Renderer", appKey: "editor", cpu: 7, memoryBytes: 200)
        let c = ProcessSample(identity: .init(pid: 3, startMicroseconds: 1, uid: 501), name: "com.apple.WebKit.WebContent", appKey: "webkit", cpu: nil, memoryBytes: nil)
        let groups = ProcessGrouping.groups([a,b,c])
        XCTAssertEqual(groups.count, 2)
        XCTAssertEqual(groups.first { $0.id == "editor" }?.cpu, 10)
        XCTAssertEqual(groups.first { $0.id == "editor" }?.memoryBytes, 300)
        XCTAssertNil(groups.first { $0.id == "webkit" }?.memoryBytes)
        XCTAssertEqual(groups.first { $0.id == "webkit" }?.name, "com.apple.WebKit.WebContent")
    }
}
