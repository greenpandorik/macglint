import Foundation

public final class HistoryStore {
    private struct Archive: Codable {
        var snapshots: [MetricSnapshot]
        var events: [AlertEvent]
    }
    public private(set) var snapshots: [MetricSnapshot] = []
    public private(set) var events: [AlertEvent] = []
    public private(set) var loadWarning: String?
    private let url: URL
    public init(url: URL) {
        self.url = url
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            guard size < 25_000_000 else { throw CocoaError(.fileReadTooLarge) }
            let a = try JSONDecoder().decode(Archive.self, from: Data(contentsOf: url))
            snapshots = a.snapshots.sorted { $0.date < $1.date }
            events = a.events.sorted { $0.date < $1.date }
            prune(now: Date())
        } catch {
            loadWarning = "История не прочитана. Начат новый журнал."
            let backup = url.deletingPathExtension().appendingPathExtension("corrupt.json")
            if !FileManager.default.fileExists(atPath: backup.path) { try? FileManager.default.copyItem(at: url, to: backup) }
        }
    }
    public func append(_ sample: MetricSnapshot, events newEvents: [AlertEvent] = []) {
        snapshots.append(sample); events.append(contentsOf: newEvents); prune(now: sample.date)
    }
    public func addEvents(_ newEvents: [AlertEvent]) {
        events.append(contentsOf: newEvents); prune(now: Date())
    }
    private func prune(now: Date) {
        let cutoff = now.addingTimeInterval(-86400)
        snapshots.removeAll { $0.date < cutoff || $0.date > now.addingTimeInterval(60) }
        events.removeAll { $0.date < cutoff || $0.date > now.addingTimeInterval(60) }
        if snapshots.count > 8640 { snapshots.removeFirst(snapshots.count - 8640) }
        if events.count > 500 { events.removeFirst(events.count - 500) }
    }
    public func save() throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(Archive(snapshots: snapshots, events: events))
        try data.write(to: url, options: .atomic)
    }
    public func clear() throws { snapshots = []; events = []; try save() }
}
