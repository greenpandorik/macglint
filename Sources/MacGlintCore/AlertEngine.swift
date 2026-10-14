import Foundation

public final class AlertEngine {
    private struct State {
        var rule: AlertRule
        var since: Double?
        var lastFire: Double?
        var active = false
    }
    private var states: [UUID: State] = [:]
    private var lastTime: Double?
    public init() {}
    public func resetPending() {
        for id in states.keys { states[id]?.since = nil; states[id]?.active = false }
        lastTime = nil
    }
    public func evaluate(snapshot: MetricSnapshot, processes: [ProcessSample], rules: [AlertRule], excludedApps: Set<String> = [], paused: Bool = false, mutedRuleIDs: Set<UUID> = [], uptime: Double) -> [AlertEvent] {
        let gap = lastTime.map { uptime - $0 > 30 || uptime < $0 } ?? false
        lastTime = uptime
        let ids = Set(rules.map(\.id))
        states = states.filter { ids.contains($0.key) }
        var events: [AlertEvent] = []
        for rule in rules {
            var state = states[rule.id] ?? State(rule: rule)
            if state.rule != rule { state = State(rule: rule) }
            if gap { state.since = nil; state.active = false }
            let excluded = rule.appKey.map { excludedApps.contains($0) } ?? false
            guard rule.enabled, rule.isValid, !paused, !excluded, !mutedRuleIDs.contains(rule.id),
                  let value = measurement(rule, snapshot, processes), value.isFinite else {
                state.since = nil; state.active = false; states[rule.id] = state; continue
            }
            let below = rule.metric == .diskFreeGB
            let exceeds = below ? value < rule.threshold : value >= rule.threshold
            let recovered: Bool
            if rule.metric == .pressure { recovered = value < rule.threshold }
            else { recovered = below ? value >= rule.threshold * 1.1 : value <= rule.threshold * 0.9 }
            if state.active {
                if recovered { state.active = false; state.since = nil }
            } else if exceeds {
                if state.since == nil { state.since = uptime }
                let due = uptime - (state.since ?? uptime) >= rule.duration
                let cooled = state.lastFire.map { uptime - $0 >= rule.cooldown } ?? true
                if due && cooled {
                    let group = processes.filter { $0.appKey == rule.appKey }
                    let process = group.max { a, b in
                        rule.metric == .cpu ? (a.cpu ?? 0) < (b.cpu ?? 0) : (a.memoryBytes ?? 0) < (b.memoryBytes ?? 0)
                    }
                    let display = rule.metric == .pressure ? (value >= 2 ? "критическое" : "повышенное") : String(format: "%.1f", value)
                    events.append(AlertEvent(ruleID: rule.id, date: snapshot.date, title: rule.name,
                        detail: "\(rule.metric.title): \(display) · дольше \(Int(rule.duration)) с", metric: rule.metric,
                        value: value, appKey: rule.appKey, process: process, ruleSnapshot: rule))
                    state.lastFire = uptime; state.active = true
                }
            } else { state.since = nil }
            states[rule.id] = state
        }
        return events
    }
    private func measurement(_ r: AlertRule, _ s: MetricSnapshot, _ p: [ProcessSample]) -> Double? {
        if let key = r.appKey {
            let group = p.filter { $0.appKey == key }
            guard !group.isEmpty else { return nil }
            switch r.metric {
            case .cpu:
                guard group.allSatisfy({ $0.cpu != nil }) else { return nil }
                return group.reduce(0) { $0 + ($1.cpu ?? 0) }
            case .memoryGB:
                guard group.allSatisfy({ $0.memoryBytes != nil }) else { return nil }
                return group.reduce(0) { $0 + Double($1.memoryBytes ?? 0) } / 1e9
            default: return nil
            }
        }
        switch r.metric {
        case .cpu: return s.cpu
        case .memoryGB: return s.memoryUsed.map { Double($0) / 1e9 }
        case .pressure: return s.pressure.map(Double.init)
        case .diskFreeGB: return s.diskFree.map { Double($0) / 1e9 }
        }
    }
}
