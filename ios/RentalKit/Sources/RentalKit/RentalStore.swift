import Foundation
import Combine

public struct Account: Codable, Equatable, Sendable {
    public enum Method: String, Codable, Sendable { case phone, apple }
    public let method: Method
    public let display: String
}

public enum LoginError: Error, Equatable, Sendable {
    case badPhone, badCode
    public var message: String {
        self == .badPhone ? "请输入 11 位手机号" : "请输入 6 位验证码（演示：任意 6 位数字）"
    }
}

/// What the app should do after a QR / deep link (docs/tech/01 §2).
public enum DeepLinkOutcome: Equatable, Sendable {
    case startRent(cabinet: String, needsLogin: Bool)
    case activated(orderID: String, device: String)
    case activationNeedsOrder
    case openRenew(orderID: String)
    case renewNeedsOrder
}

/// Rental flow in progress (before an order exists).
public struct RentDraft: Equatable, Sendable {
    public var cabinet: String
    public var fitting: Fitting?
    public init(cabinet: String, fitting: Fitting? = nil) { self.cabinet = cabinet; self.fitting = fitting }
}

/// App state: account, orders, demo clock. Persisted as one JSON file; no network.
public final class RentalStore: ObservableObject {
    @Published public private(set) var account: Account?
    @Published public private(set) var orders: [Order] = []
    @Published public var draft: RentDraft?
    /// Bumped whenever the clock jumps so views depending on `now` re-render.
    @Published public private(set) var clockVersion = 0

    public let clock: DemoClock
    private let fileURL: URL?

    private struct Snapshot: Codable {
        var account: Account?
        var orders: [Order]
        var clockOffset: TimeInterval
    }

    public init(fileURL: URL?, clock: DemoClock = DemoClock()) {
        self.fileURL = fileURL
        self.clock = clock
        if let fileURL, let data = try? Data(contentsOf: fileURL),
           let snap = try? JSONDecoder().decode(Snapshot.self, from: data) {
            account = snap.account
            orders = snap.orders
            clock.offset = snap.clockOffset
        }
        refreshAll()
    }

    public static func defaultFileURL() -> URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("xeo-rental-state.json")
    }

    public var now: Date { clock.now }

    private func save() {
        guard let fileURL else { return }
        let snap = Snapshot(account: account, orders: orders, clockOffset: clock.offset)
        if let data = try? JSONEncoder().encode(snap) { try? data.write(to: fileURL, options: .atomic) }
    }

    // MARK: account (placeholders — no real SMS / Apple ID calls)

    public var isLoggedIn: Bool { account != nil }

    /// Returns nil on success. Any 6-digit code is accepted (placeholder, no SMS is sent).
    @discardableResult
    public func loginWithPhone(_ phone: String, code: String) -> LoginError? {
        let p = phone.filter(\.isNumber)
        guard p.count == 11, p.hasPrefix("1") else { return .badPhone }
        guard code.count == 6, code.allSatisfy({ $0.isASCII && $0.isNumber }) else { return .badCode }
        account = Account(method: .phone, display: String(p.prefix(3)) + "****" + String(p.suffix(4)))
        save()
        return nil
    }

    public func loginWithApplePlaceholder() {
        account = Account(method: .apple, display: "Apple 账号用户")
        save()
    }

    public func logout() { account = nil; save() }

    // MARK: orders

    public func order(_ id: String) -> Order? { orders.first { $0.id == id } }

    /// Most recent order that is renting (the one a device can belong to).
    public var currentRental: Order? { orders.last { $0.status == .renting } }

    /// Most recent order that still needs the user (renting / returning / unpaid).
    public var activeOrder: Order? {
        orders.last { $0.status == .renting || $0.status == .returning || ($0.status == .pendingPayment && $0.paymentDeadline > now) }
    }

    public func beginRent(cabinet: String) { draft = RentDraft(cabinet: cabinet) }

    @discardableResult
    public func placeOrder(fitting: Fitting, plan: RentalPlan) -> Order {
        let cabinet = draft?.cabinet ?? DemoIDs.cabinet
        let o = Order(id: nextOrderID(), cabinet: cabinet, fitting: fitting, plan: plan, now: now)
        orders.append(o)
        draft = nil
        save()
        return o
    }

    private func nextOrderID() -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyMMddHHmm"
        return "XR" + f.string(from: now) + String(format: "%02d", orders.count % 100)
    }

    private func mutate(_ id: String, _ body: (inout Order) throws -> Void) throws {
        guard let i = orders.firstIndex(where: { $0.id == id }) else { throw OrderError.invalidState }
        var o = orders[i]
        try body(&o)
        orders[i] = o
        save()
    }

    public func pay(_ id: String) throws { try mutate(id) { try $0.pay(now: now) } }
    public func renew(_ id: String, plan: RentalPlan) throws { try mutate(id) { try $0.renew(plan, now: now) } }
    public func scheduleReturn(_ id: String, method: ReturnMethod) throws { try mutate(id) { try $0.scheduleReturn(method, now: now) } }
    public func advanceReturn(_ id: String) throws { try mutate(id) { try $0.advanceReturn(now: now) } }

    /// Closes unpaid orders whose 10-minute window has passed.
    public func refreshAll() {
        var changed = false
        for i in orders.indices where orders[i].refresh(now: now) { changed = true }
        if changed { save() }
    }

    // MARK: QR / deep links

    public func handle(_ route: QRRoute) -> DeepLinkOutcome {
        refreshAll()
        switch route {
        case let .rent(cabinet):
            let c = cabinet ?? DemoIDs.cabinet
            beginRent(cabinet: c)
            return .startRent(cabinet: c, needsLogin: !isLoggedIn)
        case let .activate(device):
            let d = device ?? DemoIDs.device
            guard let o = currentRental else { return .activationNeedsOrder }
            try? mutate(o.id) { try $0.activate(device: d, now: now) }
            return .activated(orderID: o.id, device: d)
        case let .renew(device):
            let d = device ?? DemoIDs.device
            // Prefer the order this device was activated on, else the current rental.
            if let o = orders.last(where: { $0.status == .renting && $0.deviceID == d }) ?? currentRental {
                return .openRenew(orderID: o.id)
            }
            return .renewNeedsOrder
        }
    }

    // MARK: demo tools

    public enum DemoJump: Sendable {
        case expiringIn2Days, overdue5Hours, pendingRemaining30s
    }

    /// Moves the demo clock; returns false when there is no order the jump applies to.
    @discardableResult
    public func demoJump(_ jump: DemoJump) -> Bool {
        switch jump {
        case .expiringIn2Days, .overdue5Hours:
            guard let end = currentRental?.endsAt else { return false }
            clock.jump(to: end.addingTimeInterval(jump == .expiringIn2Days ? -2 * 86_400 : 5 * 3600))
        case .pendingRemaining30s:
            guard let o = orders.last(where: { $0.status == .pendingPayment }) else { return false }
            clock.jump(to: o.paymentDeadline.addingTimeInterval(-30))
        }
        clockVersion += 1
        refreshAll()
        save()
        return true
    }

    public func resetClock() {
        clock.offset = 0
        clockVersion += 1
        refreshAll()
        save()
    }

    public func resetAll() {
        account = nil
        orders = []
        draft = nil
        clock.offset = 0
        clockVersion += 1
        save()
    }
}
