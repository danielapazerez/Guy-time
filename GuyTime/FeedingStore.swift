import Foundation
import WidgetKit

@MainActor
final class FeedingStore: ObservableObject {
    @Published var entries: [FeedingEntry] = [] { didSet { persistAndRefresh() } }
    @Published var activeNursing: ActiveNursing? { didSet { persistAndRefresh() } }
    @Published var vitaminDDate: Date? { didSet { persistAndRefresh() } }
    @Published private(set) var isSyncing = false
    @Published private(set) var lastSyncDate: Date?
    @Published var syncErrorMessage: String?

    private let key = "GuyTime.store.v2"
    private let legacyKey = "GuyTime.store.v1"
    private var syncTask: Task<Void, Never>?

    init() {
        load()
        refreshWidget()
    }

    deinit { syncTask?.cancel() }

    var visibleEntries: [FeedingEntry] { entries.filter { !$0.isDeleted } }
    var sortedEntries: [FeedingEntry] { visibleEntries.sorted { $0.date > $1.date } }
    var lastFeedingDate: Date? { visibleEntries.map(\.date).max() }
    var todayEntries: [FeedingEntry] { visibleEntries.filter { Calendar.current.isDateInToday($0.date) } }

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
        scheduleSync()
    }

    func stopActiveNursing(now: Date = Date()) {
        guard let active = activeNursing else { return }
        entries.append(FeedingEntry(date: now, kind: .nursing(side: active.side, duration: max(1, now.timeIntervalSince(active.startedAt)))))
        activeNursing = nil
        scheduleSync()
    }

    func addBottle(type: BottleType, milliliters: Int, date: Date = Date()) {
        guard milliliters > 0 else { return }
        entries.append(FeedingEntry(date: date, kind: .bottle(type: type, milliliters: milliliters)))
        scheduleSync()
    }

    func toggleVitaminD() {
        vitaminDDate = vitaminDTakenToday ? nil : Date()
        scheduleSync()
    }

    func delete(_ entry: FeedingEntry) {
        guard let index = entries.firstIndex(where: { $0.id == entry.id }) else { return }
        entries[index].isDeleted = true
        entries[index].updatedAt = Date()
        scheduleSync()
    }

    func update(_ entry: FeedingEntry) {
        guard let index = entries.firstIndex(where: { $0.id == entry.id }) else { return }
        var changed = entry
        changed.updatedAt = Date()
        entries[index] = changed
        scheduleSync()
    }

    func syncNow() async {
        guard !isSyncing else { return }
        isSyncing = true
        syncErrorMessage = nil
        defer { isSyncing = false }
        do {
            try await CloudKitSyncService.shared.push(entries: entries, vitaminDDate: vitaminDDate)
            let remote = try await CloudKitSyncService.shared.fetchAll()
            merge(remote.entries)
            if let remoteVitamin = remote.vitaminDDate,
               vitaminDDate == nil || remoteVitamin > (vitaminDDate ?? .distantPast) {
                vitaminDDate = remoteVitamin
            }
            lastSyncDate = Date()
        } catch {
            syncErrorMessage = error.localizedDescription
        }
    }

    func refreshFromCloud() async {
        guard !isSyncing else { return }
        isSyncing = true
        syncErrorMessage = nil
        defer { isSyncing = false }
        do {
            let remote = try await CloudKitSyncService.shared.fetchAll()
            merge(remote.entries)
            if let remoteVitamin = remote.vitaminDDate { vitaminDDate = remoteVitamin }
            lastSyncDate = Date()
        } catch {
            syncErrorMessage = error.localizedDescription
        }
    }

    private func merge(_ remote: [FeedingEntry]) {
        var map = Dictionary(uniqueKeysWithValues: entries.map { ($0.id, $0) })
        for item in remote {
            if let current = map[item.id] {
                if item.updatedAt > current.updatedAt { map[item.id] = item }
            } else {
                map[item.id] = item
            }
        }
        entries = Array(map.values)
    }

    private func scheduleSync() {
        syncTask?.cancel()
        syncTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            await self?.syncNow()
        }
        if let lastFeedingDate { NotificationManager.shared.scheduleAfterFeeding(from: lastFeedingDate) }
    }

    private struct PersistedState: Codable {
        var entries: [FeedingEntry]
        var activeNursing: ActiveNursing?
        var vitaminDDate: Date?
    }

    private func persistAndRefresh() {
        let state = PersistedState(entries: entries, activeNursing: activeNursing, vitaminDDate: vitaminDDate)
        if let data = try? JSONEncoder().encode(state) { UserDefaults.standard.set(data, forKey: key) }
        refreshWidget()
    }

    private func load() {
        let defaults = UserDefaults.standard
        guard let data = defaults.data(forKey: key) ?? defaults.data(forKey: legacyKey),
              let state = try? JSONDecoder().decode(PersistedState.self, from: data) else { return }
        entries = state.entries
        activeNursing = state.activeNursing
        vitaminDDate = state.vitaminDDate
    }

    private func refreshWidget() {
        guard let defaults = UserDefaults(suiteName: SharedConfiguration.appGroupIdentifier) else { return }
        let last = sortedEntries.first
        let title: String
        switch last?.kind {
        case let .nursing(side, _): title = "הנקה · \(side.rawValue)"
        case let .bottle(type, ml): title = "\(type.rawValue) · \(ml) מ״ל"
        case nil: title = "עדיין אין האכלות"
        }
        let snapshot = WidgetSnapshot(lastFeedingDate: last?.date, lastFeedingTitle: title, lastNursingSide: lastNursingSide?.rawValue, activeSide: activeNursing?.side.rawValue, activeStartedAt: activeNursing?.startedAt, updatedAt: Date())
        if let data = try? JSONEncoder().encode(snapshot) {
            defaults.set(data, forKey: SharedConfiguration.widgetSnapshotKey)
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
}
