import SwiftUI
import WidgetKit

private enum WidgetConfiguration {
    static let appGroupIdentifier = "group.com.pazgroup.GuyTime"
    static let snapshotKey = "GuyTime.widget.snapshot.v2"
}

private struct Snapshot: Codable {
    var lastFeedingDate: Date?
    var lastFeedingTitle: String
    var lastNursingSide: String?
    var activeSide: String?
    var activeStartedAt: Date?
    var updatedAt: Date
}

private struct GuyTimeEntry: TimelineEntry {
    let date: Date
    let snapshot: Snapshot
}

private struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> GuyTimeEntry { GuyTimeEntry(date: .now, snapshot: sample) }
    func getSnapshot(in context: Context, completion: @escaping (GuyTimeEntry) -> Void) { completion(GuyTimeEntry(date: .now, snapshot: load() ?? sample)) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<GuyTimeEntry>) -> Void) {
        let entry = GuyTimeEntry(date: .now, snapshot: load() ?? sample)
        completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(15 * 60))))
    }
    private func load() -> Snapshot? {
        guard let data = UserDefaults(suiteName: WidgetConfiguration.appGroupIdentifier)?.data(forKey: WidgetConfiguration.snapshotKey) else { return nil }
        return try? JSONDecoder().decode(Snapshot.self, from: data)
    }
    private var sample: Snapshot { Snapshot(lastFeedingDate: Date().addingTimeInterval(-5400), lastFeedingTitle: "הנקה · ימין", lastNursingSide: "ימין", activeSide: nil, activeStartedAt: nil, updatedAt: .now) }
}

struct GuyTimeWidget: Widget {
    let kind = "GuyTimeWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            GuyTimeWidgetView(entry: entry)
                .containerBackground(.background, for: .widget)
                .environment(\.layoutDirection, .rightToLeft)
        }
        .configurationDisplayName("Guy Time")
        .description("הזמן מאז ההאכלה האחרונה והצד האחרון.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private struct GuyTimeWidgetView: View {
    let entry: GuyTimeEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack { Image(systemName: "heart.fill").foregroundStyle(.pink); Text("Guy Time").font(.headline); Spacer() }
            if let active = entry.snapshot.activeSide, let started = entry.snapshot.activeStartedAt {
                Text("הנקה פעילה · \(active)").font(.caption).foregroundStyle(.secondary)
                Text(started, style: .timer).font(.system(.title2, design: .rounded, weight: .bold)).monospacedDigit()
            } else if let last = entry.snapshot.lastFeedingDate {
                Text("מאז ההאכלה האחרונה").font(.caption).foregroundStyle(.secondary)
                Text(last, style: .timer).font(.system(.title2, design: .rounded, weight: .bold)).monospacedDigit()
                Text(entry.snapshot.lastFeedingTitle).font(.caption2).lineLimit(1)
            } else {
                Text("עדיין אין האכלות").font(.headline)
            }
            Spacer(minLength: 0)
        }
    }
}
