import XCTest
import Darwin
import MacGlintCore
@testable import MacGlintSystem
final class SystemTests: XCTestCase {
    func testLiveSampleHasMemoryAndSelfProcess() {
        let sampler = SystemSampler()
        let first = sampler.sample()
        XCTAssertGreaterThan(first.snapshot.memoryTotal, 0)
        XCTAssertNotNil(first.snapshot.memoryUsed)
        XCTAssertNotNil(first.processes.first { $0.identity.pid == getpid() })
        var next = first
        for _ in 0..<10 {
            Thread.sleep(forTimeInterval: 0.1)
            next = sampler.sample()
            if next.snapshot.cpu != nil { break }
        }
        var interfaces: UnsafeMutablePointer<ifaddrs>?
        if getifaddrs(&interfaces) == 0 {
            var item = interfaces; var hasPhysicalInterface = false
            while let current = item {
                if String(cString: current.pointee.ifa_name).hasPrefix("en") { hasPhysicalInterface = true }
                item = current.pointee.ifa_next
            }
            freeifaddrs(interfaces)
            if hasPhysicalInterface { XCTAssertNotNil(next.snapshot.download, "Counter traversal must reach en interfaces") }
        }
        XCTAssertNotNil(next.snapshot.cpu)
        XCTAssertTrue((0...100).contains(next.snapshot.cpu ?? -1))
    }
    func testProcessCPUAgreesWithIndependentPOSIXClock() throws {
        func cpuSeconds() -> Double {
            var usage = rusage(); getrusage(RUSAGE_SELF, &usage)
            return Double(usage.ru_utime.tv_sec + usage.ru_stime.tv_sec) + Double(usage.ru_utime.tv_usec + usage.ru_stime.tv_usec) / 1e6
        }
        let sampler = SystemSampler()
        let beforeTime = ProcessInfo.processInfo.systemUptime
        let beforeCPU = cpuSeconds()
        _ = sampler.sample()
        while ProcessInfo.processInfo.systemUptime - beforeTime < 0.3 { _ = getpid() }
        let sample = sampler.sample()
        let elapsed = ProcessInfo.processInfo.systemUptime - beforeTime
        let expected = (cpuSeconds() - beforeCPU) / elapsed / Double(ProcessInfo.processInfo.activeProcessorCount) * 100
        let actual = try XCTUnwrap(sample.processes.first { $0.identity.pid == getpid() }?.cpu)
        XCTAssertGreaterThan(expected, 0.05)
        XCTAssertEqual(actual, expected, accuracy: expected * 0.3)
    }
    func testTerminationRejectsStaleIdentityAndSignalsOnlyOwnedChild() throws {
        let child = Process(); child.executableURL = URL(fileURLWithPath: "/bin/sleep"); child.arguments = ["30"]
        try child.run()
        defer { if child.isRunning { child.terminate() }; child.waitUntilExit() }
        guard let identity = ProcessController.identity(for: child.processIdentifier) else { return XCTFail("Missing child identity") }
        var stale = identity; stale.startMicroseconds += 1
        XCTAssertThrowsError(try ProcessController.terminate(identity: stale, force: false))
        XCTAssertTrue(child.isRunning)
        var otherUser = identity; otherUser.uid += 1
        XCTAssertThrowsError(try ProcessController.terminate(identity: otherUser, force: true))
        XCTAssertTrue(child.isRunning)
        try ProcessController.terminate(identity: identity, force: false)
        child.waitUntilExit()
        XCTAssertFalse(child.isRunning)
    }
    func testProtectedPIDsAreRejected() throws {
        XCTAssertThrowsError(try ProcessController.terminate(identity: .init(pid: 1, startMicroseconds: 0, uid: 0), force: true))
        let selfID = try XCTUnwrap(ProcessController.identity(for: getpid()))
        XCTAssertThrowsError(try ProcessController.terminate(identity: selfID, force: false))
    }
}
