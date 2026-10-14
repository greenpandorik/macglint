import Foundation

public final class HistoryStore {
    private struct Archive: Codable {
        var snapshots: [MetricSnapshot]
        var events: [AlertEvent]
        var episodes: [Episode]?
    }
    public private(set) var snapshots: [MetricSnapshot] = []
    public private(set) var episodes: [Episode] = []
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
            episodes = (a.episodes ?? []).sorted { $0.id < $1.id }
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
    public func appendEpisode(_ episode: Episode) {
        episodes.append(episode); prune(now: episode.id)
    }
    private func prune(now: Date) {
        let cutoff = now.addingTimeInterval(-86400)
        snapshots.removeAll { $0.date < cutoff || $0.date > now.addingTimeInterval(60) }
        episodes.removeAll { $0.id < cutoff || $0.id > now.addingTimeInterval(60) }
        if episodes.count > 2880 { episodes.removeFirst(episodes.count - 2880) }
        events.removeAll { $0.date < cutoff || $0.date > now.addingTimeInterval(60) }
        if snapshots.count > 8640 { snapshots.removeFirst(snapshots.count - 8640) }
        if events.count > 500 { events.removeFirst(events.count - 500) }
    }
    public func save() throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(Archive(snapshots: snapshots, events: events, episodes: episodes))
        try data.write(to: url, options: .atomic)
    }
    public func clear() throws { snapshots = []; events = []; episodes = []; try save() }
}
