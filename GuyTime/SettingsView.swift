import CloudKit
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: FeedingStore
    @StateObject private var notifications = NotificationManager.shared
    @State private var sharePayload: SharePayload?
    @State private var preparingShare = false
    @State private var shareError: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("iCloud וסנכרון") {
                    Button {
                        Task { await store.syncNow() }
                    } label: {
                        Label(store.isSyncing ? "מסנכרן…" : "סנכרון עכשיו", systemImage: "icloud.and.arrow.up")
                    }
                    .disabled(store.isSyncing)

                    if let lastSyncDate = store.lastSyncDate {
                        LabeledContent("סנכרון אחרון", value: lastSyncDate.formatted(date: .omitted, time: .shortened))
                    }
                    if let error = store.syncErrorMessage {
                        Text(error).font(.caption).foregroundStyle(.red)
                    }
                }

                Section("שיתוף עם בן הזוג") {
                    Button {
                        preparingShare = true
                        Task {
                            defer { preparingShare = false }
                            do {
                                let result = try await CloudKitSyncService.shared.makeShare()
                                sharePayload = SharePayload(share: result.0, container: result.1)
                            } catch {
                                shareError = error.localizedDescription
                            }
                        }
                    } label: {
                        Label(preparingShare ? "מכין הזמנה…" : "הזמנת בן הזוג", systemImage: "person.2.badge.plus")
                    }
                    .disabled(preparingShare)
                    Text("ההזמנה נפתחת באמצעות ממשק השיתוף של iCloud ומאפשרת לשני חשבונות Apple לעדכן את אותם הנתונים.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                Section("התראות") {
                    if notifications.authorizationGranted {
                        HStack {
                            Text("תזכורת אחרי")
                            Spacer()
                            Text("\(notifications.reminderHours.formatted()) שעות")
                        }
                        Slider(value: $notifications.reminderHours, in: 1...6, step: 0.5)
                        Button("עדכון התזכורת") {
                            if let date = store.lastFeedingDate { notifications.scheduleAfterFeeding(from: date) }
                        }
                    } else {
                        Button("אפשר התראות") { Task { await notifications.requestAuthorization() } }
                    }
                }

                Section("Widget") {
                    Text("לאחר בניית האפליקציה, לחיצה ארוכה על מסך הבית → ‎+‎ → Guy Time.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("הגדרות")
            .sheet(item: $sharePayload) { payload in
                CloudSharingView(share: payload.share, container: payload.container)
            }
            .alert("לא ניתן ליצור שיתוף", isPresented: Binding(get: { shareError != nil }, set: { if !$0 { shareError = nil } })) {
                Button("אישור") { shareError = nil }
            } message: { Text(shareError ?? "") }
        }
    }
}

private struct SharePayload: Identifiable {
    let id = UUID()
    let share: CKShare
    let container: CKContainer
}
