import XCTest
@testable import MacGlintCore

final class InsightsTests: XCTestCase {
    private func p(_ pid: Int32 = 10, key: String = "Editor.app", memory: UInt64? = 100, cpu: Double? = 1, start: UInt64 = 1, uid: UInt32 = 501) -> ProcessSample {
        .init(identity: .init(pid: pid, startMicroseconds: start, uid: uid), name: "Editor", appKey: key, appName: key, cpu: cpu, memoryBytes: memory)
    }
    func testEpisodeRanksAggregateGroupsAndExcludesOtherUsers() {
        let samples = [p(memory: 100, cpu: 20), p(11, memory: 200, cpu: 30), p(12, key: "Other.app", memory: 900, cpu: 2), p(13, key: "Foreign.app", memory: 9999, cpu: 90, uid: 502)]
        let e = Episode.capture(snapshot: .init(cpu: 60), processes: samples, uid: 501)
        XCTAssertEqual(e.apps.count, 2)
        let editor = e.apps.first { $0.id == "Editor.app" }
        XCTAssertEqual(editor?.cpu, 50)
        XCTAssertEqual(editor?.memoryBytes, 300)
        XCTAssertEqual(editor?.processCount, 2)
        XCTAssertEqual(editor?.representative, samples[1].identity)
        let many = (1...20).map { p(Int32($0), key: "App\($0).app", memory: UInt64(30 - $0), cpu: Double($0)) }
        XCTAssertEqual(Episode.capture(snapshot: .init(), processes: many, uid: 501).apps.count, 6)
    }
    func testNearestEpisodeDoesNotInventContextAcrossGap() {
        let date = Date()
        let e = Episode.capture(snapshot: .init(date: date), processes: [], uid: 501)
        XCTAssertNotNil(Episode.nearest(to: date.addingTimeInterval(14), in: [e]))
        XCTAssertNil(Episode.nearest(to: date.addingTimeInterval(60), in: [e]))
    }
    func testGrowthUsesTenMinuteBaselineAndDoesNotCallNewAppsGrowth() {
        let t = MemoryGrowthTracker()
        let date = Date()
        for second in stride(from: 0, through: 720, by: 10) {
            t.record(processes: [p(memory: UInt64(100 + second))], at: date.addingTimeInterval(Double(second)), uid: 501)
        }
        XCTAssertEqual(t.growth.first?.before, 220)
        XCTAssertEqual(t.growth.first?.after, 820)
        XCTAssertEqual(t.growth.first?.increase, 600)
        XCTAssertEqual(t.growth.first?.elapsed, 600)
        t.record(processes: [p(memory: 820), p(20, key: "New.app", memory: 9999)], at: date.addingTimeInterval(730), uid: 501)
        XCTAssertEqual(t.growth.count, 1)
    }
    func testGrowthResetsOnMissingValueRestartGapAndAbsence() {
        for mode in 0..<4 {
            let t = MemoryGrowthTracker(); let date = Date()
            for second in stride(from: 0, through: 60, by: 10) {
                t.record(processes: [p(memory: UInt64(100 + second))], at: date.addingTimeInterval(Double(second)), uid: 501)
            }
            XCTAssertEqual(t.growth.count, 1)
            switch mode {
            case 0: t.record(processes: [p(memory: nil)], at: date.addingTimeInterval(70), uid: 501)
            case 1: t.record(processes: [p(memory: 999, start: 2)], at: date.addingTimeInterval(70), uid: 501)
            case 2: t.record(processes: [p(memory: 999)], at: date.addingTimeInterval(120), uid: 501)
            default: t.record(processes: [], at: date.addingTimeInterval(70), uid: 501)
            }
            XCTAssertTrue(t.growth.isEmpty)
        }
    }
    func testGrowthLabelsCompositionChangesAndIgnoresDeclines() {
        let t = MemoryGrowthTracker(); let date = Date()
        for second in stride(from: 0, through: 60, by: 10) {
            let extra = second > 0 ? [p(11, memory: 200)] : []
            t.record(processes: [p(memory: 100)] + extra, at: date.addingTimeInterval(Double(second)), uid: 501)
        }
        XCTAssertEqual(t.growth.first?.increase, 200)
        XCTAssertEqual(t.growth.first?.compositionChanged, true)
        t.reset()
        for second in stride(from: 0, through: 60, by: 10) {
            t.record(processes: [p(memory: UInt64(200 - second))], at: date.addingTimeInterval(Double(second)), uid: 501)
        }
        XCTAssertTrue(t.growth.isEmpty)
    }
    func testLegacyArchiveAndNewContextRoundTripAndClear() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("history.json"); let now = Date()
        let metric = MetricSnapshot(date: now, cpu: 42)
        let encoded = try JSONEncoder().encode([metric])
        let old = "{\"snapshots\":\(String(decoding: encoded, as: UTF8.self)),\"events\":[]}"
        try Data(old.utf8).write(to: url)
        let h = HistoryStore(url: url)
        XCTAssertEqual(h.snapshots.count, 1); XCTAssertTrue(h.episodes.isEmpty)
        let context = Episode.capture(snapshot: metric, processes: [p()], uid: 501)
        h.appendEpisode(context)
        var event = AlertEvent(ruleID: UUID(), date: now, title: "CPU", detail: "High", metric: .cpu, value: 42)
        event.context = context
        h.addEvents([event]); try h.save()
        let loaded = HistoryStore(url: url)
        XCTAssertEqual(loaded.episodes.first?.apps.first?.memoryBytes, 100)
        XCTAssertEqual(loaded.events.first?.context?.snapshot.cpu, 42)
        loaded.appendEpisode(Episode.capture(snapshot: .init(date: now.addingTimeInterval(86401)), processes: [], uid: 501))
        XCTAssertEqual(loaded.episodes.count, 1)
        try loaded.clear()
        XCTAssertTrue(HistoryStore(url: url).episodes.isEmpty)
    }
    func testPerRuleMuteDoesNotSuppressOtherRulesAndResetsPending() {
        let e = AlertEngine()
        let a = AlertRule(name: "A", metric: .cpu, threshold: 50, duration: 10)
        let b = AlertRule(name: "B", metric: .cpu, threshold: 50, duration: 0)
        _ = e.evaluate(snapshot: .init(cpu: 90), processes: [], rules: [a], uptime: 0)
        let muted = e.evaluate(snapshot: .init(cpu: 90), processes: [], rules: [a,b], mutedRuleIDs: [a.id], uptime: 10)
        XCTAssertEqual(muted.map(\.ruleID), [b.id])
        XCTAssertTrue(e.evaluate(snapshot: .init(cpu: 90), processes: [], rules: [a], uptime: 20).isEmpty)
        XCTAssertEqual(e.evaluate(snapshot: .init(cpu: 90), processes: [], rules: [a], uptime: 30).count, 1)
    }
    func testEventKeepsOriginalRuleAfterEditingAndLegacyDecode() throws {
        var rule = AlertRule(name: "Original", metric: .cpu, threshold: 80, duration: 0)
        let event = try XCTUnwrap(AlertEngine().evaluate(snapshot: .init(cpu: 90), processes: [], rules: [rule], uptime: 0).first)
        rule.threshold = 95
        XCTAssertEqual(event.ruleSnapshot?.threshold, 80)
        let encoded = try JSONEncoder().encode(event)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        json.removeValue(forKey: "context"); json.removeValue(forKey: "ruleSnapshot")
        let legacy = try JSONDecoder().decode(AlertEvent.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(legacy.value, 90); XCTAssertNil(legacy.context); XCTAssertNil(legacy.ruleSnapshot)
    }
    func testHistoricalWindowStaysAnchoredWhileSelectingAdjacentMoment() {
        let now = Date(); let eventDate = now.addingTimeInterval(-10800)
        var navigation = HistoryNavigation()
        navigation.focusEvent(at: eventDate)
        navigation.selectMoment(eventDate.addingTimeInterval(10))
        XCTAssertTrue(navigation.range(now: now, duration: 3600).contains(eventDate))
        XCTAssertEqual(navigation.selectedDate, eventDate.addingTimeInterval(10))
        XCTAssertFalse(navigation.range(now: now, duration: 3600).contains(now))
        navigation.goLive()
        XCTAssertNil(navigation.selectedDate)
        XCTAssertEqual(navigation.range(now: now, duration: 3600).upperBound, now)
    }
    func testContinuousGrowthSeesBriefMissingReadingAndReportsReadiness() {
        let tracker = MemoryGrowthTracker(); let date = Date()
        for second in stride(from: 0, through: 60, by: 2) {
            tracker.record(processes: [p(memory: UInt64(100 + second))], at: date.addingTimeInterval(Double(second)), uid: 501)
        }
        XCTAssertTrue(tracker.hasComparison)
        tracker.record(processes: [p(memory: nil)], at: date.addingTimeInterval(62), uid: 501)
        tracker.record(processes: [p(memory: 300)], at: date.addingTimeInterval(64), uid: 501)
        XCTAssertFalse(tracker.hasComparison); XCTAssertTrue(tracker.growth.isEmpty)
        for second in stride(from: 66, through: 124, by: 2) {
            tracker.record(processes: [p(memory: 300)], at: date.addingTimeInterval(Double(second)), uid: 501)
        }
        XCTAssertTrue(tracker.hasComparison); XCTAssertTrue(tracker.growth.isEmpty)
    }
    func testMutePreferencesLoadWithoutNewKeyAndRoundTrip() throws {
        var p = Preferences(); p.menuCPU = false
        let data = try JSONEncoder().encode(p)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any]); json.removeValue(forKey: "mutedRules")
        let suite = "MacGlintTests.\(UUID())"; let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(try JSONSerialization.data(withJSONObject: json), forKey: "preferences")
        var loaded = Preferences.load(from: defaults)
        XCTAssertFalse(loaded.menuCPU)
        let id = UUID(); loaded.mutedRules = [id.uuidString: Date().addingTimeInterval(3600)]
        loaded.save(to: defaults)
        XCTAssertNotNil(Preferences.load(from: defaults).mutedRules?[id.uuidString])
    }
}
