import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var store: FeedingStore
    @State private var editing: FeedingEntry?

    var body: some View {
        NavigationStack {
            List {
                ForEach(store.sortedEntries) { entry in
                    Button { editing = entry } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(title(for: entry)).fontWeight(.semibold)
                                Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: icon(for: entry))
                                .foregroundStyle(.tint)
                        }
                    }
                    .buttonStyle(.plain)
                    .swipeActions {
                        Button(role: .destructive) { store.delete(entry) } label: {
                            Label("מחיקה", systemImage: "trash")
                        }
                    }
                }
            }
            .overlay {
                if store.visibleEntries.isEmpty {
                    ContentUnavailableView("עדיין אין האכלות", systemImage: "heart")
                }
            }
            .navigationTitle("היסטוריה")
            .sheet(item: $editing) { EntryEditor(entry: $0) }
        }
    }

    private func title(for entry: FeedingEntry) -> String {
        switch entry.kind {
        case let .nursing(side, duration): return "הנקה · \(side.rawValue) · \(Int(duration / 60)) דק׳"
        case let .bottle(type, ml): return "\(type.rawValue) · \(ml) מ״ל"
        }
    }

    private func icon(for entry: FeedingEntry) -> String {
        switch entry.kind {
        case .nursing: return "heart.fill"
        case .bottle: return "waterbottle.fill"
        }
    }
}

private struct EntryEditor: View {
    @EnvironmentObject private var store: FeedingStore
    @Environment(\.dismiss) private var dismiss
    @State var entry: FeedingEntry

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("תאריך ושעה", selection: $entry.date)
                switch entry.kind {
                case let .nursing(side, duration):
                    Picker("צד", selection: Binding(
                        get: { side },
                        set: { entry.kind = .nursing(side: $0, duration: duration) }
                    )) {
                        ForEach(FeedingSide.allCases) { Text($0.rawValue).tag($0) }
                    }
                    Stepper("משך: \(Int(duration / 60)) דקות", value: Binding(
                        get: { Int(duration / 60) },
                        set: { entry.kind = .nursing(side: side, duration: TimeInterval($0 * 60)) }
                    ), in: 1...180)
                case let .bottle(type, ml):
                    Picker("סוג", selection: Binding(
                        get: { type },
                        set: { entry.kind = .bottle(type: $0, milliliters: ml) }
                    )) {
                        ForEach(BottleType.allCases) { Text($0.rawValue).tag($0) }
                    }
                    Stepper("כמות: \(ml) מ״ל", value: Binding(
                        get: { ml },
                        set: { entry.kind = .bottle(type: type, milliliters: $0) }
                    ), in: 10...500, step: 10)
                }
            }
            .navigationTitle("עריכת האכלה")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("ביטול") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("שמירה") { store.update(entry); dismiss() }
                }
            }
        }
    }
}
