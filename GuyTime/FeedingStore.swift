import Foundation

@MainActor
final class FeedingStore: ObservableObject {
    @Published var entries: [FeedingEntry] = [] { didSet { save() } }
    @Published var activeNursing: ActiveNursing? { didSet { save() } }
    @Published var vitaminDDate: Date? { didSet { save() } }

    private let key = "GuyTime.store.v1"

    init() { load() }

    var lastFeedingDate: Date? { entries.map(\.date).max() }

    var lastNursingSide: FeedingSide? {
        entries
            .sorted { $0.date > $1.date }
            .compactMap { entry -> FeedingSide? in
                if case let .nursing(side, _) = entry.kind { return side }
                return nil
            }
            .first
    }

    var vitaminDTakenToday: Bool {
        guard let vitaminDDate else { return false }
        return Calendar.current.isDateInToday(vitaminDDate)
    }

    func toggleNursing(side: FeedingSide) {
        if let active = activeNursing {
            if active.side == side {
                let duration = max(1, Date().timeIntervalSince(active.startedAt))
                entries.append(FeedingEntry(date: Date(), kind: .nursing(side: side, duration: duration)))
                activeNursing = nil
            } else {
                let duration = max(1, Date().timeIntervalSince(active.startedAt))
                entries.append(FeedingEntry(date: Date(), kind: .nursing(side: active.side, duration: duration)))
                activeNursing = ActiveNursing(side: side, startedAt: Date())
            }
        } else {
            activeNursing = ActiveNursing(side: side, startedAt: Date())
        }
    }

    func addBottle(type: BottleType, milliliters: Int) {
        guard milliliters > 0 else { return }
        entries.append(FeedingEntry(date: Date(), kind: .bottle(type: type, milliliters: milliliters)))
    }

    func toggleVitaminD() {
        vitaminDDate = vitaminDTakenToday ? nil : Date()
    }

    func delete(_ entry: FeedingEntry) {
        entries.removeAll { $0.id == entry.id }
    }

    func update(_ entry: FeedingEntry) {
        guard let index = entries.firstIndex(where: { $0.id == entry.id }) else { return }
        entries[index] = entry
    }

    private struct PersistedState: Codable {
        var entries: [FeedingEntry]
        var activeNursing: ActiveNursing?
        var vitaminDDate: Date?
    }

    private func save() {
        let state = PersistedState(entries: entries, activeNursing: activeNursing, vitaminDDate: vitaminDDate)
        if let data = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let state = try? JSONDecoder().decode(PersistedState.self, from: data) else { return }
        entries = state.entries
        activeNursing = state.activeNursing
        vitaminDDate = state.vitaminDDate
    }
}
