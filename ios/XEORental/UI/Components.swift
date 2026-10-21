import SwiftUI
import RentalKit

/// The XEO logo from the asset catalog (vector, from brand/logo_black.svg). Never redrawn or recoloured.
/// The SVG's artboard is square with the wordmark in the middle, so the frame is square and clipped to the mark.
struct LogoView: View {
    var height: CGFloat = 28
    var body: some View {
        Image("Logo")
            .resizable()
            .scaledToFill()
            .frame(width: height * 3.1, height: height)
            .clipped()
            .accessibilityLabel("XEO")
    }
}

struct ScreenTitle: View {
    let title: String
    var subtitle: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.xeoLargeTitle).foregroundStyle(Brand.ink)
            if let subtitle { Text(subtitle).font(.xeoBody).foregroundStyle(Brand.secondary) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// "步骤 2 / 5" plus a thin progress rule in brand purple.
struct StepHeader: View {
    let index: Int
    let total: Int
    let title: String
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 4) {
                ForEach(0..<total, id: \.self) { i in
                    Capsule().fill(i <= index ? Brand.purple : Brand.silver).frame(height: 4)
                }
            }
            Text("步骤 \(index + 1) / \(total)").font(.xeoCaption).foregroundStyle(Brand.caption)
            Text(title).font(.xeoTitle).foregroundStyle(Brand.ink)
        }
    }
}

struct StatusChip: View {
    let phase: RentalPhase
    var body: some View {
        Text(phase.title)
            .font(.system(size: 12, weight: .semibold))
            .padding(.horizontal, 10).padding(.vertical, 4)
            .foregroundStyle(foreground)
            .background(Capsule().fill(background))
    }
    private var foreground: Color {
        switch phase {
        case .overdue: return .white
        case .closed, .completed: return Brand.secondary
        default: return Brand.purple
        }
    }
    private var background: Color {
        switch phase {
        case .overdue: return Brand.warning
        case .closed, .completed: return Brand.softGray
        default: return Brand.purple.opacity(0.1)
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label).font(.xeoBody).foregroundStyle(Brand.secondary)
            Spacer(minLength: 16)
            Text(value).font(.xeoBody).foregroundStyle(Brand.ink).multilineTextAlignment(.trailing)
        }
    }
}

struct PriceTag: View {
    let yuan: Int
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(Pricing.format(yuan)).font(.system(size: 22, weight: .bold)).foregroundStyle(Brand.ink)
            Text(Pricing.label).font(.xeoCaption).foregroundStyle(Brand.caption)
        }
    }
}

/// Vertical list of timeline events, newest last.
struct TimelineList: View {
    let events: [TimelineEvent]
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(Array(events.enumerated()), id: \.offset) { i, e in
                HStack(alignment: .top, spacing: 12) {
                    Circle().fill(i == events.count - 1 ? Brand.purple : Brand.silver).frame(width: 10, height: 10).padding(.top, 5)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(e.title).font(.xeoBody).foregroundStyle(i == events.count - 1 ? Brand.ink : Brand.secondary)
                        Text(Formatters.dateTime.string(from: e.at)).font(.xeoCaption).foregroundStyle(Brand.caption)
                    }
                }
            }
        }
    }
}

enum Formatters {
    static let dateTime: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M月d日 HH:mm"
        return f
    }()
}

/// Banner for orders that need attention (expiring soon / overdue / unpaid).
struct AttentionBanner: View {
    let order: Order
    let phase: RentalPhase
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 20, weight: .semibold)).foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.xeoHeadline).foregroundStyle(Brand.ink)
                Text(detail).font(.xeoCaption).foregroundStyle(Brand.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(Brand.caption)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: Brand.corner).fill(tint.opacity(0.08)))
        .overlay(RoundedRectangle(cornerRadius: Brand.corner).stroke(tint.opacity(0.5), lineWidth: 1))
    }
    private var tint: Color { if case .overdue = phase { return Brand.warning } else { return Brand.purple } }
    private var icon: String {
        switch phase {
        case .overdue: return "exclamationmark.triangle"
        case .pendingPayment: return "creditcard"
        default: return "clock"
        }
    }
    private var title: String {
        switch phase {
        case .overdue: return "租期已逾期"
        case .expiringSoon: return "租期即将到期"
        case .pendingPayment: return "订单待支付"
        default: return phase.title
        }
    }
    private var detail: String {
        switch phase {
        case let .overdue(by): return "已逾期 \(DurationText.format(by)) · 点此续租或归还"
        case let .expiringSoon(left): return "还剩 \(DurationText.format(left)) · 点此续租或归还"
        case let .pendingPayment(left): return "剩余 \(DurationText.format(left, clock: true)) 自动关闭 · 点此继续支付"
        default: return order.id
        }
    }
}
