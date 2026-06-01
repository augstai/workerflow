import AppKit
import SwiftUI

enum WFDesign {
    enum Colors {
        static let background = Color(hex: "#0E1110")
        static let panel = Color(hex: "#151816")
        static let panelElevated = Color(hex: "#1D211F")
        static let control = Color(hex: "#262B28")
        static let controlHover = Color(hex: "#303631")
        static let border = Color.white.opacity(0.10)
        static let borderStrong = Color.white.opacity(0.18)
        static let text = Color(hex: "#F4F6F5")
        static let textMuted = Color(hex: "#AAB2AD")
        static let textFaint = Color(hex: "#68726D")
        static let accent = Color(hex: "#5CC8FF")
        static let accentDeep = Color(hex: "#0A84FF")
        static let success = Color(hex: "#39D98A")
        static let warning = Color(hex: "#FFBD4A")
        static let danger = Color(hex: "#FF5C7A")
    }

    enum Radius {
        static let control: CGFloat = 8
        static let panel: CGFloat = 16
        static let pill: CGFloat = 999
    }
}

extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex.trimmingCharacters(in: CharacterSet(charactersIn: "#")))
        var value: UInt64 = 0
        scanner.scanHexInt64(&value)

        let red = Double((value >> 16) & 0xff) / 255.0
        let green = Double((value >> 8) & 0xff) / 255.0
        let blue = Double(value & 0xff) / 255.0

        self.init(red: red, green: green, blue: blue)
    }
}

struct VisualEffectBackground: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    init(
        material: NSVisualEffectView.Material = .hudWindow,
        blendingMode: NSVisualEffectView.BlendingMode = .behindWindow
    ) {
        self.material = material
        self.blendingMode = blendingMode
    }

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = .active
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    var fullWidth = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: WFDesign.Radius.control, style: .continuous)
                    .fill(configuration.isPressed ? WFDesign.Colors.accentDeep.opacity(0.82) : WFDesign.Colors.accentDeep)
            )
            .shadow(color: WFDesign.Colors.accentDeep.opacity(configuration.isPressed ? 0.12 : 0.24), radius: 12, x: 0, y: 5)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
    }
}

struct QuietButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(WFDesign.Colors.text)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: WFDesign.Radius.control, style: .continuous)
                    .fill(configuration.isPressed ? WFDesign.Colors.controlHover : WFDesign.Colors.control)
            )
            .overlay(
                RoundedRectangle(cornerRadius: WFDesign.Radius.control, style: .continuous)
                    .stroke(WFDesign.Colors.border, lineWidth: 0.8)
            )
    }
}

struct DestructiveButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(WFDesign.Colors.danger)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: WFDesign.Radius.control, style: .continuous)
                    .fill(WFDesign.Colors.danger.opacity(configuration.isPressed ? 0.18 : 0.10))
            )
    }
}
