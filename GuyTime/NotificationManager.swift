import Foundation
import UserNotifications

@MainActor
final class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    @Published private(set) var authorizationGranted = false
    @Published var reminderHours: Double {
        didSet { UserDefaults.standard.set(reminderHours, forKey: "GuyTime.reminderHours") }
    }

    private let reminderID = "GuyTime.nextFeedingReminder"

    private init() {
        let saved = UserDefaults.standard.double(forKey: "GuyTime.reminderHours")
        reminderHours = saved > 0 ? saved : 3
        Task { await refreshStatus() }
    }

    func requestAuthorization() async {
        do {
            authorizationGranted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            authorizationGranted = false
        }
    }

    func refreshStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorizationGranted = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
    }

    func scheduleAfterFeeding(from date: Date) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [reminderID])
        guard authorizationGranted, reminderHours > 0 else { return }

        let content = UNMutableNotificationContent()
        content.title = "Guy Time"
        content.body = "עברו \(formattedHours) מאז ההאכלה האחרונה של גיא."
        content.sound = .default

        let target = date.addingTimeInterval(reminderHours * 3600)
        let interval = max(60, target.timeIntervalSinceNow)
        center.add(UNNotificationRequest(identifier: reminderID, content: content, trigger: UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)))
    }

    func cancelReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [reminderID])
    }

    private var formattedHours: String {
        reminderHours.rounded() == reminderHours ? "\(Int(reminderHours)) שעות" : "\(reminderHours.formatted()) שעות"
    }
}
