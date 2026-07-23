import SwiftUI

struct StatisticsView: View {
    @EnvironmentObject private var store: FeedingStore
    @State private var period: StatsPeriod = .today

    private var filteredEntries: [FeedingEntry] {
        let calendar = Calendar.current
        let now = Date()
        return store.entries.filter { entry in
            switch period {
            case .today: return calendar.isDateInToday(entry.date)
            case .week:
                guard let start = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: now)) else { return true }
                return entry.date >= start
            case .all: return true
            }
        }
    }

    private var nursingEntries: [FeedingEntry] {
        filteredEntries.filter { if case .nursing = $0.kind { return true }; return false }
    }

    private var bottleEntries: [FeedingEntry] {
        filteredEntries.filter { if case .bottle = $0.kind { return true }; return false }
    }

    private var totalNursingSeconds: TimeInterval {
        nursingEntries.reduce(0) { total, entry in
            if case let .nursing(_, duration) = entry.kind { return total + duration }
            return total
        }
    }

    private var totalML: Int {
        bottleEntries.reduce(0) { total, entry in
            if case let .bottle(_, ml) = entry.kind { return total + ml }
            return total
        }
    }

    private func count(side: FeedingSide) -> Int {
        nursingEntries.filter {
            if case let .nursing(entrySide, _) = $0.kind { return entrySide == side }
            return false
        }.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Picker("תקופה", selection: $period) {
                        ForEach(StatsPeriod.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        StatCard(title: "הנקות", value: "\(nursingEntries.count)", icon: "heart.fill")
                        StatCard(title: "זמן הנקה", value: durationText, icon: "timer")
                        StatCard(title: "בקבוקים", value: "\(bottleEntries.count)", icon: "waterbottle.fill")
                        StatCard(title: "סך הכול", value: "\(totalML) מ״ל", icon: "drop.fill")
                        StatCard(title: "ימין", value: "\(count(side: .right))", icon: "r.circle.fill")
                        StatCard(title: "שמאל", value: "\(count(side: .left))", icon: "l.circle.fill")
                    }

                    if period == .today {
                        StatCard(
                            title: "ויטמין D",
                            value: store.vitaminDTakenToday ? "נלקח" : "לא נלקח",
                            icon: store.vitaminDTakenToday ? "checkmark.circle.fill" : "circle"
                        )
                    }
                }
                .padding()
            }
            .navigationTitle("סטטיסטיקה")
        }
    }

    private var durationText: String {
        let minutes = Int(totalNursingSeconds / 60)
        return minutes >= 60 ? "\(minutes / 60)ש׳ \(minutes % 60)ד׳" : "\(minutes) דק׳"
    }
}

private enum StatsPeriod: String, CaseIterable, Identifiable {
    case today = "היום"
    case week = "7 ימים"
    case all = "הכול"
    var id: String { rawValue }
}

private struct StatCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon).font(.title)
            Text(value).font(.title2.bold()).minimumScaleFactor(0.75)
            Text(title).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 140)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24))
    }
}
