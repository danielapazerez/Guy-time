import Foundation

@MainActor
final class FeedingStore: ObservableObject {
    @Published var entries: [FeedingEntry] = [] { didSet { save() } }
    @Published var activeNursing: ActiveNursing? { didSet { save() } }
    @Published var vitaminDDate: Date? { didSet { save() } }

    private let key = "GuyTime.store.v1"

    init() { load() }

    var sortedEntries: [FeedingEntry] { entries.sorted { $0.date > $1.date } }
    var lastFeedingDate: Date? { entries.map(\.date).max() }

    var todayEntries: [FeedingEntry] {
        entries.filter { Calendar.current.isDateInToday($0.date) }
    }

    var lastNursingSide: FeedingSide? {
        sortedEntries.compactMap { entry -> FeedingSide? in
            if case let .nursing(side, _) = entry.kind { return side }
            return nil
        }.first
    }

    var vitaminDTakenToday: Bool {
        guard let vitaminDDate else { return false }
        return Calendar.current.isDateInToday(vitaminDDate)
    }

    func toggleNursing(side: FeedingSide, now: Date = Date()) {
        if let active = activeNursing {
            let duration = max(1, now.timeIntervalSince(active.startedAt))
            entries.append(FeedingEntry(date: now, kind: .nursing(side: active.side, duration: duration)))
            activeNursing = active.side == side ? nil : ActiveNursing(side: side, startedAt: now)
        } else {
            activeNursing = ActiveNursing(side: side, startedAt: now)
        }
    }

    func stopActiveNursing(now: Date = Date()) {
        guard let active = activeNursing else { return }
        let duration = max(1, now.timeIntervalSince(active.startedAt))
        entries.append(FeedingEntry(date: now, kind: .nursing(side: active.side, duration: duration)))
        activeNursing = nil
    }

    func addBottle(type: BottleType, milliliters: Int, date: Date = Date()) {
        guard milliliters > 0 else { return }
        entries.append(FeedingEntry(date: date, kind: .bottle(type: type, milliliters: milliliters)))
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
        do {
            let data = try JSONEncoder().encode(state)
            UserDefaults.standard.set(data, forKey: key)
        } catch {
            assertionFailure("Guy Time save failed: \(error)")
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key) else { return }
        do {
            let state = try JSONDecoder().decode(PersistedState.self, from: data)
            entries = state.entries
            activeNursing = state.activeNursing
            vitaminDDate = state.vitaminDDate
        } catch {
            assertionFailure("Guy Time load failed: \(error)")
        }
    }
}
