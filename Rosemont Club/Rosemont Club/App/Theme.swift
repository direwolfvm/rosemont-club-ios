import SwiftUI
import UIKit

/// The website's palette (`app/globals.css`), with dark-mode counterparts.
extension Color {
    static let paper = Color(light: 0xFAF9F5, dark: 0x0F151C)
    static let card = Color(light: 0xFFFEFA, dark: 0x1A222B)
    static let brand = Color(light: 0x244D75, dark: 0x8FB4D9)
    static let brandFill = Color(light: 0x244D75, dark: 0x2E5C86)
    static let ink = Color(light: 0x243D55, dark: 0xE6EDF6)
    static let mutedInk = Color(light: 0x627486, dark: 0x9AABBB)
    static let line = Color(light: 0xD3DAE1, dark: 0x2C3A48)
    static let mist = Color(light: 0xEDF2F8, dark: 0x1F2B38)
    static let clay = Color(light: 0xA35335, dark: 0xD98A63)
    static let success = Color(light: 0x2F6B4F, dark: 0x8FD3B0)

    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light)
        })
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

extension Font {
    static func display(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }
    static let heroTitle = display(34)
    static let pageTitle = display(30)
    static let sectionTitle = display(24)
    static let cardTitle = display(19, weight: .semibold)
}

struct PrimaryButtonStyle: ButtonStyle {
    var wide = true
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.vertical, 13)
            .padding(.horizontal, 20)
            .frame(maxWidth: wide ? .infinity : nil)
            .background(Color.brandFill.opacity(configuration.isPressed ? 0.8 : 1), in: RoundedRectangle(cornerRadius: 8))
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    var wide = true
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(Color.brand)
            .padding(.vertical, 12)
            .padding(.horizontal, 20)
            .frame(maxWidth: wide ? .infinity : nil)
            .background(configuration.isPressed ? Color.mist : Color.clear, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.line, lineWidth: 1))
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
    static var primaryCompact: PrimaryButtonStyle { PrimaryButtonStyle(wide: false) }
}

extension ButtonStyle where Self == SecondaryButtonStyle {
    static var secondary: SecondaryButtonStyle { SecondaryButtonStyle() }
    static var secondaryCompact: SecondaryButtonStyle { SecondaryButtonStyle(wide: false) }
}

struct CardBackground: ViewModifier {
    var padding: CGFloat = 18
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.card, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.line, lineWidth: 1))
    }
}

extension View {
    func card(padding: CGFloat = 18) -> some View { modifier(CardBackground(padding: padding)) }

    /// Standard page gutter used throughout the app.
    func pageGutter() -> some View { padding(.horizontal, 18) }
}

/// Custom text field styling matching the website's forms.
struct ClubFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.card, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.line, lineWidth: 1))
    }
}
