import SwiftUI
import Charts
import AppKit
import MacGlintCore

enum Format {
    static func percent(_ value: Double?) -> String { value.map { String(format: "%.0f%%", $0) } ?? "—" }
    static func bytes(_ value: UInt64?) -> String {
        guard let value else { return "—" }
        if value >= 1_000_000_000 { return String(format: "%.1f ГБ", Double(value) / 1e9) }
        return String(format: "%.0f МБ", Double(value) / 1e6)
    }
    static func rate(_ value: Double?) -> String {
        guard let value else { return "—" }
        if value >= 1e6 { return String(format: "%.1f МБ/с", value / 1e6) }
        return String(format: "%.0f КБ/с", value / 1e3)
    }
}
struct Sparkline: View {
    var values: [Double]
    var color: Color = .blue
    var body: some View {
        GeometryReader { geo in
            let top = max(10, values.max() ?? 10)
            Path { path in
                guard values.count > 1 else { return }
                for (index, value) in values.enumerated() {
                    let point = CGPoint(x: geo.size.width * CGFloat(index) / CGFloat(values.count - 1), y: geo.size.height * (1 - min(1, max(0, value / top))))
                    if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
                }
            }.stroke(color, style: StrokeStyle(lineWidth: 1.7, lineCap: .round, lineJoin: .round))
        }.accessibilityHidden(true)
    }
}
struct MetricTile: View {
    let icon: String; let title: String; let value: String; var subtitle = ""; var color: Color = .blue
    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Label(title, systemImage: icon).font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.8)
            Text(value).font(.system(size: 20, weight: .medium)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.7)
            if !subtitle.isEmpty { Text(subtitle).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1) }
        }.frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
    }
}
struct AppIcon: View {
    let key: String
    private static let cache = NSCache<NSString, NSImage>()
    var body: some View {
        Group {
            if key.hasSuffix(".app") { Image(nsImage: icon).resizable() }
            else { Image(systemName: key.localizedCaseInsensitiveContains("webkit") ? "globe" : "gearshape.2").resizable().scaledToFit().padding(4).foregroundStyle(.secondary) }
        }.frame(width: 28, height: 28).accessibilityHidden(true)
    }
    private var icon: NSImage {
        if let cached = Self.cache.object(forKey: key as NSString) { return cached }
        let image = NSWorkspace.shared.icon(forFile: key)
        Self.cache.countLimit = 100; Self.cache.setObject(image, forKey: key as NSString)
        return image
    }
}
struct SmallLabel: View {
    let text: String
    var body: some View { Text(text).font(.system(size: 11)).foregroundStyle(.secondary) }
}

struct QuietEmptyState: View {
    let title: String
    let message: String
    var body: some View {
        VStack(spacing: 8) {
            Text(title).font(.headline)
            Text(message).font(.callout).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).frame(maxWidth: 360)
        }.padding(.vertical, 32).frame(maxWidth: .infinity)
    }
}
