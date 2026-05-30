import Foundation
import UserNotifications

enum ReminderScheduler {
    private static let identifierPrefix = "fitness50-workout-reminder-"
    private static let schedulingHorizonDays = 21

    static func reschedule(state: AppState, calendar: Calendar = .current, now: Date = Date()) {
        let settings = state.reminderSettings

        if !settings.enabled {
            cancelAll()
            return
        }

        let requests = pendingRequests(
            state: state,
            settings: settings,
            calendar: calendar,
            now: now
        )
        let center = UNUserNotificationCenter.current()

        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }

            center.getPendingNotificationRequests { pendingRequests in
                let identifiers = pendingRequests
                    .map(\.identifier)
                    .filter { $0.hasPrefix(identifierPrefix) }
                center.removePendingNotificationRequests(withIdentifiers: identifiers)

                for request in requests {
                    center.add(request)
                }
            }
        }
    }

    static func cancelAll() {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            let identifiers = requests
                .map(\.identifier)
                .filter { $0.hasPrefix(identifierPrefix) }
            guard !identifiers.isEmpty else { return }
            center.removePendingNotificationRequests(withIdentifiers: identifiers)
        }
    }

    private static func pendingRequests(
        state: AppState,
        settings: ReminderSettings,
        calendar: Calendar,
        now: Date
    ) -> [UNNotificationRequest] {
        (0..<schedulingHorizonDays).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: now)) else {
                return nil
            }

            let dayString = DateCoding.dayString(from: day)
            let plannedWorkouts = unique(
                Program.plan(startDate: state.startDate, date: dayString)
                + (state.rescheduledWorkouts[dayString] ?? [])
            )
            guard !plannedWorkouts.isEmpty else { return nil }

            if let saved = state.sessions[dayString] {
                let completedOrSkipped = Set(saved.completedWorkouts + saved.skippedWorkouts)
                if Set(plannedWorkouts).isSubset(of: completedOrSkipped) {
                    return nil
                }
            }

            guard let fireDate = reminderDate(
                for: day,
                settings: settings,
                calendar: calendar
            ), fireDate > now else {
                return nil
            }

            let content = UNMutableNotificationContent()
            content.title = "Fitness50"
            content.body = "You still have planned movement today."
            content.sound = .default

            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

            return UNNotificationRequest(
                identifier: identifier(for: dayString),
                content: content,
                trigger: trigger
            )
        }
    }

    private static func reminderDate(
        for day: Date,
        settings: ReminderSettings,
        calendar: Calendar
    ) -> Date? {
        var components = calendar.dateComponents([.year, .month, .day], from: day)
        components.hour = settings.hour
        components.minute = settings.minute
        return calendar.date(from: components)
    }

    private static func identifier(for day: String) -> String {
        "\(identifierPrefix)\(day)"
    }

    private static func unique(_ workoutIds: [String]) -> [String] {
        var seen = Set<String>()
        return workoutIds.filter { seen.insert($0).inserted }
    }
}
