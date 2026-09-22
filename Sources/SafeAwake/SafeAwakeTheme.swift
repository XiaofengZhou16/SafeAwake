import SwiftUI

enum AwakeTheme {
    static let accent = Color(red: 0.10, green: 0.67, blue: 0.49)
    static let accentBright = Color(red: 0.20, green: 0.82, blue: 0.62)
    static let warning = Color(red: 0.96, green: 0.62, blue: 0.16)
    static let surfaceTint = Color.primary.opacity(0.035)
    static let border = Color.primary.opacity(0.10)
    static let textSecondary = Color.secondary

    enum Radius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
    }

    enum Motion {
        static let snappy = Animation.spring(duration: 0.28, bounce: 0.12)
        static let smooth = Animation.easeInOut(duration: 0.22)
    }
}

private struct AwakeCardModifier: ViewModifier {
    let padding: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: AwakeTheme.Radius.medium, style: .continuous)
                        .fill(.regularMaterial)
                    RoundedRectangle(cornerRadius: AwakeTheme.Radius.medium, style: .continuous)
                        .fill(AwakeTheme.surfaceTint)
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: AwakeTheme.Radius.medium, style: .continuous)
                    .strokeBorder(AwakeTheme.border, lineWidth: 0.5)
            }
    }
}

extension View {
    func awakeCard(padding: CGFloat = 12) -> some View {
        modifier(AwakeCardModifier(padding: padding))
    }
}
