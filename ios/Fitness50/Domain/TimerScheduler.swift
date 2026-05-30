import Foundation
import UserNotifications

enum TimerScheduler {
    static func schedule(_ timer: PendingTimer) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }

            let content = UNMutableNotificationContent()
            content.title = timer.label
            content.body = "Time's up."
            content.sound = .default

            let interval = max(1, timer.fireAt.timeIntervalSinceNow)
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
            let request = UNNotificationRequest(
                identifier: notificationIdentifier(for: timer.id),
                content: content,
                trigger: trigger
            )

            center.add(request)
        }
    }

    static func cancel(_ timerId: UUID) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [notificationIdentifier(for: timerId)]
        )
    }

    private static func notificationIdentifier(for timerId: UUID) -> String {
        "fitness50-timer-\(timerId.uuidString)"
    }
}
