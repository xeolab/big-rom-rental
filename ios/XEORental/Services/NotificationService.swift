import Foundation
import UserNotifications
import RentalKit

/// Local rental reminders with 续租 / 稍后提醒 actions. No push server: everything is scheduled on device.
///
/// Demo clock: order dates live on the demo clock (`store.now` may be fast-forwarded), so a
/// demo date D fires at real time D − clock.offset.
@MainActor
final class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    static let category = "XEO_RENTAL_REMINDER"
    static let renewAction = "RENEW"
    static let snoozeAction = "SNOOZE"
    /// Demo value: 「稍后提醒」 re-fires after one minute so it can be shown live.
    static let snoozeInterval: TimeInterval = 60

    private let store: RentalStore
    private let center = UNUserNotificationCenter.current()
    var onOpenOrder: ((String) -> Void)?

    init(store: RentalStore) {
        self.store = store
        super.init()
    }

    func activate() {
        center.delegate = self
        let renew = UNNotificationAction(identifier: Self.renewAction, title: "续租", options: [.foreground])
        let snooze = UNNotificationAction(identifier: Self.snoozeAction, title: "稍后提醒", options: [])
        center.setNotificationCategories([UNNotificationCategory(identifier: Self.category, actions: [renew, snooze], intentIdentifiers: [], options: [])])
        center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    /// Two reminders per rental: 1 day before the end, and at the end (overdue).
    func scheduleReminders(for order: Order) {
        cancelReminders(for: order.id)
        guard order.status == .renting, let end = order.endsAt else { return }
        let offset = store.clock.offset
        let plans: [(String, Date, String, String)] = [
            ("expiring", end.addingTimeInterval(-86_400), "【XEO 租期提醒】租期即将到期", "您的 Rom 设备租期还剩 1 天，到期时间 \(Formatters.dateTime.string(from: end))。点「续租」继续使用，或在订单里选择归还方式。"),
            ("overdue", end, "【XEO 租期提醒】租期已到期", "您的 Rom 设备已到期，逾期将按天计费。点「续租」继续使用，或尽快归还。"),
        ]
        for (kind, demoDate, title, body) in plans {
            let fireIn = demoDate.addingTimeInterval(-offset).timeIntervalSinceNow
            guard fireIn > 1 else { continue }
            add(id: "\(order.id).\(kind)", orderID: order.id, title: title, body: body, after: fireIn)
        }
    }

    func cancelReminders(for orderID: String) {
        center.removePendingNotificationRequests(withIdentifiers: ["\(orderID).expiring", "\(orderID).overdue", "\(orderID).snooze", "\(orderID).now"])
    }

    /// Demo tool: send the reminder matching the order's current phase in 3 seconds.
    func fireNow(for order: Order) {
        let phase = order.phase(at: store.now)
        let body: String
        switch phase {
        case let .overdue(by): body = "您的 Rom 设备已逾期 \(DurationText.format(by))。点「续租」继续使用，或尽快归还。"
        case let .expiringSoon(left), let .renting(left): body = "您的 Rom 设备租期还剩 \(DurationText.format(left))。点「续租」继续使用，或在订单里选择归还方式。"
        default: body = "订单 \(order.id) 当前状态：\(phase.title)"
        }
        add(id: "\(order.id).now", orderID: order.id, title: "【XEO 租期提醒】", body: body, after: 3)
    }

    private func add(id: String, orderID: String, title: String, body: String, after seconds: TimeInterval) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = Self.category
        content.userInfo = ["orderID": orderID]
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, seconds), repeats: false)
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    // MARK: UNUserNotificationCenterDelegate

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                            withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .list])   // show even while the app is open (demo)
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                            withCompletionHandler completionHandler: @escaping () -> Void) {
        let orderID = response.notification.request.content.userInfo["orderID"] as? String
        let action = response.actionIdentifier
        let content = response.notification.request.content
        Task { @MainActor in
            defer { completionHandler() }
            guard let orderID else { return }
            if action == Self.snoozeAction {
                self.add(id: "\(orderID).snooze", orderID: orderID, title: content.title, body: content.body, after: Self.snoozeInterval)
            } else {
                // 「续租」 or a tap on the notification body.
                self.onOpenOrder?(orderID)
            }
        }
    }
}
