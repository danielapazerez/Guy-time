import Charts
import SwiftUI

struct StatisticsView: View {
    @EnvironmentObject private var store: FeedingStore
    @State private var period: StatsPeriod = .week

    private var filteredEntries: [FeedingEntry] {
        let start = period.startDate
        return store.visibleEntries.filter { start == nil || $0.date >= start! }
    }

    private var dailyData: [DailyStats] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filteredEntries) { calendar.startOfDay(for: $0.date) }
        return grouped.map { date, entries in
            var nursingMinutes = 0.0, ml = 0
            var nursingCount = 0, bottleCount = 0
            for entry in entries {
                switch entry.kind {
                case let .nursing(_, duration): nursingCount += 1; nursingMinutes += duration / 60
                case let .bottle(_, amount): bottleCount += 1; ml += amount
                }
            }
            return DailyStats(date: date, nursingCount: nursingCount, nursingMinutes: nursingMinutes, bottleCount: bottleCount, milliliters: ml)
        }.sorted { $0.date < $1.date }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    Picker("תקופה", selection: $period) {
                        ForEach(StatsPeriod.allCases) { Text($0.rawValue).tag($0) }
                    }.pickerStyle(.segmented)

                    SummaryGrid(entries: filteredEntries)
                    ChartCard(title: "האכלות ביום") {
                        Chart(dailyData) { day in
                            BarMark(x: .value("יום", day.date, unit: .day), y: .value("האכלות", day.nursingCount + day.bottleCount))
                                .foregroundStyle(.pink.gradient)
                        }
                    }
                    ChartCard(title: "מ״ל בבקבוקים") {
                        Chart(dailyData) { day in
                            LineMark(x: .value("יום", day.date, unit: .day), y: .value("מ״ל", day.milliliters))
                                .interpolationMethod(.catmullRom)
                            PointMark(x: .value("יום", day.date, unit: .day), y: .value("מ״ל", day.milliliters))
                        }
                    }
                    ChartCard(title: "דקות הנקה") {
                        Chart(dailyData) { day in
                            AreaMark(x: .value("יום", day.date, unit: .day), y: .value("דקות", day.nursingMinutes))
                                .foregroundStyle(.green.opacity(0.35).gradient)
                            LineMark(x: .value("יום", day.date, unit: .day), y: .value("דקות", day.nursingMinutes))
                                .foregroundStyle(.green)
                        }
                    }
                    SideBalanceChart(entries: filteredEntries)
                }.padding()
            }.navigationTitle("גרפים וסטטיסטיקה")
        }
    }
}

private struct DailyStats: Identifiable {
    var id: Date { date }
    let date: Date
    let nursingCount: Int
    let nursingMinutes: Double
    let bottleCount: Int
    let milliliters: Int
}

private enum StatsPeriod: String, CaseIterable, Identifiable {
    case today = "היום", week = "7 ימים", month = "30 יום", all = "הכול"
    var id: String { rawValue }
    var startDate: Date? {
        let c = Calendar.current
        switch self {
        case .today: return c.startOfDay(for: Date())
        case .week: return c.date(byAdding: .day, value: -6, to: c.startOfDay(for: Date()))
        case .month: return c.date(byAdding: .day, value: -29, to: c.startOfDay(for: Date()))
        case .all: return nil
        }
    }
}

private struct SummaryGrid: View {
    let entries: [FeedingEntry]
    private var nursing: [(FeedingSide, TimeInterval)] { entries.compactMap { if case let .nursing(s, d) = $0.kind { return (s,d) }; return nil } }
    private var bottles: [Int] { entries.compactMap { if case let .bottle(_, ml) = $0.kind { return ml }; return nil } }
    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            Metric(title: "הנקות", value: "\(nursing.count)", icon: "heart.fill")
            Metric(title: "זמן הנקה", value: "\(Int(nursing.reduce(0) { $0 + $1.1 } / 60)) דק׳", icon: "timer")
            Metric(title: "בקבוקים", value: "\(bottles.count)", icon: "waterbottle.fill")
            Metric(title: "סך מ״ל", value: "\(bottles.reduce(0,+))", icon: "drop.fill")
        }
    }
}

private struct Metric: View {
    let title: String, value: String, icon: String
    var body: some View {
        VStack(spacing: 8) { Image(systemName: icon).font(.title2); Text(value).font(.title2.bold()); Text(title).foregroundStyle(.secondary) }
            .frame(maxWidth: .infinity, minHeight: 110).background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }
}

private struct ChartCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 12) { Text(title).font(.headline); content.frame(height: 190) }
            .padding().background(.thinMaterial, in: RoundedRectangle(cornerRadius: 22))
    }
}

private struct SideBalanceChart: View {
    let entries: [FeedingEntry]
    private var values: [(String, Int)] {
        FeedingSide.allCases.map { side in
            (side.rawValue, entries.filter { if case let .nursing(s, _) = $0.kind { return s == side }; return false }.count)
        }
    }
    var body: some View {
        ChartCard(title: "איזון ימין–שמאל") {
            Chart(values, id: \.0) { item in
                SectorMark(angle: .value("הנקות", item.1), innerRadius: .ratio(0.55), angularInset: 3)
                    .foregroundStyle(by: .value("צד", item.0))
            }.chartLegend(position: .bottom)
        }
    }
}
