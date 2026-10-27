import SwiftUI

enum Theme {
    static let bgTop = Color(red: 0.07, green: 0.08, blue: 0.11)
    static let bgBottom = Color(red: 0.12, green: 0.13, blue: 0.18)
    static let card = Color.white.opacity(0.06)
    static let stroke = Color.white.opacity(0.10)
    static let textPrimary = Color.white.opacity(0.96)
    static let textSecondary = Color.white.opacity(0.55)
    static let gold = Color(red: 1.0, green: 0.78, blue: 0.30)
    static let amber = Color(red: 1.0, green: 0.62, blue: 0.15)
    static let green = Color(red: 0.35, green: 0.95, blue: 0.62)
    static let pink = Color(red: 1.0, green: 0.42, blue: 0.55)
    static let cyan = Color(red: 0.35, green: 0.85, blue: 0.98)

    static var hypeGradient: LinearGradient {
        LinearGradient(colors: [gold, amber, Color(red: 1.0, green: 0.45, blue: 0.25)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    static var simpleGradient: LinearGradient {
        LinearGradient(colors: [Color.white, Color.white.opacity(0.75)],
                       startPoint: .top, endPoint: .bottom)
    }
    static var barGradient: LinearGradient {
        LinearGradient(colors: [green, cyan], startPoint: .leading, endPoint: .trailing)
    }
    static var hypeBarGradient: LinearGradient {
        LinearGradient(colors: [gold, pink, cyan], startPoint: .leading, endPoint: .trailing)
    }

    static func mono(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

struct PanelBackground: View {
    var hype: Bool
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(LinearGradient(colors: [Theme.bgTop, Theme.bgBottom],
                                     startPoint: .top, endPoint: .bottom))
            if hype {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(RadialGradient(colors: [Theme.amber.opacity(0.16), .clear],
                                         center: .topTrailing, startRadius: 4, endRadius: 320))
            }
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 1)
        }
    }
}

/// 简易 HUD 按钮
struct HUDButton: View {
    let symbol: String
    var help: String = ""
    let action: () -> Void
    @State private var hover = false
    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(hover ? Color.white : Theme.textSecondary)
                .frame(width: 22, height: 22)
                .background(Circle().fill(Color.white.opacity(hover ? 0.14 : 0.06)))
        }
        .buttonStyle(.plain)
        .help(help)
        .onHover { hover = $0 }
    }
}
