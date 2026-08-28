import Foundation
import UserNotifications

/// Local notifications, no push server: a 7:00 ping about the question of
/// the week and a 19:00 tasks check-in — whose text mentions nudges if any
/// are waiting — plus an immediate alert when a nudge arrives. Everything is
/// re-scheduled from live app state every time the app leaves the foreground
/// (and again on each launch), so the texts always reflect the latest sync.
enum Notifications {
    static let questionID = "daily-question-0700"
    static let tasksID = "daily-tasks-1900"
    static let nudgeID = "nudge-immediate"

    // Retained for the app's lifetime — UNUserNotificationCenter holds its
    // delegate weakly.
    private static let foregroundPresenter = ForegroundPresenter()

    static func installDelegate() {
        UNUserNotificationCenter.current().delegate = foregroundPresenter
    }

    /// Ask only once, right after a successful connect: the user has just
    /// chosen to make the app part of their day, which is the moment a
    /// permission prompt makes sense.
    static func requestAuthorizationIfNeeded() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else { return }
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    /// (Re)build the two repeating daily reminders. Passing the current nudge
    /// state lets the 19:00 body call out unanswered nudges.
    static func reschedule(hasUnseenNudges: Bool, nudgerName: String?) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [questionID, tasksID])

        let question = UNMutableNotificationContent()
        question.title = "This week's question 🍯"
        question.body = "Answer it, then see what your partner said."
        question.sound = .default
        center.add(UNNotificationRequest(
            identifier: questionID,
            content: question,
            trigger: UNCalendarNotificationTrigger(dateMatching: DateComponents(hour: 7), repeats: true)
        ))

        let evening = UNMutableNotificationContent()
        evening.title = "Tasks check-in 🐝"
        if hasUnseenNudges {
            evening.body = "\(nudgerName ?? "Your partner") nudged you about this week's question — and there may be tasks left today."
        } else {
            evening.body = "Any tasks left today? Points don't earn themselves."
        }
        evening.sound = .default
        center.add(UNNotificationRequest(
            identifier: tasksID,
            content: evening,
            trigger: UNCalendarNotificationTrigger(dateMatching: DateComponents(hour: 19), repeats: true)
        ))
    }

    /// Immediate alert for a nudge that just came in. Fires while the app is
    /// open too — ForegroundPresenter shows it as a banner.
    static func nudgeAlert(from name: String?) {
        let content = UNMutableNotificationContent()
        content.title = "\(name ?? "Your partner") nudged you 🐝"
        content.body = "They're waiting on your answer to this week's question."
        content.sound = .default
        UNUserNotificationCenter.current().add(UNNotificationRequest(
            identifier: nudgeID,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        ))
    }

    static func cancelAll() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [questionID, tasksID, nudgeID])
        center.removeDeliveredNotifications(withIdentifiers: [nudgeID])
    }
}

/// Shows notification banners even while Hunny is in the foreground —
/// without this, an alert arriving on-screen would be swallowed.
private final class ForegroundPresenter: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
