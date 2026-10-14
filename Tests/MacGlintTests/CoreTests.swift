import XCTest
@testable import MacGlintCore
final class CoreTests: XCTestCase {
    func testRatesRejectCounterResetAndSamplingGap() {
        XCTAssertEqual(MetricMath.rate(previous: 100, current: 300, elapsed: 2), 100)
        XCTAssertNil(MetricMath.rate(previous: 300, current: 100, elapsed: 2))
        XCTAssertNil(MetricMath.rate(previous: 100, current: 300, elapsed: 31))
        XCTAssertNil(MetricMath.rate(previous: 100, current: 300, elapsed: 0))
    }
    func testNetworkRatesUse64BitPerInterfaceBaselines() {
        let previous = ["en0": NetworkCounter(received: 4_000_000_000, sent: 100)]
        let current = ["en0": NetworkCounter(received: 9_000_000_000, sent: 300), "en1": NetworkCounter(received: 900_000, sent: 900_000)]
        let rate = NetworkRates.measure(previous: previous, current: current, elapsed: 5)
        XCTAssertEqual(rate.download, 1_000_000_000)
        XCTAssertEqual(rate.upload, 40)
        XCTAssertNil(NetworkRates.measure(previous: previous, current: ["en0": .init(received: 1, sent: 1)], elapsed: 5).download)
    }
    func testProcessCPUUsesWholeMachineScale() {
        XCTAssertEqual(MetricMath.cpu(deltaNanoseconds: 2_000_000_000, elapsed: 2, cores: 8), 12.5)
        XCTAssertNil(MetricMath.cpu(deltaNanoseconds: 1, elapsed: 60, cores: 8))
    }
}
