import XCTest
import CoreGraphics
@testable import MacGlintCore

final class InterfaceLogicTests: XCTestCase {
    func testInvalidTypedNumberCannotSavePreviousValidValue() {
        let rule = AlertRule(name: "CPU", metric: .cpu, threshold: 80)
        var draft = RuleDraft(rule: rule)
        draft.threshold = "oops"
        XCTAssertNil(draft.build())
        XCTAssertNotNil(draft.validationMessage)
        draft.threshold = "85,5"
        XCTAssertEqual(draft.build()?.threshold, 85.5)
        draft.duration = "90000"
        XCTAssertNil(draft.build())
    }
    func testScopeChangeOnlyOffersSupportedMetrics() {
        var draft = RuleDraft(rule: AlertRule(name: "Pressure", metric: .pressure, threshold: 1))
        draft.setAppKey("/Applications/Editor.app")
        XCTAssertEqual(draft.rule.metric, .cpu)
        XCTAssertEqual(draft.availableMetrics, [.cpu, .memoryGB])
        XCTAssertNotNil(draft.build())
    }
    func testMemorySortingAppliesToChildrenWithUnknownValuesLast() {
        let samples = [
            ProcessSample(identity: .init(pid: 1, startMicroseconds: 1, uid: 1), name: "CPU", appKey: "app", cpu: 50, memoryBytes: 100),
            ProcessSample(identity: .init(pid: 2, startMicroseconds: 1, uid: 1), name: "Memory", appKey: "app", cpu: 1, memoryBytes: 1000),
            ProcessSample(identity: .init(pid: 3, startMicroseconds: 1, uid: 1), name: "Unknown", appKey: "app", cpu: 99)
        ]
        XCTAssertEqual(ProcessGrouping.groups(samples, sortByMemory: true).first?.processes.map(\.identity.pid), [2, 1, 3])
    }
    func testMiniPanelStaysInsideSmallAndOffsetDisplays() {
        let screen = CGRect(x: -1200, y: 50, width: 1200, height: 650)
        let frame = PanelPlacement.frame(visibleScreen: screen, anchorX: -1190)
        XCTAssertTrue(screen.contains(frame))
        XCTAssertLessThanOrEqual(frame.size.height, screen.size.height - 16)
        XCTAssertEqual(frame.size.width, 380)
    }
}
