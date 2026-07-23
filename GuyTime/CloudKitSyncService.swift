import CloudKit
import Foundation

actor CloudKitSyncService {
    static let shared = CloudKitSyncService()

    private let container = CKContainer.default()
    private var privateDatabase: CKDatabase { container.privateCloudDatabase }
    private var sharedDatabase: CKDatabase { container.sharedCloudDatabase }
    private let entryRecordType = "FeedingEntry"
    private let rootRecordType = "GuyTimeFamily"

    enum SyncError: LocalizedError {
        case iCloudUnavailable
        case rootMissing

        var errorDescription: String? {
            switch self {
            case .iCloudUnavailable: return "iCloud אינו זמין במכשיר הזה."
            case .rootMissing: return "לא נמצא מרחב שיתוף משפחתי."
            }
        }
    }

    func accountStatus() async throws -> CKAccountStatus {
        try await container.accountStatus()
    }

    func ensurePrivateRoot() async throws -> CKRecord {
        let id = CKRecord.ID(recordName: SharedConfiguration.cloudRootRecordName)
        do {
            return try await privateDatabase.record(for: id)
        } catch let error as CKError where error.code == .unknownItem {
            let root = CKRecord(recordType: rootRecordType, recordID: id)
            root["name"] = "Guy Time" as CKRecordValue
            root["createdAt"] = Date() as CKRecordValue
            return try await privateDatabase.save(root)
        }
    }

    func push(entries: [FeedingEntry], vitaminDDate: Date?) async throws {
        let status = try await accountStatus()
        guard status == .available else { throw SyncError.iCloudUnavailable }
        let root = try await ensurePrivateRoot()

        var records = entries.map { entryRecord(from: $0, parent: root.recordID) }
        let settingsID = CKRecord.ID(recordName: "settings", zoneID: root.recordID.zoneID)
        let settings = CKRecord(recordType: "GuyTimeSettings", recordID: settingsID)
        settings["vitaminDDate"] = vitaminDDate as CKRecordValue?
        settings["updatedAt"] = Date() as CKRecordValue
        settings.parent = CKRecord.Reference(recordID: root.recordID, action: .none)
        records.append(settings)

        for chunk in records.chunked(into: 200) {
            _ = try await privateDatabase.modifyRecords(saving: chunk, deleting: [], savePolicy: .changedKeys, atomically: false)
        }
    }

    func fetchAll() async throws -> (entries: [FeedingEntry], vitaminDDate: Date?) {
        let status = try await accountStatus()
        guard status == .available else { throw SyncError.iCloudUnavailable }

        var merged: [UUID: FeedingEntry] = [:]
        var vitaminDDate: Date?

        for database in [privateDatabase, sharedDatabase] {
            let fetched = try await fetchRecords(recordType: entryRecordType, database: database)
            for record in fetched {
                guard let entry = feedingEntry(from: record) else { continue }
                if let current = merged[entry.id] {
                    if entry.updatedAt > current.updatedAt { merged[entry.id] = entry }
                } else {
                    merged[entry.id] = entry
                }
            }

            let settings = try await fetchRecords(recordType: "GuyTimeSettings", database: database)
            let newest = settings.max { lhs, rhs in
                (lhs["updatedAt"] as? Date ?? .distantPast) < (rhs["updatedAt"] as? Date ?? .distantPast)
            }
            if let date = newest?["vitaminDDate"] as? Date { vitaminDDate = date }
        }

        return (Array(merged.values), vitaminDDate)
    }

    func makeShare() async throws -> (CKShare, CKContainer) {
        let root = try await ensurePrivateRoot()
        if let existing = try? await existingShare(for: root) { return (existing, container) }

        let share = CKShare(rootRecord: root)
        share[CKShare.SystemFieldKey.title] = "Guy Time – גיא" as CKRecordValue
        share.publicPermission = .none
        _ = try await privateDatabase.modifyRecords(saving: [root, share], deleting: [], savePolicy: .changedKeys, atomically: true)
        return (share, container)
    }

    func acceptShare(metadata: CKShare.Metadata) async throws {
        try await container.accept(metadata)
    }

    private func existingShare(for root: CKRecord) async throws -> CKShare {
        guard let shareReference = root.share else { throw SyncError.rootMissing }
        guard let share = try await privateDatabase.record(for: shareReference.recordID) as? CKShare else { throw SyncError.rootMissing }
        return share
    }

    private func entryRecord(from entry: FeedingEntry, parent: CKRecord.ID) -> CKRecord {
        let record = CKRecord(recordType: entryRecordType, recordID: CKRecord.ID(recordName: entry.id.uuidString, zoneID: parent.zoneID))
        record["entryID"] = entry.id.uuidString as CKRecordValue
        record["date"] = entry.date as CKRecordValue
        record["updatedAt"] = entry.updatedAt as CKRecordValue
        record["isDeleted"] = entry.isDeleted as CKRecordValue
        record.parent = CKRecord.Reference(recordID: parent, action: .none)
        switch entry.kind {
        case let .nursing(side, duration):
            record["kind"] = "nursing" as CKRecordValue
            record["side"] = side.rawValue as CKRecordValue
            record["duration"] = duration as CKRecordValue
        case let .bottle(type, milliliters):
            record["kind"] = "bottle" as CKRecordValue
            record["bottleType"] = type.rawValue as CKRecordValue
            record["milliliters"] = milliliters as CKRecordValue
        }
        return record
    }

    private func feedingEntry(from record: CKRecord) -> FeedingEntry? {
        guard let idString = record["entryID"] as? String,
              let id = UUID(uuidString: idString),
              let date = record["date"] as? Date,
              let kindName = record["kind"] as? String else { return nil }
        let updatedAt = record["updatedAt"] as? Date ?? date
        let isDeleted = record["isDeleted"] as? Bool ?? false
        let kind: FeedingKind
        if kindName == "nursing",
           let sideName = record["side"] as? String,
           let side = FeedingSide(rawValue: sideName) {
            kind = .nursing(side: side, duration: record["duration"] as? Double ?? 0)
        } else if kindName == "bottle",
                  let typeName = record["bottleType"] as? String,
                  let type = BottleType(rawValue: typeName) {
            kind = .bottle(type: type, milliliters: record["milliliters"] as? Int ?? 0)
        } else { return nil }
        return FeedingEntry(id: id, date: date, kind: kind, updatedAt: updatedAt, isDeleted: isDeleted)
    }

    private func fetchRecords(recordType: String, database: CKDatabase) async throws -> [CKRecord] {
        var result: [CKRecord] = []
        var cursor: CKQueryOperation.Cursor?
        repeat {
            let page: (matchResults: [(CKRecord.ID, Result<CKRecord, Error>)], queryCursor: CKQueryOperation.Cursor?)
            if let cursor {
                page = try await database.records(continuingMatchFrom: cursor, resultsLimit: 200)
            } else {
                page = try await database.records(matching: CKQuery(recordType: recordType, predicate: NSPredicate(value: true)), resultsLimit: 200)
            }
            result.append(contentsOf: page.matchResults.compactMap { try? $0.1.get() })
            cursor = page.queryCursor
        } while cursor != nil
        return result
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [] }
        return stride(from: 0, to: count, by: size).map { Array(self[$0..<Swift.min($0 + size, count)]) }
    }
}
