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
        Thread.sleep(forTimeInterval: 0.1)
        let next = sampler.sample()
        XCTAssertNotNil(next.snapshot.cpu)
        XCTAssertTrue((0...100).contains(next.snapshot.cpu ?? -1))
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
