import Foundation

public enum MaskSize: String, Codable, CaseIterable, Identifiable, Sendable {
    case s = "S", m = "M", l = "L"
    public var id: String { rawValue }
    public var title: String { "\(rawValue) 码" }

    /// Recommendation from head circumference (cm).
    public static func recommended(forHeadCircumference cm: Int) -> MaskSize {
        cm < 55 ? .s : (cm < 59 ? .m : .l)
    }
}

public enum EarphoneChoice: String, Codable, CaseIterable, Identifiable, Sendable {
    case own, rent
    public var id: String { rawValue }
    public var title: String { self == .own ? "使用自己的耳机" : "租用耳机" }
}

/// The accessory combination confirmed in the fitting flow.
public struct Fitting: Codable, Equatable, Sendable {
    public var mask: MaskSize
    public var headCircumferenceCm: Int
    /// true = from the face measurement, false = typed in by the user.
    public var headMeasured: Bool
    public var leftDiopter: Int
    public var rightDiopter: Int
    public var earphone: EarphoneChoice

    public init(mask: MaskSize, headCircumferenceCm: Int, headMeasured: Bool, leftDiopter: Int, rightDiopter: Int, earphone: EarphoneChoice) {
        self.mask = mask
        self.headCircumferenceCm = headCircumferenceCm
        self.headMeasured = headMeasured
        self.leftDiopter = leftDiopter
        self.rightDiopter = rightDiopter
        self.earphone = earphone
    }

    public var lensSummary: String { "左 \(leftDiopter) 度 · 右 \(rightDiopter) 度" }
    public var strapSummary: String { "头围 \(headCircumferenceCm) cm" + (headMeasured ? "（测量）" : "（手填）") }
}

// MARK: - Diopter input (近视度数): non-negative whole numbers only

public enum DiopterError: Error, Equatable, Sendable {
    case empty, negative, decimal, notNumber, tooLarge

    public var message: String {
        switch self {
        case .empty: return "请填写度数，没有近视填 0"
        case .negative: return "度数不能为负数（不支持远视）"
        case .decimal: return "度数请填整数，例如 350"
        case .notNumber: return "只能填写数字"
        case .tooLarge: return "超出可选范围（0–\(DiopterRule.max) 度）"
        }
    }
}

public enum DiopterRule {
    public static let max = 1200

    public static func validate(_ text: String) -> Result<Int, DiopterError> {
        let s = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.isEmpty { return .failure(.empty) }
        if s.hasPrefix("-") || s.hasPrefix("−") { return .failure(.negative) }
        if s.contains(".") || s.contains("。") || s.contains(",") { return .failure(.decimal) }
        guard s.allSatisfy({ $0.isASCII && $0.isNumber }), let v = Int(s) else { return .failure(.notNumber) }
        if v > max { return .failure(.tooLarge) }
        return .success(v)
    }

    /// Live input filter: keeps ASCII digits only, at most 4 of them, no leading zeros ("0350" → "350").
    public static func sanitize(_ text: String) -> String {
        let digits = String(text.filter { $0.isASCII && $0.isNumber }.prefix(4))
        guard let v = Int(digits) else { return digits }
        return String(v)
    }
}

// MARK: - Head circumference estimate from a face scan

/// Estimates head circumference from face-mesh width samples (meters, e.g. the X extent of ARFaceGeometry).
///
/// Model: head breadth ≈ face-mesh width × breadthFactor; head length = breadth / cephalicIndex;
/// circumference = Ramanujan ellipse perimeter of (length, breadth) + soft-tissue/hair allowance.
/// The constants are anthropometric averages — **待真机校准** with a tape measure on a few people.
public struct HeadEstimator: Sendable {
    public static let breadthFactor = 1.10
    public static let cephalicIndex = 0.79
    public static let allowanceCm = 1.5
    public static let range = 48...66
    public static let samplesNeeded = 30

    public private(set) var samples: [Double] = []

    public init() {}

    /// Adds one face-width sample in meters; implausible values (< 9 cm or > 22 cm) are ignored.
    public mutating func add(faceWidthMeters w: Double) {
        guard w > 0.09, w < 0.22 else { return }
        samples.append(w)
    }

    public var progress: Double { min(1, Double(samples.count) / Double(Self.samplesNeeded)) }
    public var isReady: Bool { samples.count >= Self.samplesNeeded }

    /// Median-filtered estimate in whole centimeters, nil until enough samples.
    public var estimateCm: Int? {
        guard isReady else { return nil }
        let sorted = samples.sorted()
        return Self.circumferenceCm(faceWidthMeters: sorted[sorted.count / 2])
    }

    public static func circumferenceCm(faceWidthMeters w: Double) -> Int {
        let breadth = w * 100 * breadthFactor
        let length = breadth / cephalicIndex
        let a = length / 2, b = breadth / 2
        let perimeter = Double.pi * (3 * (a + b) - ((3 * a + b) * (a + 3 * b)).squareRoot())
        let cm = Int((perimeter + allowanceCm).rounded())
        return min(range.upperBound, max(range.lowerBound, cm))
    }
}
