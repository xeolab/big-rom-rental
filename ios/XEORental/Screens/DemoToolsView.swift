import SwiftUI
import RentalKit

/// Hidden demo panel (long-press the logo on the home screen). Moves the demo clock, fires reminders, resets data.
struct DemoToolsView: View {
    @EnvironmentObject private var store: RentalStore
    @EnvironmentObject private var model: AppModel
    @State private var note: String?
    @State private var confirmReset = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ScreenTitle(title: "演示工具", subtitle: "只用于演示：调整应用内时间、触发提醒、清空数据。不影响手机系统时间。")

                group("时间快进") {
                    tool("租期剩 2 天（即将到期）", "clock.badge.exclamationmark") { jump(.expiringIn2Days, needs: "租赁中的订单") }
                    tool("已逾期 5 小时", "exclamationmark.triangle") { jump(.overdue5Hours, needs: "租赁中的订单") }
                    tool("待支付订单剩 30 秒", "timer") { jump(.pendingRemaining30s, needs: "待支付订单") }
                    tool("恢复真实时间", "arrow.uturn.backward") { store.resetClock(); note = "已恢复真实时间" }
                    Text("当前应用时间：\(Formatters.dateTime.string(from: store.now))" + (store.clock.offset == 0 ? "" : "（已调整）"))
                        .font(.xeoCaption).foregroundStyle(Brand.caption)
                }

                group("提醒") {
                    tool("3 秒后发送租期提醒通知", "bell.badge") {
                        guard let o = store.currentRental else { note = "没有租赁中的订单"; return }
                        model.notifications.fireNow(for: o)
                        note = "3 秒后会收到提醒，可以先锁屏或切到后台"
                    }
                }

                group("二维码（模拟扫码）") {
                    tool("打开柜机入口二维码", "qrcode") { model.open(QRRoute.rent(cabinet: DemoIDs.cabinet).url) }
                    tool("打开 Rom 激活二维码", "qrcode") { model.open(QRRoute.activate(device: DemoIDs.device).url) }
                    tool("打开 Rom 续租二维码", "qrcode") { model.open(QRRoute.renew(device: DemoIDs.device).url) }
                }

                group("数据") {
                    tool("清空全部数据（账号、订单、时间）", "trash") { confirmReset = true }
                }

                if let note { Text(note).font(.xeoBody).foregroundStyle(Brand.purple) }
            }
            .padding(Brand.gutter)
        }
        .background(Brand.paper)
        .navigationTitle("演示工具")
        .xeoInlineTitle()
        .alert("清空全部数据？", isPresented: $confirmReset) {
            Button("取消", role: .cancel) {}
            Button("清空", role: .destructive) {
                store.orders.forEach { model.notifications.cancelReminders(for: $0.id) }
                store.resetAll()
                model.path = []
            }
        } message: { Text("会退出登录并删除所有演示订单。") }
    }

    private func jump(_ j: RentalStore.DemoJump, needs: String) {
        guard store.demoJump(j) else { note = "没有\(needs)"; return }
        // Reminders were scheduled against the old clock offset; re-plan them on the new one.
        if let o = store.currentRental { model.notifications.scheduleReminders(for: o) }
        note = "已调整应用时间"
    }

    private func group<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.xeoHeadline).foregroundStyle(Brand.ink)
            content()
        }
    }

    private func tool(_ title: String, _ icon: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon).foregroundStyle(Brand.purple).frame(width: 24)
                Text(title).font(.xeoBody).foregroundStyle(Brand.ink)
                Spacer()
            }
            .xeoCard()
        }
        .buttonStyle(.plain)
    }
}
