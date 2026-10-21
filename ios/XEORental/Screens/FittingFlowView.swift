import SwiftUI
import RentalKit

/// 设备与配件适配: 面罩 → 绑带（测头围）→ 镜片（近视度数）→ 耳机 → 确认组合.
/// One face measurement feeds both the mask recommendation and the strap size.
struct FittingFlowView: View {
    @EnvironmentObject private var store: RentalStore
    @EnvironmentObject private var model: AppModel

    @State private var step = 0
    @State private var mask: MaskSize?
    @State private var headCm: Int?
    @State private var headMeasured = false
    @State private var showMeasure = false
    @State private var leftText = ""
    @State private var rightText = ""
    @State private var earphone: EarphoneChoice?

    private let titles = ["选择面罩", "调整绑带", "选择镜片度数", "选择耳机", "确认配件组合"]

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    StepHeader(index: step, total: titles.count, title: titles[step])
                    switch step {
                    case 0: maskStep
                    case 1: strapStep
                    case 2: lensStep
                    case 3: earphoneStep
                    default: summaryStep
                    }
                }
                .padding(Brand.gutter)
            }
            footer
        }
        .background(Brand.paper)
        .navigationTitle("配件适配")
        .xeoInlineTitle()
        .sheet(isPresented: $showMeasure) {
            HeadMeasureView { cm, measured in
                headCm = cm
                headMeasured = measured
                if mask == nil { mask = MaskSize.recommended(forHeadCircumference: cm) }
            }
        }
    }

    // MARK: steps

    private var recommendedMask: MaskSize? { headCm.map(MaskSize.recommended(forHeadCircumference:)) }

    private var maskStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("先做一次面部测量，我们会据此推荐面罩尺码和绑带长度。").font(.xeoBody).foregroundStyle(Brand.secondary)
            Button { showMeasure = true } label: {
                Label(headCm == nil ? "开始面部测量" : "重新测量（当前头围 \(headCm!) cm）", systemImage: "faceid")
            }
            .buttonStyle(SecondaryButtonStyle())
            ForEach(MaskSize.allCases) { size in
                Button { mask = size } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(size.title).font(.xeoHeadline).foregroundStyle(Brand.ink)
                            Text(maskHint(size)).font(.xeoCaption).foregroundStyle(Brand.secondary)
                        }
                        Spacer()
                        if size == recommendedMask {
                            Text("推荐").font(.system(size: 12, weight: .semibold)).foregroundStyle(Brand.purple)
                        }
                    }
                    .xeoCard(selected: mask == size)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func maskHint(_ s: MaskSize) -> String {
        switch s {
        case .s: return "适合头围 55 cm 以下"
        case .m: return "适合头围 55–58 cm"
        case .l: return "适合头围 59 cm 以上"
        }
    }

    private var strapStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let cm = headCm {
                VStack(alignment: .leading, spacing: 8) {
                    Text(headMeasured ? "估算头围" : "头围").font(.xeoCaption).foregroundStyle(Brand.caption)
                    HStack(alignment: .firstTextBaseline) {
                        Text("\(cm)").font(.system(size: 44, weight: .bold)).foregroundStyle(Brand.ink)
                        Text("cm").font(.xeoHeadline).foregroundStyle(Brand.secondary)
                        Spacer()
                        Stepper("", value: Binding(get: { headCm ?? cm }, set: { headCm = $0 }), in: HeadEstimator.range)
                            .labelsHidden()
                    }
                    Text(headMeasured ? "根据面部测量估算，可用 ± 微调 1 cm。" : "手动填写的头围，可用 ± 调整。")
                        .font(.xeoCaption).foregroundStyle(Brand.secondary)
                }
                .xeoCard()
            } else {
                Text("还没有测量头围。").font(.xeoBody).foregroundStyle(Brand.secondary)
            }
            Button { showMeasure = true } label: {
                Label(headCm == nil ? "测量头围" : "重新测量", systemImage: "faceid")
            }
            .buttonStyle(SecondaryButtonStyle())
            Text("绑带会按头围预调到合适长度，拿到设备后仍可手动微调。").font(.xeoCaption).foregroundStyle(Brand.caption)
        }
    }

    private var leftResult: Result<Int, DiopterError> { DiopterRule.validate(leftText) }
    private var rightResult: Result<Int, DiopterError> { DiopterRule.validate(rightText) }

    private var lensStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("请填写左右眼的近视度数（整数，单位：度）。没有近视请填 0。").font(.xeoBody).foregroundStyle(Brand.secondary)
            diopterField("左眼", text: $leftText, result: leftResult)
            diopterField("右眼", text: $rightText, result: rightResult)
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.circle").foregroundStyle(Brand.purple)
                Text("本设备镜片**不支持散光**矫正，仅支持 0–\(DiopterRule.max) 度近视。如有明显散光，建议佩戴隐形眼镜使用。")
                    .font(.xeoBody).foregroundStyle(Brand.ink)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: Brand.corner).fill(Brand.frost))
        }
    }

    private func diopterField(_ label: String, text: Binding<String>, result: Result<Int, DiopterError>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label).font(.xeoHeadline).foregroundStyle(Brand.ink).frame(width: 48, alignment: .leading)
                TextField("例如 350", text: text)
                    .xeoNumberPad()
                    .font(.system(size: 20, weight: .semibold))
                    .onChange(of: text.wrappedValue) { _, v in
                        let clean = DiopterRule.sanitize(v)
                        if clean != v { text.wrappedValue = clean }
                    }
                Text("度").font(.xeoBody).foregroundStyle(Brand.secondary)
            }
            .xeoCard()
            if !text.wrappedValue.isEmpty, case let .failure(e) = result {
                Text(e.message).font(.xeoCaption).foregroundStyle(Brand.warning)
            }
        }
    }

    private var earphoneStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("观影声音可以用自己的耳机，也可以一起租用 XEO 耳机。").font(.xeoBody).foregroundStyle(Brand.secondary)
            ForEach(EarphoneChoice.allCases) { e in
                Button { earphone = e } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(e.title).font(.xeoHeadline).foregroundStyle(Brand.ink)
                        Text(e == .own ? "支持蓝牙耳机，或通过 3.5 mm / USB‑C 有线连接" : "随设备一起领取，归还时一并放回收纳包")
                            .font(.xeoCaption).foregroundStyle(Brand.secondary)
                    }
                    .xeoCard(selected: earphone == e)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var summaryStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let f = fitting {
                InfoRow(label: "面罩", value: f.mask.title)
                InfoRow(label: "绑带", value: f.strapSummary)
                InfoRow(label: "镜片", value: f.lensSummary)
                InfoRow(label: "耳机", value: f.earphone.title)
            }
            Text("确认后选择租期。领取时柜机会按这份组合备好配件。").font(.xeoCaption).foregroundStyle(Brand.caption).padding(.top, 6)
        }
        .xeoCard()
    }

    // MARK: footer

    private var fitting: Fitting? {
        guard let mask, let headCm, case let .success(l) = leftResult, case let .success(r) = rightResult, let earphone else { return nil }
        return Fitting(mask: mask, headCircumferenceCm: headCm, headMeasured: headMeasured, leftDiopter: l, rightDiopter: r, earphone: earphone)
    }

    private var canContinue: Bool {
        switch step {
        case 0: return mask != nil
        case 1: return headCm != nil
        case 2: if case .success = leftResult, case .success = rightResult { return true } else { return false }
        case 3: return earphone != nil
        default: return fitting != nil
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            if step > 0 {
                Button("上一步") { step -= 1 }.buttonStyle(SecondaryButtonStyle()).frame(maxWidth: 120)
            }
            Button(step == titles.count - 1 ? "确认，选择租期" : "下一步") {
                if step < titles.count - 1 { step += 1 } else if let f = fitting {
                    if store.draft == nil { store.beginRent(cabinet: DemoIDs.cabinet) }
                    store.draft?.fitting = f
                    model.path.append(.plan)
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(!canContinue)
        }
        .padding(Brand.gutter)
        .background(Brand.paper)
    }
}
