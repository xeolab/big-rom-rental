import SwiftUI
import RentalKit

struct HomeView: View {
    @EnvironmentObject private var store: RentalStore
    @EnvironmentObject private var model: AppModel

    var body: some View {
        // One-second tick so countdowns and 「即将到期」 banners stay current.
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    header
                    if let o = store.activeOrder { activeCard(o) }
                    actions
                    hint
                }
                .padding(Brand.gutter)
            }
            .background(Brand.paper)
        }
        .xeoHideNavBar()
    }

    private var header: some View {
        HStack {
            LogoView(height: 30)
                // Hidden entry to the demo tools.
                .onLongPressGesture(minimumDuration: 0.8) { model.path.append(.demoTools) }
            Spacer()
            if let a = store.account {
                Text(a.display).font(.xeoCaption).foregroundStyle(Brand.caption)
            }
        }
    }

    @ViewBuilder
    private func activeCard(_ o: Order) -> some View {
        let phase = o.phase(at: store.now)
        VStack(alignment: .leading, spacing: 12) {
            if phase.needsAttention {
                Button { model.path.append(isUnpaid(phase) ? .pendingPayment(o.id) : .renew(o.id)) } label: {
                    AttentionBanner(order: o, phase: phase)
                }
                .buttonStyle(.plain)
            }
            Button { model.path.append(.order(o.id)) } label: {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("XEO BIG + Rom").font(.xeoHeadline).foregroundStyle(Brand.ink)
                        Spacer()
                        StatusChip(phase: phase)
                    }
                    if let end = o.endsAt, o.status == .renting {
                        Text("到期 \(Formatters.dateTime.string(from: end))").font(.xeoBody).foregroundStyle(Brand.secondary)
                    } else if let m = o.returnMethod, let s = o.returnStage {
                        Text(s.title(for: m)).font(.xeoBody).foregroundStyle(Brand.secondary)
                    } else {
                        Text("订单 \(o.id)").font(.xeoBody).foregroundStyle(Brand.secondary)
                    }
                }
                .xeoCard()
            }
            .buttonStyle(.plain)
        }
    }

    private func isUnpaid(_ p: RentalPhase) -> Bool {
        if case .pendingPayment = p { return true }
        return false
    }

    private var actions: some View {
        VStack(spacing: 12) {
            if store.activeOrder == nil {
                VStack(alignment: .leading, spacing: 8) {
                    Text("把 IMAX 装进口袋").font(.xeoLargeTitle).foregroundStyle(Brand.ink)
                    Text("扫描影院柜机上的二维码，选好配件与租期，即刻带走 BIG + Rom。").font(.xeoBody).foregroundStyle(Brand.secondary)
                }
                .padding(.bottom, 8)
            }
            Button { model.path.append(.scanner) } label: {
                Label("扫一扫", systemImage: "qrcode.viewfinder")
            }
            .buttonStyle(PrimaryButtonStyle())
            Button { model.path.append(.orders) } label: {
                Label("我的订单", systemImage: "list.bullet.rectangle")
            }
            .buttonStyle(SecondaryButtonStyle())
        }
    }

    private var hint: some View {
        Text("也可以直接用系统相机扫描柜机二维码，会自动打开本应用。")
            .font(.xeoCaption)
            .foregroundStyle(Brand.caption)
    }
}
