import Foundation

/// Stored order status. 「即将到期 / 已逾期」 are NOT stored — they are derived from the clock (see `phase(at:)`).
public enum OrderStatus: String, Codable, Sendable {
    case pendingPayment, renting, returning, completed, closed
}

public enum ReturnMethod: Codable, Equatable, Sendable {
    case courier(address: String, slot: String)
    case cabinet(cinemaID: String)

    public var title: String {
        switch self {
        case .courier: return "上门取件"
        case .cabinet: return "影院柜机归还"
        }
    }

    public var detail: String {
        switch self {
        case let .courier(address, slot): return "\(address) · \(slot)"
        case let .cabinet(id): return ReturnCatalog.cinema(id)?.name ?? id
        }
    }

    /// courier: scheduled → inTransit → verifying → completed; cabinet: scheduled → verifying → completed.
    public var stages: [ReturnStage] {
        switch self {
        case .courier: return [.scheduled, .inTransit, .verifying, .completed]
        case .cabinet: return [.scheduled, .verifying, .completed]
        }
    }
}

public enum ReturnStage: String, Codable, Sendable {
    case scheduled, inTransit, verifying, completed

    public func title(for method: ReturnMethod) -> String {
        switch (self, method) {
        case (.scheduled, .courier): return "已预约上门取件"
        case (.scheduled, .cabinet): return "待交还至柜机"
        case (.inTransit, _): return "快递运输中"
        case (.verifying, .courier): return "已签收，设备核验中"
        case (.verifying, .cabinet): return "已交还，待核验"
        case (.completed, _): return "核验无误，订单完成"
        }
    }
}

public struct TimelineEvent: Codable, Equatable, Sendable {
    public let at: Date
    public let title: String
}

public struct Renewal: Codable, Equatable, Sendable {
    public let at: Date
    public let plan: RentalPlan
    public let amount: Int
}

/// What the UI should show for an order at a given moment.
public enum RentalPhase: Equatable, Sendable {
    case pendingPayment(remaining: TimeInterval)
    case closed
    case renting(remaining: TimeInterval)
    case expiringSoon(remaining: TimeInterval)
    case overdue(by: TimeInterval)
    case returning(ReturnStage)
    case completed

    public var title: String {
        switch self {
        case .pendingPayment: return "待支付"
        case .closed: return "已关闭"
        case .renting: return "租赁中"
        case .expiringSoon: return "即将到期"
        case .overdue: return "已逾期"
        case .returning: return "归还中"
        case .completed: return "已完成"
        }
    }

    public var needsAttention: Bool {
        switch self {
        case .expiringSoon, .overdue, .pendingPayment: return true
        default: return false
        }
    }
}

public enum OrderError: Error, Equatable, Sendable {
    case paymentExpired, invalidState

    public var message: String {
        switch self {
        case .paymentExpired: return "支付已超时，订单已关闭"
        case .invalidState: return "当前订单状态不支持该操作"
        }
    }
}

public struct Order: Codable, Identifiable, Equatable, Sendable {
    public static let paymentWindow: TimeInterval = 10 * 60          // owner's decision: 10 minutes
    public static let expiringThreshold: TimeInterval = 1 * 86_400   // 「即将到期」= ≤ 1 day left (owner, 2026-10-21)

    public let id: String
    public let cabinet: String
    public let createdAt: Date
    public let paymentDeadline: Date
    public let plan: RentalPlan
    public let fitting: Fitting
    public private(set) var status: OrderStatus
    public private(set) var amountPaid: Int
    public private(set) var startsAt: Date?
    public private(set) var endsAt: Date?
    public private(set) var renewals: [Renewal]
    public private(set) var deviceID: String?
    public private(set) var activatedAt: Date?
    public private(set) var returnMethod: ReturnMethod?
    public private(set) var returnStage: ReturnStage?
    public private(set) var timeline: [TimelineEvent]

    public init(id: String, cabinet: String, fitting: Fitting, plan: RentalPlan, now: Date) {
        self.id = id
        self.cabinet = cabinet
        self.createdAt = now
        self.paymentDeadline = now.addingTimeInterval(Self.paymentWindow)
        self.plan = plan
        self.fitting = fitting
        self.status = .pendingPayment
        self.amountPaid = 0
        self.renewals = []
        self.timeline = [TimelineEvent(at: now, title: "订单已创建，待支付")]
    }

    /// Amount due for the initial payment.
    public var amountDue: Int { plan.price }

    // MARK: derived state

    public func phase(at now: Date) -> RentalPhase {
        switch status {
        case .pendingPayment:
            let left = paymentDeadline.timeIntervalSince(now)
            return left > 0 ? .pendingPayment(remaining: left) : .closed
        case .closed: return .closed
        case .completed: return .completed
        case .returning: return .returning(returnStage ?? .scheduled)
        case .renting:
            let left = (endsAt ?? now).timeIntervalSince(now)
            if left < 0 { return .overdue(by: -left) }
            return left <= Self.expiringThreshold ? .expiringSoon(remaining: left) : .renting(remaining: left)
        }
    }

    /// Persist the timeout of an unpaid order. Returns true if something changed.
    @discardableResult
    public mutating func refresh(now: Date) -> Bool {
        guard status == .pendingPayment, now >= paymentDeadline else { return false }
        status = .closed
        timeline.append(TimelineEvent(at: paymentDeadline, title: "支付超时，订单已关闭"))
        return true
    }

    // MARK: transitions

    /// Fake payment confirmed (「二次确认」→ 确定). The rental clock starts now
    /// (the original plan starts it at cabinet pickup, which is out of scope for this demo).
    public mutating func pay(now: Date) throws {
        refresh(now: now)
        if status == .closed { throw OrderError.paymentExpired }
        guard status == .pendingPayment else { throw OrderError.invalidState }
        status = .renting
        amountPaid = amountDue
        startsAt = now
        endsAt = now.addingTimeInterval(plan.duration)
        timeline.append(TimelineEvent(at: now, title: "支付成功 \(Pricing.format(amountDue))，租期开始"))
    }

    /// Extends from the current end date, so an overdue period is covered by the renewal.
    public mutating func renew(_ extra: RentalPlan, now: Date) throws {
        guard status == .renting, let end = endsAt else { throw OrderError.invalidState }
        endsAt = end.addingTimeInterval(extra.duration)
        amountPaid += extra.price
        renewals.append(Renewal(at: now, plan: extra, amount: extra.price))
        timeline.append(TimelineEvent(at: now, title: "续租 \(extra.title)，支付 \(Pricing.format(extra.price))"))
    }

    public mutating func activate(device: String, now: Date) throws {
        guard status == .renting else { throw OrderError.invalidState }
        if deviceID == device, activatedAt != nil { return }
        deviceID = device
        activatedAt = now
        timeline.append(TimelineEvent(at: now, title: "Rom 已激活（\(device)）"))
    }

    public mutating func scheduleReturn(_ method: ReturnMethod, now: Date) throws {
        guard status == .renting else { throw OrderError.invalidState }
        status = .returning
        returnMethod = method
        returnStage = .scheduled
        timeline.append(TimelineEvent(at: now, title: "\(method.title)：\(ReturnStage.scheduled.title(for: method))"))
    }

    /// Demo button: move the return to its next stage.
    public mutating func advanceReturn(now: Date) throws {
        guard status == .returning, let method = returnMethod, let stage = returnStage,
              let i = method.stages.firstIndex(of: stage), i + 1 < method.stages.count else { throw OrderError.invalidState }
        let next = method.stages[i + 1]
        returnStage = next
        if next == .completed { status = .completed }
        timeline.append(TimelineEvent(at: now, title: next.title(for: method)))
    }

    /// Next return stage label for the demo button, nil when there is none.
    public var nextReturnStageTitle: String? {
        guard status == .returning, let m = returnMethod, let s = returnStage,
              let i = m.stages.firstIndex(of: s), i + 1 < m.stages.count else { return nil }
        return m.stages[i + 1].title(for: m)
    }
}

public enum DurationText {
    /// "2 天 3 小时" / "5 小时 12 分" / "09:41" (mm:ss under an hour when `clock` is true).
    public static func format(_ t: TimeInterval, clock: Bool = false) -> String {
        let s = max(0, Int(t.rounded(.down)))
        if clock && s < 3600 { return String(format: "%02d:%02d", s / 60, s % 60) }
        let d = s / 86_400, h = (s % 86_400) / 3600, m = (s % 3600) / 60
        if d > 0 { return "\(d) 天 \(h) 小时" }
        if h > 0 { return "\(h) 小时 \(m) 分" }
        return "\(max(m, s > 0 ? 1 : 0)) 分钟"
    }
}
