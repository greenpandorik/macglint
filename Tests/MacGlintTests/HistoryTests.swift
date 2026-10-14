import XCTest
@testable import MacGlintCore
final class HistoryTests: XCTestCase {
    func testRetentionPersistenceAndClear() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("history.json")
        let h = HistoryStore(url: url)
        let now = Date()
        h.append(.init(date: now.addingTimeInterval(-90000), cpu: 10))
        h.append(.init(date: now, cpu: 40))
        try h.save()
        let loaded = HistoryStore(url: url)
        XCTAssertEqual(loaded.snapshots.count, 1)
        XCTAssertEqual(loaded.snapshots.first?.cpu, 40)
        try loaded.clear()
        XCTAssertTrue(HistoryStore(url: url).snapshots.isEmpty)
    }
    func testCorruptFileDoesNotCrashAndCanBeReplaced() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("history.json")
        try Data("broken".utf8).write(to: url)
        let h = HistoryStore(url: url)
        h.append(.init(cpu: 30)); try h.save()
        XCTAssertEqual(HistoryStore(url: url).snapshots.first?.cpu, 30)
    }
}
