import Foundation

public enum MetricMath {
    public static func rate(previous: UInt64, current: UInt64, elapsed: Double) -> Double? {
        guard elapsed > 0, elapsed <= 30, current >= previous else { return nil }
        return Double(current - previous) / elapsed
    }
    public static func cpu(deltaNanoseconds: UInt64, elapsed: Double, cores: Int) -> Double? {
        guard cores > 0, let rate = rate(previous: 0, current: deltaNanoseconds, elapsed: elapsed) else { return nil }
        return min(100, max(0, rate / 1_000_000_000 / Double(cores) * 100))
    }
}

public struct ProcessIdentity: Codable, Hashable, Sendable {
    public var pid: Int32
    public var startMicroseconds: UInt64
    public var uid: UInt32
    public init(pid: Int32, startMicroseconds: UInt64, uid: UInt32) {
        self.pid = pid; self.startMicroseconds = startMicroseconds; self.uid = uid
    }
}
public struct ProcessSample: Codable, Identifiable, Sendable {
    public var identity: ProcessIdentity
    public var name: String
    public var path: String
    public var appKey: String
    public var appName: String
    public var cpu: Double?
    public var memoryBytes: UInt64?
    public var id: ProcessIdentity { identity }
    public init(identity: ProcessIdentity, name: String, path: String = "", appKey: String = "", appName: String = "", cpu: Double? = nil, memoryBytes: UInt64? = nil) {
        self.identity = identity; self.name = name; self.path = path
        self.appKey = appKey.isEmpty ? "process:\(path.isEmpty ? name : path)" : appKey
        self.appName = appName.isEmpty ? name : appName; self.cpu = cpu; self.memoryBytes = memoryBytes
    }
}
public struct MetricSnapshot: Codable, Identifiable, Sendable {
    public var date: Date
    public var cpu: Double?
    public var memoryUsed: UInt64?
    public var memoryTotal: UInt64
    public var pressure: Int?
    public var download: Double?
    public var upload: Double?
    public var battery: Double?
    public var charging: Bool
    public var diskFree: UInt64?
    public var id: Date { date }
    public init(date: Date = Date(), cpu: Double? = nil, memoryUsed: UInt64? = nil, memoryTotal: UInt64 = 0, pressure: Int? = nil, download: Double? = nil, upload: Double? = nil, battery: Double? = nil, charging: Bool = false, diskFree: UInt64? = nil) {
        self.date = date; self.cpu = cpu; self.memoryUsed = memoryUsed; self.memoryTotal = memoryTotal
        self.pressure = pressure; self.download = download; self.upload = upload
        self.battery = battery; self.charging = charging; self.diskFree = diskFree
    }
}
public enum RuleMetric: String, Codable, CaseIterable, Sendable {
    case cpu, memoryGB, pressure, diskFreeGB
    public var title: String {
        switch self { case .cpu: return "CPU, %"; case .memoryGB: return "Память, ГБ"; case .pressure: return "Давление на память"; case .diskFreeGB: return "Свободный диск, ГБ" }
    }
}
public struct AlertRule: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var metric: RuleMetric
    public var appKey: String?
    public var threshold: Double
    public var duration: Double
    public var cooldown: Double
    public var enabled: Bool
    public init(id: UUID = UUID(), name: String, metric: RuleMetric, appKey: String? = nil, threshold: Double, duration: Double = 120, cooldown: Double = 900, enabled: Bool = true) {
        self.id = id; self.name = name; self.metric = metric; self.appKey = appKey
        self.threshold = threshold; self.duration = duration; self.cooldown = cooldown; self.enabled = enabled
    }
    public var isValid: Bool {
        guard threshold.isFinite, threshold > 0, duration.isFinite, duration >= 0, duration <= 86400, cooldown.isFinite, cooldown >= 0, cooldown <= 604800 else { return false }
        if metric == .cpu && threshold > 100 { return false }
        if metric == .pressure && threshold != 1 && threshold != 2 { return false }
        if appKey != nil && (metric == .pressure || metric == .diskFreeGB) { return false }
        return !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    public static var defaults: [AlertRule] {
        [AlertRule(name: "Длительная загрузка CPU", metric: .cpu, threshold: 85),
         AlertRule(name: "Памяти не хватает", metric: .pressure, threshold: 1, duration: 60),
         AlertRule(name: "Мало места на диске", metric: .diskFreeGB, threshold: 10, duration: 30)]
    }
}
public struct AlertEvent: Codable, Identifiable, Sendable {
    public var id: UUID = UUID()
    public var ruleID: UUID
    public var date: Date
    public var title: String
    public var detail: String
    public var metric: RuleMetric
    public var value: Double
    public var appKey: String?
    public var process: ProcessSample?
    public var context: Episode? = nil
    public var ruleSnapshot: AlertRule? = nil
}

public struct NetworkCounter: Sendable {
    public var received: UInt64
    public var sent: UInt64
    public init(received: UInt64, sent: UInt64) { self.received = received; self.sent = sent }
}
public enum NetworkRates {
    public static func measure(previous: [String: NetworkCounter], current: [String: NetworkCounter], elapsed: Double) -> (download: Double?, upload: Double?) {
        var downloads: [Double] = [], uploads: [Double] = []
        for (key, now) in current {
            guard let old = previous[key] else { continue }
            if let value = MetricMath.rate(previous: old.received, current: now.received, elapsed: elapsed) { downloads.append(value) }
            if let value = MetricMath.rate(previous: old.sent, current: now.sent, elapsed: elapsed) { uploads.append(value) }
        }
        return (downloads.isEmpty ? nil : downloads.reduce(0, +), uploads.isEmpty ? nil : uploads.reduce(0, +))
    }
}
