import SwiftUI
import RentalKit

@main
struct XEORentalApp: App {
    @StateObject private var store: RentalStore
    @StateObject private var model: AppModel
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let store = RentalStore(fileURL: RentalStore.defaultFileURL())
        _store = StateObject(wrappedValue: store)
        _model = StateObject(wrappedValue: AppModel(store: store))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(model)
                .tint(Brand.purple)
                .preferredColorScheme(.light)
                .onOpenURL { model.open($0) }   // xeorental://… from the system camera or Safari
                .onAppear { model.notifications.activate() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { store.refreshAll() }
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        NavigationStack(path: $model.path) {
            HomeView()
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .login: LoginView()
                    case .fitting: FittingFlowView()
                    case .plan: PlanView()
                    case let .confirm(plan): ConfirmOrderView(plan: plan)
                    case let .pendingPayment(id): PendingPaymentView(orderID: id)
                    case .orders: OrdersView()
                    case let .order(id): OrderDetailView(orderID: id)
                    case let .renew(id): RenewView(orderID: id)
                    case let .returnFlow(id): ReturnView(orderID: id)
                    case .scanner: ScannerScreen()
                    case .demoTools: DemoToolsView()
                    }
                }
        }
        .alert(item: $model.alert) { a in
            Alert(title: Text(a.title), message: Text(a.message), dismissButton: .default(Text("知道了")))
        }
    }
}
