import Foundation
import CoreGraphics

public enum PanelPlacement {
    public static func frame(visibleScreen screen: CGRect, anchorX: CGFloat) -> CGRect {
        let width = min(380, max(1, screen.size.width - 16))
        let height = min(554, max(1, screen.size.height - 16))
        return CGRect(x: max(screen.minX + 8, min(anchorX - width, screen.maxX - width - 8)),
                      y: screen.maxY - height - 8, width: width, height: height)
    }
}

/// Text stays editable until valid; invalid text must never save a previous numeric value.
public struct RuleDraft {
    public var rule: AlertRule
    public var threshold: String
    public var duration: String
    public var cooldown: String
    public init(rule: AlertRule) {
        self.rule = rule
        threshold = String(rule.threshold); duration = String(rule.duration); cooldown = String(rule.cooldown)
    }
    public var availableMetrics: [RuleMetric] { rule.appKey == nil ? RuleMetric.allCases : [.cpu, .memoryGB] }
    public mutating func setAppKey(_ key: String?) {
        rule.appKey = key
        if !availableMetrics.contains(rule.metric) { rule.metric = .cpu; threshold = "80" }
    }
    private func number(_ text: String) -> Double? {
        guard let value = Double(text.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")), value.isFinite else { return nil }
        return value
    }
    public var validationMessage: String? {
        if rule.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "Введите название правила." }
        guard let t = number(threshold), let d = number(duration), let c = number(cooldown) else { return "Введите числа: например, 80 или 1,5." }
        if t <= 0 { return "Порог должен быть больше нуля." }
        if rule.metric == .cpu && t > 100 { return "CPU: укажите порог от 0 до 100%." }
        if rule.metric == .pressure && t != 1 && t != 2 { return "Давление на память: 1 — повышенное, 2 — критическое." }
        if d < 0 || d > 86400 { return "Длительность: от 0 до 86 400 секунд." }
        if c < 0 || c > 604800 { return "Интервал повторов: от 0 до 604 800 секунд." }
        if !availableMetrics.contains(rule.metric) { return "Для приложения доступны CPU и память." }
        return nil
    }
    public func build() -> AlertRule? {
        guard validationMessage == nil, let t = number(threshold), let d = number(duration), let c = number(cooldown) else { return nil }
        var result = rule
        result.name = result.name.trimmingCharacters(in: .whitespacesAndNewlines)
        result.threshold = t; result.duration = d; result.cooldown = c
        return result.isValid ? result : nil
    }
}
