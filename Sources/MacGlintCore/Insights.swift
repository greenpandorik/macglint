import Foundation

/// A bounded historical summary. It records observations, not an attribution of a slowdown.
public struct AppObservation: Codable, Identifiable, Sendable {
    public var id: String
    public var name: String
    public var cpu: Double?
    public var memoryBytes: UInt64?
    public var processCount: Int
    public var representative: ProcessIdentity?
}
public struct Episode: Codable, Identifiable, Sendable {
    public var snapshot: MetricSnapshot
    public var apps: [AppObservation]
    public var id: Date { snapshot.date }
    public static func capture(snapshot: MetricSnapshot, processes: [ProcessSample], uid: UInt32) -> Episode {
        let groups = ProcessGrouping.groups(processes.filter { $0.identity.uid == uid })
        let cpu = groups.filter { $0.cpu != nil }.sorted { a, b in a.cpu == b.cpu ? a.id < b.id : (a.cpu ?? 0) > (b.cpu ?? 0) }.prefix(3)
        let memory = groups.filter { $0.memoryBytes != nil }.sorted { a, b in a.memoryBytes == b.memoryBytes ? a.id < b.id : (a.memoryBytes ?? 0) > (b.memoryBytes ?? 0) }.prefix(3)
        var seen = Set<String>()
        let apps = (Array(cpu) + Array(memory)).filter { seen.insert($0.id).inserted }.map { group in
            AppObservation(id: group.id, name: group.name, cpu: group.cpu, memoryBytes: group.memoryBytes,
                           processCount: group.processes.count, representative: group.processes.first?.identity)
        }
        return Episode(snapshot: snapshot, apps: apps)
    }
    public static func nearest(to date: Date, in episodes: [Episode], tolerance: TimeInterval = 18) -> Episode? {
        guard let closest = episodes.min(by: { abs($0.id.timeIntervalSince(date)) < abs($1.id.timeIntervalSince(date)) }),
              abs(closest.id.timeIntervalSince(date)) <= tolerance else { return nil }
        return closest
    }
}
public struct MemoryGrowth: Identifiable, Sendable {
    public var id: String
    public var name: String
    public var before: UInt64
    public var after: UInt64
    public var since: Date
    public var until: Date
    public var compositionChanged: Bool
    public var process: ProcessIdentity?
    public var increase: UInt64 { after - before }
    public var elapsed: TimeInterval { until.timeIntervalSince(since) }
}
public final class MemoryGrowthTracker {
    private struct Point {
        let date: Date
        let bytes: UInt64
        let identities: Set<ProcessIdentity>
    }
    private var points: [String: [Point]] = [:]
    public private(set) var growth: [MemoryGrowth] = []
    public private(set) var hasComparison = false
    public init() {}
    public func reset() { points = [:]; growth = []; hasComparison = false }
    public func record(processes: [ProcessSample], at date: Date, uid: UInt32) {
        let groups = ProcessGrouping.groups(processes.filter { $0.identity.uid == uid }, sortByMemory: true)
        let alive = Set(groups.map(\.id))
        points = points.filter { alive.contains($0.key) }
        var result: [MemoryGrowth] = []
        hasComparison = false
        for group in groups {
            guard let memory = group.memoryBytes else { points[group.id] = nil; continue }
            let identities = Set(group.processes.map(\.identity))
            var trace = points[group.id] ?? []
            if let last = trace.last,
               date.timeIntervalSince(last.date) > 30 || date <= last.date || last.identities.isDisjoint(with: identities) {
                trace = []
            }
            trace.removeAll { date.timeIntervalSince($0.date) > 600 }
            trace.append(Point(date: date, bytes: memory, identities: identities))
            // Sampling is normally every 2–6 seconds; keep a hard bound as well.
            if trace.count > 301 { trace.removeFirst(trace.count - 301) }
            points[group.id] = trace
            guard let first = trace.first, date.timeIntervalSince(first.date) >= 60 else { continue }
            hasComparison = true
            guard memory > first.bytes else { continue }
            result.append(MemoryGrowth(id: group.id, name: group.name, before: first.bytes, after: memory,
                since: first.date, until: date, compositionChanged: trace.contains { $0.identities != first.identities },
                process: group.processes.first?.identity))
        }
        growth = result.sorted { $0.increase == $1.increase ? $0.id < $1.id : $0.increase > $1.increase }
    }
}

/// Event focus and point selection share a time window until the user explicitly returns live.
public struct HistoryNavigation {
    public var selectedDate: Date?
    private var center: Date?
    public init() {}
    public mutating func focusEvent(at date: Date) { center = date; selectedDate = nil }
    public mutating func selectMoment(_ date: Date) { selectedDate = date }
    public mutating func goLive() { center = nil; selectedDate = nil }
    public func range(now: Date, duration: TimeInterval) -> ClosedRange<Date> {
        let end = center?.addingTimeInterval(duration / 2) ?? now
        return end.addingTimeInterval(-duration)...end
    }
}
