import Foundation
public enum Appearance: String, Codable, CaseIterable { case system, light, dark }
public struct Preferences: Codable {
    public var appearance: Appearance = .system
    public var menuCPU = true
    public var menuMemory = false
    public var menuNetwork = false
    public var notifications = false
    public var rules = AlertRule.defaults
    public var excludedApps: Set<String> = []
    public var pauseUntil: Date?
    public init() {}
    public static func load(from defaults: UserDefaults) -> Preferences {
        guard let data = defaults.data(forKey: "preferences"), var value = try? JSONDecoder().decode(Self.self, from: data) else { return .init() }
        value.rules = value.rules.filter(\.isValid)
        return value
    }
    public func save(to defaults: UserDefaults) {
        var clean = self; clean.rules = clean.rules.filter(\.isValid)
        if let data = try? JSONEncoder().encode(clean) { defaults.set(data, forKey: "preferences") }
    }
}
public struct ProcessGroup: Identifiable {
    public var id: String
    public var name: String
    public var processes: [ProcessSample]
    public var cpu: Double?
    public var memoryBytes: UInt64?
}
public enum ProcessGrouping {
    public static func groups(_ samples: [ProcessSample]) -> [ProcessGroup] {
        Dictionary(grouping: samples, by: \.appKey).map { key, items in
            let sorted = items.sorted { ($0.cpu ?? -1) > ($1.cpu ?? -1) }
            let cpu = items.allSatisfy { $0.cpu != nil } ? items.reduce(0.0) { $0 + ($1.cpu ?? 0) } : nil
            let memory: UInt64? = items.allSatisfy { $0.memoryBytes != nil } ? items.reduce(UInt64(0)) { $0 + ($1.memoryBytes ?? 0) } : nil
            return ProcessGroup(id: key, name: items.first?.appName ?? key, processes: sorted, cpu: cpu, memoryBytes: memory)
        }
    }
}
