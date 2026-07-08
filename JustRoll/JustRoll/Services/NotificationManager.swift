import Foundation
import UserNotifications
import UIKit

extension Notification.Name {
    /// Posted when the user taps a notification; object is the tab index to open.
    static let openTabFromNotification = Notification.Name("openTabFromNotification")
}

/// Owns all UserNotifications work: permission + APNs registration, the two
/// on-device reminders (rolling nudge, unsent reminder), and routing taps on
/// any notification (local or remote) to the right tab.
final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    private static let nudgeId = "rolling-nudge"
    private static let unsentIdPrefix = "unsent-reminder-"
    private static let unsentIds = (1...7).map { "\(unsentIdPrefix)\($0)" }

    private static let nudgeInterval: TimeInterval = 3 * 3600
    private static let unsentInterval: TimeInterval = 24 * 3600

    /// Tab indices — must match the TabView tags in RootTabView.
    private enum Tab: Int { case circles = 0, unsent = 1, memory = 2 }

    // MARK: Permission + remote registration

    /// Ask for notification permission (first call shows the system prompt)
    /// and register with APNs so the device gets a push token. Called once
    /// the user is signed in.
    func requestAuthorizationAndRegister() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        Task {
            let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
            guard granted else { return }
            await MainActor.run { UIApplication.shared.registerForRemoteNotifications() }
        }
    }

    // MARK: Rolling nudge (#3) — one repeating local notification

    /// Keep the "Still hanging out?" nudge in sync with rolling state.
    /// A single fixed identifier means rolling in several circles at once
    /// still produces exactly one nudge, and an already-pending nudge is
    /// left alone so starting a second roll doesn't reset the 3 h clock.
    func syncRollingNudge(isRollingAnywhere: Bool, nudgesEnabled: Bool) {
        let center = UNUserNotificationCenter.current()
        guard isRollingAnywhere && nudgesEnabled else {
            cancelRollingNudge()
            return
        }
        center.getPendingNotificationRequests { pending in
            guard !pending.contains(where: { $0.identifier == Self.nudgeId }) else { return }
            let content = UNMutableNotificationContent()
            content.title = "Still hanging out?"
            content.body  = "You're still rolling — stop the roll when you're done."
            content.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: Self.nudgeInterval, repeats: true)
            center.add(UNNotificationRequest(identifier: Self.nudgeId, content: content, trigger: trigger))
        }
    }

    func cancelRollingNudge() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.nudgeId])
        center.removeDeliveredNotifications(withIdentifiers: [Self.nudgeId])
    }

    // MARK: Unsent reminder (#4) — daily one-shots capped at batch expiry

    /// Keep the daily "You have unsent photos" reminders in sync with
    /// RollStore. One-shot notifications (not a repeating trigger) so the
    /// series naturally stops at the newest batch's 7-day expiry even if
    /// the app is never opened again.
    func syncUnsentReminder() {
        let center = UNUserNotificationCenter.current()
        guard let latestStop = RollStore.all().map(\.stoppedAt).max() else {
            center.removePendingNotificationRequests(withIdentifiers: Self.unsentIds)
            return
        }
        // Matches PendingBatch.expiresAt / RollStore's 7-day prune window.
        let expiry = latestStop.addingTimeInterval(7 * 24 * 3600)
        let expiryStamp = expiry.timeIntervalSince1970.rounded()

        center.getPendingNotificationRequests { pending in
            // Series already covering the newest batch → leave it, so app
            // relaunches don't reset the 24 h clock.
            let alreadyScheduled = pending.contains {
                $0.identifier.hasPrefix(Self.unsentIdPrefix)
                    && ($0.content.userInfo["expiry"] as? Double) == expiryStamp
            }
            guard !alreadyScheduled else { return }

            center.removePendingNotificationRequests(withIdentifiers: Self.unsentIds)
            var fireDate = Date().addingTimeInterval(Self.unsentInterval)
            for id in Self.unsentIds where fireDate <= expiry {
                let content = UNMutableNotificationContent()
                content.title = "You have unsent photos"
                content.body  = "A roll is waiting to be reviewed and sent before it expires."
                content.sound = .default
                content.userInfo = ["expiry": expiryStamp]
                let trigger = UNTimeIntervalNotificationTrigger(
                    timeInterval: fireDate.timeIntervalSinceNow, repeats: false)
                center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
                fireDate = fireDate.addingTimeInterval(Self.unsentInterval)
            }
        }
    }

    // MARK: Memory push date label

    /// "today" / "yesterday" / weekday name / "last week" / "Jun 30" —
    /// the {date} part of the memory push, computed on the sender's device
    /// so it's correct for the group's timezone.
    static func relativeDayLabel(for date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "today" }
        if cal.isDateInYesterday(date) { return "yesterday" }
        let days = cal.dateComponents(
            [.day], from: cal.startOfDay(for: date), to: cal.startOfDay(for: Date())
        ).day ?? 0
        let fmt = DateFormatter()
        if days < 7 {
            fmt.dateFormat = "EEEE"
        } else if days < 14 {
            return "last week"
        } else {
            fmt.dateFormat = "MMM d"
        }
        return fmt.string(from: date)
    }

    // MARK: UNUserNotificationCenterDelegate

    /// Show notifications as banners even while the app is foregrounded.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list, .sound])
    }

    /// Route a tap to the matching tab: nudge → Circles, unsent reminder →
    /// Unsent, memory push → Memory, member-joined push → Circles.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let id = response.notification.request.identifier
        let kind = response.notification.request.content.userInfo["kind"] as? String

        let tab: Tab
        if id.hasPrefix(Self.unsentIdPrefix) {
            tab = .unsent
        } else if kind == "memory" {
            tab = .memory
        } else {
            tab = .circles   // rolling nudge + member_joined
        }
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .openTabFromNotification, object: tab.rawValue)
        }
        completionHandler()
    }
}
