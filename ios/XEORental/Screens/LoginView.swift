import SwiftUI
import RentalKit

/// Placeholder login: no SMS and no Apple ID call is made. Any 11-digit phone + any 6-digit code works.
struct LoginView: View {
    @EnvironmentObject private var store: RentalStore
    @EnvironmentObject private var model: AppModel
    @State private var phone = ""
    @State private var code = ""
    @State private var codeSent = false
    @State private var error: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ScreenTitle(title: "登录 XEO", subtitle: "登录后开始租赁，订单与提醒会关联到你的账号。")

                VStack(spacing: 12) {
                    HStack {
                        Text("+86").font(.xeoBody).foregroundStyle(Brand.secondary)
                        TextField("手机号", text: $phone).xeoPhoneField().font(.xeoBody)
                    }
                    .xeoCard()
                    HStack {
                        TextField("6 位验证码", text: $code).xeoOneTimeCode().font(.xeoBody)
                            .onChange(of: code) { _, v in code = String(v.filter { $0.isASCII && $0.isNumber }.prefix(6)) }
                        Button(codeSent ? "已发送" : "获取验证码") { codeSent = true; error = nil }
                            .font(.xeoHeadline)
                            .foregroundStyle(codeSent ? Brand.caption : Brand.purple)
                            .disabled(codeSent)
                    }
                    .xeoCard()
                    if codeSent {
                        Text("演示环境：不会真的发送短信，输入任意 6 位数字即可。").font(.xeoCaption).foregroundStyle(Brand.caption)
                    }
                    if let error {
                        Text(error).font(.xeoCaption).foregroundStyle(Brand.warning)
                    }
                }

                Button("登录") {
                    if let e = store.loginWithPhone(phone, code: code) { error = e.message } else { model.didLogin() }
                }
                .buttonStyle(PrimaryButtonStyle())

                HStack {
                    Rectangle().fill(Brand.silver).frame(height: 1)
                    Text("或").font(.xeoCaption).foregroundStyle(Brand.caption)
                    Rectangle().fill(Brand.silver).frame(height: 1)
                }

                // Styled like Sign in with Apple, but a placeholder: no entitlement, so a free personal team can sign the app.
                Button {
                    store.loginWithApplePlaceholder()
                    model.didLogin()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "applelogo")
                        Text("通过 Apple 登录")
                    }
                    .font(.xeoHeadline)
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(RoundedRectangle(cornerRadius: Brand.corner).fill(Color.black))
                }
                .buttonStyle(.plain)

                Text("登录即表示同意《XEO 租赁服务协议》与《隐私政策》（演示）").font(.xeoCaption).foregroundStyle(Brand.caption)
            }
            .padding(Brand.gutter)
        }
        .background(Brand.paper)
        .navigationTitle("")
        .xeoInlineTitle()
    }
}
