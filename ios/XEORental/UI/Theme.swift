import SwiftUI

/// XEO brand tokens (xeo-brand skill §A2): white ground, black type, XEO Purple as the single accent.
enum Brand {
    static let purple = Color(red: 0x66 / 255, green: 0x38 / 255, blue: 0xB6 / 255)       // #6638B6
    static let purpleTint = Color(red: 0x90 / 255, green: 0x68 / 255, blue: 0xF0 / 255)   // #9068F0 — dark backgrounds only
    static let ink = Color.black
    static let paper = Color.white
    static let softGray = Color(red: 0xF5 / 255, green: 0xF5 / 255, blue: 0xF5 / 255)     // Soft White Gray
    static let frost = Color(red: 0xEF / 255, green: 0xF1 / 255, blue: 0xF4 / 255)        // Frost Haze
    static let silver = Color(red: 0xD9 / 255, green: 0xDD / 255, blue: 0xE3 / 255)       // Cool Silver
    static let secondary = Color(red: 0x4A / 255, green: 0x4A / 255, blue: 0x4A / 255)    // body-secondary (layout gray)
    static let caption = Color(red: 0x8A / 255, green: 0x8F / 255, blue: 0x96 / 255)
    static let warning = Color(red: 0xC2 / 255, green: 0x41 / 255, blue: 0x2D / 255)      // overdue / errors only

    static let corner: CGFloat = 14
    static let gutter: CGFloat = 20
}

extension Font {
    static let xeoLargeTitle = Font.system(size: 30, weight: .bold)
    static let xeoTitle = Font.system(size: 22, weight: .bold)
    static let xeoHeadline = Font.system(size: 17, weight: .semibold)
    static let xeoBody = Font.system(size: 16)
    static let xeoCaption = Font.system(size: 13)
}

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.xeoHeadline)
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(RoundedRectangle(cornerRadius: Brand.corner).fill(isEnabled ? Brand.purple : Brand.silver))
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.xeoHeadline)
            .foregroundStyle(Brand.ink)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(RoundedRectangle(cornerRadius: Brand.corner).stroke(Brand.silver, lineWidth: 1.5))
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

extension View {
    func xeoCard(selected: Bool = false) -> some View {
        padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: Brand.corner).fill(selected ? Brand.purple.opacity(0.06) : Brand.paper))
            .overlay(RoundedRectangle(cornerRadius: Brand.corner).stroke(selected ? Brand.purple : Brand.silver, lineWidth: selected ? 2 : 1))
    }

    // iOS-only modifiers behind helpers so the shared views also type-check on macOS.
    @ViewBuilder func xeoInlineTitle() -> some View {
        #if os(iOS)
        navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }

    @ViewBuilder func xeoHideNavBar() -> some View {
        #if os(iOS)
        toolbar(.hidden, for: .navigationBar)
        #else
        self
        #endif
    }

    @ViewBuilder func xeoNumberPad() -> some View {
        #if os(iOS)
        keyboardType(.numberPad)
        #else
        self
        #endif
    }

    @ViewBuilder func xeoPhoneField() -> some View {
        #if os(iOS)
        keyboardType(.phonePad).textContentType(.telephoneNumber)
        #else
        self
        #endif
    }

    @ViewBuilder func xeoOneTimeCode() -> some View {
        #if os(iOS)
        keyboardType(.numberPad).textContentType(.oneTimeCode)
        #else
        self
        #endif
    }
}
