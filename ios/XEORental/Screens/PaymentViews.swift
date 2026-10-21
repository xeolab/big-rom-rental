import SwiftUI
import RentalKit

/// 租期选择: 1 / 3 / 7 天, illustrative prices.
struct PlanView: View {
    @EnvironmentObject private var model: AppModel
    @State private var plan: RentalPlan = .threeDays

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ScreenTitle(title: "选择租期", subtitle: "租期从支付成功开始计算，到期前会提醒你续租或归还。")
                    ForEach(RentalPlan.allCases) { p in
                        Button { plan = p } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(p.title).font(.xeoTitle).foregroundStyle(Brand.ink)
                                    Text(String(format: "约 ¥%.0f / 天", Double(p.price) / Double(p.days))).font(.xeoCaption).foregroundStyle(Brand.secondary)
                                }
                                Spacer()
                                PriceTag(yuan: p.price)
                            }
                            .xeoCard(selected: plan == p)
                        }
                        .buttonStyle(.plain)
                    }
                    Text("价格为示意价，仅用于演示。").font(.xeoCaption).foregroundStyle(Brand.caption)
                }
                .padding(Brand.gutter)
            }
            Button("下一步，确认订单") { model.path.append(.confirm(plan)) }
                .buttonStyle(PrimaryButtonStyle())
                .padding(Brand.gutter)
        }
        .background(Brand.paper)
        .navigationTitle("租期")
        .xeoInlineTitle()
    }
}

/// Fake two-step payment shared by first payment, pending orders and renewals:
/// 「立即支付」→ confirmation dialog → 确定 / 取消.
struct PayConfirmModifier: ViewModifier {
    @Binding var isPresented: Bool
    let amount: Int
    let onConfirm: () -> Void
    let onCancel: () -> Void

    func body(content: Content) -> some View {
        content.alert("确认支付 \(Pricing.format(amount))？", isPresented: $isPresented) {
            Button("取消", role: .cancel) { onCancel() }
            Button("确定") { onConfirm() }
        } message: {
            Text("演示环境：不会真的扣款。")
        }
    }
}

extension View {
    func payConfirm(isPresented: Binding<Bool>, amount: Int, onConfirm: @escaping () -> Void, onCancel: @escaping () -> Void) -> some View {
        modifier(PayConfirmModifier(isPresented: isPresented, amount: amount, onConfirm: onConfirm, onCancel: onCancel))
    }
}

/// 确认订单 → 立即支付. The order is created (待支付, 10-minute window) when 「立即支付」 is tapped.
struct ConfirmOrderView: View {
    let plan: RentalPlan
    @EnvironmentObject private var store: RentalStore
    @EnvironmentObject private var model: AppModel
    @State private var orderID: String?
    @State private var asking = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ScreenTitle(title: "确认订单")
                    VStack(alignment: .leading, spacing: 12) {
                        Text("XEO BIG + Rom").font(.xeoHeadline).foregroundStyle(Brand.ink)
                        InfoRow(label: "取货柜机", value: store.draft?.cabinet ?? DemoIDs.cabinet)
                        InfoRow(label: "租期", value: plan.title)
                    }
                    .xeoCard()
                    if let f = store.draft?.fitting {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("配件组合").font(.xeoHeadline).foregroundStyle(Brand.ink)
                            InfoRow(label: "面罩", value: f.mask.title)
                            InfoRow(label: "绑带", value: f.strapSummary)
                            InfoRow(label: "镜片", value: f.lensSummary)
                            InfoRow(label: "耳机", value: f.earphone.title)
                        }
                        .xeoCard()
                    }
                    HStack {
                        Text("合计").font(.xeoHeadline).foregroundStyle(Brand.ink)
                        Spacer()
                        PriceTag(yuan: plan.price)
                    }
                    Text("提交后请在 10 分钟内完成支付，超时订单将自动关闭。").font(.xeoCaption).foregroundStyle(Brand.caption)
                }
                .padding(Brand.gutter)
            }
            Button("立即支付 \(Pricing.format(plan.price))") {
                if orderID == nil, let f = store.draft?.fitting { orderID = store.placeOrder(fitting: f, plan: plan).id }
                if orderID != nil { asking = true }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(store.draft?.fitting == nil && orderID == nil)
            .padding(Brand.gutter)
        }
        .background(Brand.paper)
        .navigationTitle("确认订单")
        .xeoInlineTitle()
        .payConfirm(isPresented: $asking, amount: plan.price,
                    onConfirm: { if let id = orderID { model.confirmPayment(orderID: id) } },
                    onCancel: { if let id = orderID { model.cancelPayment(orderID: id) } })
    }
}

/// 待支付: 10-minute countdown; pay again or let it close.
struct PendingPaymentView: View {
    let orderID: String
    @EnvironmentObject private var store: RentalStore
    @EnvironmentObject private var model: AppModel
    @State private var asking = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            content
        }
        .background(Brand.paper)
        .navigationTitle("待支付")
        .xeoInlineTitle()
    }

    @ViewBuilder private var content: some View {
        if let o = store.order(orderID) {
            let phase = o.phase(at: store.now)
            VStack(spacing: 24) {
                Spacer().frame(height: 12)
                if case let .pendingPayment(left) = phase {
                    Text("订单待支付").font(.xeoTitle).foregroundStyle(Brand.ink)
                    Text(DurationText.format(left, clock: true))
                        .font(.system(size: 64, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Brand.purple)
                    Text("剩余支付时间，超时订单将自动关闭").font(.xeoBody).foregroundStyle(Brand.secondary)
                    PriceTag(yuan: o.amountDue)
                    Spacer()
                    Button("继续支付") { asking = true }.buttonStyle(PrimaryButtonStyle())
                    Button("返回首页，稍后支付") { model.path = [] }.buttonStyle(SecondaryButtonStyle())
                    Text("稍后可在「我的订单」里找到这笔订单继续支付。").font(.xeoCaption).foregroundStyle(Brand.caption)
                } else if phase == .closed {
                    Image(systemName: "xmark.circle").font(.system(size: 56)).foregroundStyle(Brand.caption)
                    Text("订单已关闭").font(.xeoTitle).foregroundStyle(Brand.ink)
                    Text("超过 10 分钟未支付，订单已自动关闭。").font(.xeoBody).foregroundStyle(Brand.secondary)
                    Spacer()
                    Button("返回首页") { model.path = [] }.buttonStyle(PrimaryButtonStyle())
                } else {
                    Text("订单已支付").font(.xeoTitle).foregroundStyle(Brand.ink)
                    Spacer()
                    Button("查看订单") { model.path = [.order(orderID)] }.buttonStyle(PrimaryButtonStyle())
                }
            }
            .padding(Brand.gutter)
            .onAppear { store.refreshAll() }
            .payConfirm(isPresented: $asking, amount: o.amountDue,
                        onConfirm: { model.confirmPayment(orderID: orderID) },
                        onCancel: {})
        } else {
            Text("订单不存在").foregroundStyle(Brand.caption)
        }
    }
}
