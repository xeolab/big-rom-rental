import Foundation

/// Rental lengths and illustrative prices (docs/tech/01 §4). Change prices here only.
public enum RentalPlan: Int, Codable, CaseIterable, Identifiable, Sendable {
    case oneDay = 1
    case threeDays = 3
    case sevenDays = 7

    public var id: Int { rawValue }
    public var days: Int { rawValue }
    public var title: String { "\(days) 天" }
    public var duration: TimeInterval { TimeInterval(days) * 86_400 }
    /// Yuan. Illustrative only — every price label in the UI says 「示意价」.
    public var price: Int { Pricing.prices[self] ?? 0 }
}

public enum Pricing {
    public static let isIllustrative = true
    public static let label = "示意价"
    public static let prices: [RentalPlan: Int] = [.oneDay: 99, .threeDays: 249, .sevenDays: 449]
    public static func format(_ yuan: Int) -> String { "¥\(yuan)" }
}

/// Demo identifiers shared with the e-ink demo (docs/tech/01 §4).
public enum DemoIDs {
    public static let cabinet = "XEO-IMAX-DEMO-01"
    public static let device = "ROM-DEMO-0001"
}

public struct Cinema: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let address: String
    public let distance: String
    public let freeSlots: Int
    public var isAvailable: Bool { freeSlots > 0 }
}

public enum ReturnCatalog {
    /// Three illustrative cinemas; one is full so the "unavailable" state is visible in the demo.
    public static let cinemas: [Cinema] = [
        Cinema(id: "C01", name: "XEO IMAX 影城（静安店）", address: "南京西路 1266 号 5F", distance: "1.2 km", freeSlots: 6),
        Cinema(id: "C02", name: "XEO IMAX 影城（徐汇店）", address: "漕溪北路 88 号 B1", distance: "4.8 km", freeSlots: 2),
        Cinema(id: "C03", name: "XEO IMAX 影城（浦东店）", address: "世纪大道 8 号 L4", distance: "9.5 km", freeSlots: 0),
    ]

    public static let courierSlots: [String] = ["今天 14:00–18:00", "明天 09:00–12:00", "明天 14:00–18:00"]

    public static func cinema(_ id: String) -> Cinema? { cinemas.first { $0.id == id } }
}
