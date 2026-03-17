import SwiftUI

enum LiftTheme {
    static let cardCornerRadius: CGFloat = 24
    static let compactCornerRadius: CGFloat = 18
}

extension Font {
    static func lift(_ style: TextStyle, weight: Weight = .regular) -> Font {
        .system(style, design: .rounded, weight: weight)
    }
}

extension Color {
    static let liftSurface = Color("LiftSurface")
    static let liftCard = Color("LiftCard")
    static let liftStrength = Color("LiftStrength")
    static let liftGlow = Color("LiftGlow")
}

extension View {
    func liftCardStyle() -> some View {
        self
            .padding(20)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: LiftTheme.cardCornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: LiftTheme.cardCornerRadius, style: .continuous)
                    .strokeBorder(.white.opacity(0.08))
            )
    }
}
