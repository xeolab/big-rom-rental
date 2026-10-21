import SwiftUI
import RentalKit

enum Route: Hashable {
    case login
    case fitting
    case plan
    case confirm(RentalPlan)
    case pendingPayment(String)
    case orders
    case order(String)
    case renew(String)
    case returnFlow(String)
    case scanner
    case demoTools
}

struct AppAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

/// Navigation + cross-screen events (deep links, notifications). Business state lives in `RentalStore`.
@MainActor
final class AppModel: ObservableObject {
    @Published var path: [Route] = []
    @Published var alert: AppAlert?
    /// Shown once on the order page right after a successful payment.
    @Published var justPaidOrderID: String?

    let store: RentalStore
    let notifications: NotificationService

    init(store: RentalStore) {
        self.store = store
        self.notifications = NotificationService(store: store)
        notifications.onOpenOrder = { [weak self] id in self?.apply(.openRenew(orderID: id)) }
    }

    // MARK: deep links / QR

    func open(_ url: URL) {
        guard let route = QRRoute.parse(url) else {
            alert = AppAlert(title: "无法识别的二维码", message: "请扫描 XEO 租赁柜机或 Rom 上显示的二维码。")
            return
        }
        apply(store.handle(route))
    }

    func open(text: String) {
        guard let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            alert = AppAlert(title: "无法识别的二维码", message: text)
            return
        }
        open(url)
    }

    func apply(_ outcome: DeepLinkOutcome) {
        switch outcome {
        case let .startRent(_, needsLogin):
            path = needsLogin ? [.login] : [.fitting]
        case let .activated(orderID, device):
            path = [.order(orderID)]
            alert = AppAlert(title: "Rom 已激活", message: "设备 \(device) 已关联到订单 \(orderID)，回到 Rom 上继续下一步即可。")
        case .activationNeedsOrder:
            path = []
            alert = AppAlert(title: "还没有租赁中的订单", message: "请先扫描柜机二维码完成租赁，再激活 Rom。")
        case let .openRenew(orderID):
            path = [.order(orderID), .renew(orderID)]
        case .renewNeedsOrder:
            path = []
            alert = AppAlert(title: "没有可续租的订单", message: "当前账号下没有租赁中的设备。")
        }
    }

    /// After login: continue the rental if one was started, otherwise go back home.
    func didLogin() {
        path = store.draft != nil ? [.fitting] : []
    }

    // MARK: payment

    /// 「二次确认」→ 确定.
    func confirmPayment(orderID: String) {
        do {
            try store.pay(orderID)
            justPaidOrderID = orderID
            if let o = store.order(orderID) { notifications.scheduleReminders(for: o) }
            path = [.order(orderID)]
        } catch let e as OrderError {
            alert = AppAlert(title: "支付未完成", message: e.message)
        } catch {
            alert = AppAlert(title: "支付未完成", message: "\(error)")
        }
    }

    /// 「二次确认」→ 取消: the order stays unpaid and its countdown page opens.
    func cancelPayment(orderID: String) {
        path = [.pendingPayment(orderID)]
    }

    func show(_ error: Error, title: String) {
        alert = AppAlert(title: title, message: (error as? OrderError)?.message ?? "\(error)")
    }
}
