import XCTest
@testable import MacGlintCore
final class CoreTests: XCTestCase {
    func testRatesRejectCounterResetAndSamplingGap() {
        XCTAssertEqual(MetricMath.rate(previous: 100, current: 300, elapsed: 2), 100)
        XCTAssertNil(MetricMath.rate(previous: 300, current: 100, elapsed: 2))
        XCTAssertNil(MetricMath.rate(previous: 100, current: 300, elapsed: 31))
        XCTAssertNil(MetricMath.rate(previous: 100, current: 300, elapsed: 0))
    }
    func testProcessCPUUsesWholeMachineScale() {
        XCTAssertEqual(MetricMath.cpu(deltaNanoseconds: 2_000_000_000, elapsed: 2, cores: 8), 12.5)
        XCTAssertNil(MetricMath.cpu(deltaNanoseconds: 1, elapsed: 60, cores: 8))
    }
}
