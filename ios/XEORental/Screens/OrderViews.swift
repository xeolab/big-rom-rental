import SwiftUI
import RentalKit

struct OrdersView: View {
    @EnvironmentObject private var store: RentalStore
    @EnvironmentObject private var model: AppModel

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if store.orders.isEmpty {
                        Text("还没有订单。扫描柜机二维码开始第一次租赁。")
                            .font(.xeoBody).foregroundStyle(Brand.secondary).padding(.top, 40)
                    }
                    ForEach(store.orders.reversed()) { o in
                        Button { open(o) } label: { row(o) }.buttonStyle(.plain)
                    }
                }
                .padding(Brand.gutter)
            }
            .background(Brand.paper)
        }
        .navigationTitle("我的订单")
        .xeoInlineTitle()
        .onAppear { store.refreshAll() }
    }

    private func open(_ o: Order) {
        if case .pendingPayment = o.phase(at: store.now) { model.path.append(.pendingPayment(o.id)) } else { model.path.append(.order(o.id)) }
    }

    private func row(_ o: Order) -> some View {
        let phase = o.phase(at: store.now)
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("XEO BIG + Rom · \(o.plan.title)").font(.xeoHeadline).foregroundStyle(Brand.ink)
                Spacer()
                StatusChip(phase: phase)
            }
            Text("订单号 \(o.id) · \(Formatters.dateTime.string(from: o.createdAt))").font(.xeoCaption).foregroundStyle(Brand.caption)
            switch phase {
            case let .pendingPayment(left):
                Text("剩余 \(DurationText.format(left, clock: true)) 自动关闭 · 点击继续支付").font(.xeoBody).foregroundStyle(Brand.purple)
            case .closed:
                Text("超时未支付，订单已关闭").font(.xeoBody).foregroundStyle(Brand.secondary)
            case let .overdue(by):
                Text("已逾期 \(DurationText.format(by))").font(.xeoBody).foregroundStyle(Brand.warning)
            case let .expiringSoon(left), let .renting(left):
                Text("剩余 \(DurationText.format(left))").font(.xeoBody).foregroundStyle(Brand.secondary)
            case let .returning(stage):
                Text(o.returnMethod.map { stage.title(for: $0) } ?? "归还中").font(.xeoBody).foregroundStyle(Brand.secondary)
            case .completed:
                Text("已完成 · 实付 \(Pricing.format(o.amountPaid))").font(.xeoBody).foregroundStyle(Brand.secondary)
            }
        }
        .xeoCard()
    }
}

struct OrderDetailView: View {
    let orderID: String
    @EnvironmentObject private var store: RentalStore
    @EnvironmentObject private var model: AppModel

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            if let o = store.order(orderID) { detail(o) } else { Text("订单不存在").foregroundStyle(Brand.caption) }
        }
        .background(Brand.paper)
        .navigationTitle("订单详情")
        .xeoInlineTitle()
    }

    private func detail(_ o: Order) -> some View {
        let phase = o.phase(at: store.now)
        return ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if model.justPaidOrderID == o.id {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill").font(.system(size: 28)).foregroundStyle(Brand.purple)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("支付成功").font(.xeoHeadline).foregroundStyle(Brand.ink)
                            Text("请到柜机领取设备；开机后按 Rom 上的提示激活。").font(.xeoCaption).foregroundStyle(Brand.secondary)
                        }
                    }
                    .xeoCard(selected: true)
                }
                header(o, phase)
                if phase.needsAttention, o.status == .renting {
                    Button { model.path.append(.renew(o.id)) } label: { AttentionBanner(order: o, phase: phase) }.buttonStyle(.plain)
                }
                actions(o, phase)
                if let m = o.returnMethod {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("归还方式").font(.xeoHeadline).foregroundStyle(Brand.ink)
                        InfoRow(label: m.title, value: m.detail)
                    }
                    .xeoCard()
                }
                VStack(alignment: .leading, spacing: 12) {
                    Text("配件组合").font(.xeoHeadline).foregroundStyle(Brand.ink)
                    InfoRow(label: "面罩", value: o.fitting.mask.title)
                    InfoRow(label: "绑带", value: o.fitting.strapSummary)
                    InfoRow(label: "镜片", value: o.fitting.lensSummary)
                    InfoRow(label: "耳机", value: o.fitting.earphone.title)
                }
                .xeoCard()
                VStack(alignment: .leading, spacing: 14) {
                    Text("订单进度").font(.xeoHeadline).foregroundStyle(Brand.ink)
                    TimelineList(events: o.timeline)
                }
                .xeoCard()
                Text("订单号 \(o.id) · 柜机 \(o.cabinet)").font(.xeoCaption).foregroundStyle(Brand.caption)
            }
            .padding(Brand.gutter)
        }
        .onDisappear { if model.justPaidOrderID == o.id { model.justPaidOrderID = nil } }
    }

    private func header(_ o: Order, _ phase: RentalPhase) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("XEO BIG + Rom").font(.xeoTitle).foregroundStyle(Brand.ink)
                Spacer()
                StatusChip(phase: phase)
            }
            if let s = o.startsAt { InfoRow(label: "租期开始", value: Formatters.dateTime.string(from: s)) }
            if let e = o.endsAt { InfoRow(label: "到期时间", value: Formatters.dateTime.string(from: e)) }
            InfoRow(label: "设备", value: o.activatedAt != nil ? "\(o.deviceID ?? "") · 已激活" : "待激活（Rom 开机后扫码）")
            InfoRow(label: "实付", value: Pricing.format(o.amountPaid) + (o.renewals.isEmpty ? "" : "（含续租 \(o.renewals.count) 次）"))
        }
        .xeoCard()
    }

    @ViewBuilder
    private func actions(_ o: Order, _ phase: RentalPhase) -> some View {
        switch o.status {
        case .renting:
            HStack(spacing: 12) {
                Button("续租") { model.path.append(.renew(o.id)) }.buttonStyle(PrimaryButtonStyle())
                Button("归还") { model.path.append(.returnFlow(o.id)) }.buttonStyle(SecondaryButtonStyle())
            }
        case .returning:
            if let next = o.nextReturnStageTitle {
                VStack(alignment: .leading, spacing: 8) {
                    Button { advance(o) } label: { Label("演示：推进到「\(next)」", systemImage: "forward.end") }
                        .buttonStyle(SecondaryButtonStyle())
                    Text("演示按钮：模拟快递、柜机与工作人员核验的进度。").font(.xeoCaption).foregroundStyle(Brand.caption)
                }
            }
        case .pendingPayment:
            Button("去支付") { model.path.append(.pendingPayment(o.id)) }.buttonStyle(PrimaryButtonStyle())
        case .completed:
            HStack(spacing: 10) {
                Image(systemName: "checkmark.seal").foregroundStyle(Brand.purple)
                Text("核验无误，订单已完成。感谢使用 XEO。").font(.xeoBody).foregroundStyle(Brand.ink)
            }
        case .closed:
            EmptyView()
        }
    }

    private func advance(_ o: Order) {
        do {
            try store.advanceReturn(o.id)
            if store.order(o.id)?.status == .completed { model.notifications.cancelReminders(for: o.id) }
        } catch { model.show(error, title: "无法推进") }
    }
}
