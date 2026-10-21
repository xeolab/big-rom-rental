import Foundation

/// Every time-dependent rule reads "now" from a clock, so the demo tools can fast-forward
/// (e.g. jump to "2 days left") without touching the device time.
public protocol RentalClock: AnyObject {
    var now: Date { get }
}

/// Wall clock plus a persisted offset. `offset` is what the demo tools change.
public final class DemoClock: RentalClock {
    public var offset: TimeInterval
    private let base: () -> Date

    public init(offset: TimeInterval = 0, base: @escaping () -> Date = Date.init) {
        self.offset = offset
        self.base = base
    }

    public var now: Date { base().addingTimeInterval(offset) }

    /// Shift the clock so that `now` becomes `target`.
    public func jump(to target: Date) { offset += target.timeIntervalSince(now) }
}
