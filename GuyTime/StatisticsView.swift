import SwiftUI

struct StatisticsView: View {
    @EnvironmentObject private var store: FeedingStore

    var nursingEntries: [FeedingEntry] {
        store.entries.filter { if case .nursing = $0.kind { return true }; return false }
    }
    var bottleEntries: [FeedingEntry] {
        store.entries.filter { if case .bottle = $0.kind { return true }; return false }
    }
    var totalNursingSeconds: TimeInterval {
        nursingEntries.reduce(0) { partial, entry in
            if case let .nursing(_, duration) = entry.kind { return partial + duration }
            return partial
        }
    }
    var totalML: Int {
        bottleEntries.reduce(0) { partial, entry in
            if case let .bottle(_, ml) = entry.kind { return partial + ml }
            return partial
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    StatCard(title: "הנקות", value: "\(nursingEntries.count)", icon: "heart.fill")
                    StatCard(title: "זמן הנקה", value: durationText, icon: "timer")
                    StatCard(title: "בקבוקים", value: "\(bottleEntries.count)", icon: "waterbottle.fill")
                    StatCard(title: "סך הכול", value: "\(totalML) מ״ל", icon: "drop.fill")
                    StatCard(title: "ויטמין D", value: store.vitaminDTakenToday ? "נלקח" : "לא נלקח", icon: "checkmark.circle.fill")
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

private struct StatCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon).font(.title)
            Text(value).font(.title2.bold())
            Text(title).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 145)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24))
    }
}
