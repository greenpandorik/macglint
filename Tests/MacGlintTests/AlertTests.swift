import XCTest
@testable import MacGlintCore
final class AlertTests: XCTestCase {
    let rule = AlertRule(name: "CPU", metric: .cpu, threshold: 85, duration: 10, cooldown: 30)
    func evaluate(_ engine: AlertEngine, _ value: Double?, _ time: Double, paused: Bool = false) -> [AlertEvent] {
        engine.evaluate(snapshot: MetricSnapshot(cpu: value), processes: [], rules: [rule], paused: paused, uptime: time)
    }
    func testSustainedLoadFiresOnceAndNeedsRecovery() {
        let e = AlertEngine()
        XCTAssertTrue(evaluate(e, 90, 0).isEmpty)
        XCTAssertTrue(evaluate(e, 90, 5).isEmpty)
        XCTAssertEqual(evaluate(e, 90, 10).count, 1)
        XCTAssertTrue(evaluate(e, 90, 20).isEmpty)
        XCTAssertTrue(evaluate(e, 90, 40).isEmpty)
        XCTAssertTrue(evaluate(e, 83, 45).isEmpty) // Above hysteresis recovery level.
        XCTAssertTrue(evaluate(e, 90, 50).isEmpty)
        XCTAssertTrue(evaluate(e, 20, 55).isEmpty)
        XCTAssertTrue(evaluate(e, 90, 60).isEmpty)
        XCTAssertEqual(evaluate(e, 90, 70).count, 1)
    }
    func testMissingInputGapAndPauseResetPendingDuration() {
        for mode in 0..<3 {
            let e = AlertEngine()
            _ = evaluate(e, 90, 0)
            if mode == 0 { _ = evaluate(e, nil, 5) }
            if mode == 1 { _ = evaluate(e, 90, 5, paused: true) }
            let t: Double = mode == 2 ? 60 : 10
            XCTAssertTrue(evaluate(e, 90, t).isEmpty)
            XCTAssertEqual(evaluate(e, 90, t + 10).count, 1)
        }
    }
    func testApplicationRulesAggregateAndRespectExclusions() {
        let e = AlertEngine()
        let r = AlertRule(name: "Editor", metric: .memoryGB, appKey: "editor", threshold: 1, duration: 0)
        let p = ProcessSample(identity: .init(pid: 44, startMicroseconds: 1, uid: 501), name: "Editor", appKey: "editor", memoryBytes: 2_000_000_000)
        XCTAssertTrue(e.evaluate(snapshot: .init(), processes: [p], rules: [r], excludedApps: ["editor"], uptime: 0).isEmpty)
        let events = e.evaluate(snapshot: .init(), processes: [p], rules: [r], uptime: 5)
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.value, 2)
        XCTAssertEqual(events.first?.process?.identity, p.identity)
    }
    func testCooldownAppliesAcrossRecovery() {
        let e = AlertEngine()
        _ = evaluate(e, 90, 0); XCTAssertEqual(evaluate(e, 90, 10).count, 1)
        _ = evaluate(e, 20, 15); _ = evaluate(e, 90, 20)
        XCTAssertTrue(evaluate(e, 90, 30).isEmpty)
        XCTAssertEqual(evaluate(e, 90, 40).count, 1)
    }
    func testRuleRejectsUnsafeDurationsAndFractionalPressure() {
        XCTAssertFalse(AlertRule(name: "Huge", metric: .cpu, threshold: 80, duration: 1e30).isValid)
        XCTAssertFalse(AlertRule(name: "Pressure", metric: .pressure, threshold: 1.5).isValid)
    }
    func testWakeResetsPendingDurationEvenWhenUptimeBarelyAdvances() {
        let e = AlertEngine()
        _ = evaluate(e, 90, 0); _ = evaluate(e, 90, 9)
        e.resetPending()
        XCTAssertTrue(evaluate(e, 90, 10).isEmpty)
        XCTAssertEqual(evaluate(e, 90, 20).count, 1)
    }
    func testInvalidRuleCannotTrigger() {
        let r = AlertRule(name: "invalid", metric: .cpu, threshold: .nan, duration: -1)
        XCTAssertFalse(r.isValid)
        XCTAssertTrue(AlertEngine().evaluate(snapshot: .init(cpu: 100), processes: [], rules: [r], uptime: 0).isEmpty)
    }
}
