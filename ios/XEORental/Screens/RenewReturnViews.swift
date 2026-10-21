import SwiftUI
import RentalKit

/// 续租 (also the target of `xeorental://renew` and the reminder notification). Links to 归还 for users who stop here.
struct RenewView: View {
    let orderID: String
    @EnvironmentObject private var store: RentalStore
    @EnvironmentObject private var model: AppModel
    @State private var plan: RentalPlan = .oneDay
    @State private var asking = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            if let o = store.order(orderID) { content(o) } else { Text("订单不存在").foregroundStyle(Brand.caption) }
        }
        .background(Brand.paper)
        .navigationTitle("续租")
        .xeoInlineTitle()
    }

    @ViewBuilder
    private func content(_ o: Order) -> some View {
        if o.status != .renting {
            VStack(spacing: 16) {
                Text("这笔订单当前不能续租（\(o.phase(at: store.now).title)）。").font(.xeoBody).foregroundStyle(Brand.secondary)
                Button("查看订单") { model.path = [.order(orderID)] }.buttonStyle(PrimaryButtonStyle())
            }
            .padding(Brand.gutter)
        } else {
            let phase = o.phase(at: store.now)
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        ScreenTitle(title: "续租", subtitle: "续租后到期时间顺延，Rom 会同步更新，无需重新激活。")
                        VStack(alignment: .leading, spacing: 10) {
                            InfoRow(label: "当前到期", value: o.endsAt.map(Formatters.dateTime.string(from:)) ?? "—")
                            if case let .overdue(by) = phase {
                                InfoRow(label: "已逾期", value: DurationText.format(by))
                                Text("续租时长从原到期时间起算，逾期部分一并覆盖。").font(.xeoCaption).foregroundStyle(Brand.warning)
                            } else if case let .expiringSoon(left) = phase {
                                InfoRow(label: "剩余", value: DurationText.format(left))
                            }
                        }
                        .xeoCard()
                        ForEach(RentalPlan.allCases) { p in
                            Button { plan = p } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("续租 \(p.title)").font(.xeoHeadline).foregroundStyle(Brand.ink)
                                        if let end = o.endsAt {
                                            Text("新的到期：\(Formatters.dateTime.string(from: end.addingTimeInterval(p.duration)))").font(.xeoCaption).foregroundStyle(Brand.secondary)
                                        }
                                    }
                                    Spacer()
                                    PriceTag(yuan: p.price)
                                }
                                .xeoCard(selected: plan == p)
                            }
                            .buttonStyle(.plain)
                        }
                        Button("不续租了？选择归还方式") { model.path.append(.returnFlow(orderID)) }
                            .font(.xeoHeadline).foregroundStyle(Brand.purple)
                    }
                    .padding(Brand.gutter)
                }
                Button("支付 \(Pricing.format(plan.price))，确认续租") { asking = true }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(Brand.gutter)
            }
            .payConfirm(isPresented: $asking, amount: plan.price, onConfirm: confirm, onCancel: {})
        }
    }

    private func confirm() {
        do {
            try store.renew(orderID, plan: plan)
            if let o = store.order(orderID) { model.notifications.scheduleReminders(for: o) }
            model.alert = AppAlert(title: "续租成功", message: "到期时间已顺延 \(plan.title)，Rom 会同步更新。")
            model.path = [.order(orderID)]
        } catch { model.show(error, title: "续租未完成") }
    }
}

/// 归还方式: 上门取件 or 影院柜机.
struct ReturnView: View {
    let orderID: String
    @EnvironmentObject private var store: RentalStore
    @EnvironmentObject private var model: AppModel

    enum Kind: String, CaseIterable, Identifiable { case courier = "上门取件", cabinet = "影院柜机归还"; var id: String { rawValue } }
    @State private var kind: Kind = .cabinet
    @State private var address = ""
    @State private var slot = ReturnCatalog.courierSlots[0]
    @State private var cinemaID: String?

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ScreenTitle(title: "选择归还方式", subtitle: "请把 BIG、Rom 和全部配件放回收纳包。")
                    Picker("归还方式", selection: $kind) {
                        ForEach(Kind.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    if kind == .courier { courier } else { cabinet }
                }
                .padding(Brand.gutter)
            }
            Button(kind == .courier ? "预约上门取件" : "确认去这家影院归还") { submit() }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!canSubmit)
                .padding(Brand.gutter)
        }
        .background(Brand.paper)
        .navigationTitle("归还")
        .xeoInlineTitle()
    }

    private var courier: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("取件地址").font(.xeoHeadline).foregroundStyle(Brand.ink)
            TextField("省市区、街道、门牌号", text: $address, axis: .vertical)
                .font(.xeoBody)
                .lineLimit(2...4)
                .xeoCard()
            Text("上门时间").font(.xeoHeadline).foregroundStyle(Brand.ink)
            ForEach(ReturnCatalog.courierSlots, id: \.self) { s in
                Button { slot = s } label: {
                    Text(s).font(.xeoBody).foregroundStyle(Brand.ink).xeoCard(selected: slot == s)
                }
                .buttonStyle(.plain)
            }
            Text("快递员上门取件后，设备送达并核验无误即完成订单。").font(.xeoCaption).foregroundStyle(Brand.caption)
        }
    }

    private var cabinet: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("支持跨影院异地归还").font(.xeoBody).foregroundStyle(Brand.secondary)
            ForEach(ReturnCatalog.cinemas) { c in
                Button { if c.isAvailable { cinemaID = c.id } } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(c.name).font(.xeoHeadline).foregroundStyle(c.isAvailable ? Brand.ink : Brand.caption)
                            Spacer()
                            Text(c.distance).font(.xeoCaption).foregroundStyle(Brand.caption)
                        }
                        Text(c.address).font(.xeoCaption).foregroundStyle(Brand.secondary)
                        Text(c.isAvailable ? "柜机可用 · 空闲格口 \(c.freeSlots)" : "柜机已满，暂不可归还")
                            .font(.xeoCaption).foregroundStyle(c.isAvailable ? Brand.purple : Brand.warning)
                    }
                    .xeoCard(selected: cinemaID == c.id)
                }
                .buttonStyle(.plain)
                .disabled(!c.isAvailable)
            }
        }
    }

    private var canSubmit: Bool {
        kind == .courier ? address.trimmingCharacters(in: .whitespacesAndNewlines).count >= 4 : cinemaID != nil
    }

    private func submit() {
        let method: ReturnMethod = kind == .courier
            ? .courier(address: address.trimmingCharacters(in: .whitespacesAndNewlines), slot: slot)
            : .cabinet(cinemaID: cinemaID ?? "")
        do {
            try store.scheduleReturn(orderID, method: method)
            model.notifications.cancelReminders(for: orderID)
            model.path = [.order(orderID)]
        } catch { model.show(error, title: "无法归还") }
    }
}
