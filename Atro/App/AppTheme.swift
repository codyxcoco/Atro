import SwiftUI
import UIKit

enum LiftTheme {
    static let cardCornerRadius: CGFloat = 24
    static let compactCornerRadius: CGFloat = 18
}

enum LiftMotion {
    static func settle(_ reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : .easeInOut(duration: 0.24)
    }

    static func selection(_ reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : .interactiveSpring(response: 0.30, dampingFraction: 0.86)
    }

    static func emphasis(_ reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : .spring(response: 0.34, dampingFraction: 0.88, blendDuration: 0.12)
    }

    static func swipe(_ reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : .spring(response: 0.30, dampingFraction: 0.84, blendDuration: 0.10)
    }

    static func reveal(_ reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.86)
    }

    static func press(_ reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : .spring(response: 0.22, dampingFraction: 0.82)
    }

    static func banner(_ reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : .snappy(duration: 0.32, extraBounce: 0.04)
    }
}

enum LiftMoodPalette {
    private static let colorStops: [(red: CGFloat, green: CGFloat, blue: CGFloat)] = [
        (0.87, 0.57, 0.62),
        (0.87, 0.68, 0.55),
        (0.67, 0.70, 0.72),
        (0.60, 0.79, 0.63),
        (0.49, 0.83, 0.62)
    ]

    static func level(for progress: CGFloat) -> Int {
        let clampedProgress = min(max(progress, 0), 1)

        switch clampedProgress {
        case ..<0.08:
            return 1
        case ..<0.38:
            return 2
        case ..<0.62:
            return 3
        case ..<0.92:
            return 4
        default:
            return 5
        }
    }

    static func color(for level: Int) -> Color {
        color(for: CGFloat(min(max(level, 1), 5) - 1) / 4)
    }

    static func color(for progress: CGFloat) -> Color {
        let clampedProgress = min(max(progress, 0), 1)
        let scaledIndex = clampedProgress * CGFloat(colorStops.count - 1)
        let lowerIndex = Int(floor(scaledIndex))
        let upperIndex = min(lowerIndex + 1, colorStops.count - 1)
        let fraction = scaledIndex - CGFloat(lowerIndex)
        let lower = colorStops[lowerIndex]
        let upper = colorStops[upperIndex]

        let baseColor = UIColor(
            red: lower.red + ((upper.red - lower.red) * fraction),
            green: lower.green + ((upper.green - lower.green) * fraction),
            blue: lower.blue + ((upper.blue - lower.blue) * fraction),
            alpha: 1
        )

        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0

        guard baseColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) else {
            return Color(uiColor: baseColor)
        }

        return Color(
            uiColor: UIColor(
                hue: hue,
                saturation: min(saturation * 1.20, 1),
                brightness: min(brightness * 0.97, 1),
                alpha: alpha
            )
        )
    }

    static func title(for level: Int) -> String {
        switch level {
        case ...1:
            "Very Bad"
        case 2:
            "Bad"
        case 3:
            "Neutral"
        case 4:
            "Good"
        default:
            "Very Good"
        }
    }

    static func title(for progress: CGFloat) -> String {
        title(for: level(for: progress))
    }
}

enum LiftTypography {
    @MainActor
    static func configureAppearance() {
        let accentColor = UIColor(named: "AccentColor") ?? .systemTeal
        let surfaceColor = UIColor(named: "LiftSurface") ?? .systemBackground

        let navigationAppearance = UINavigationBarAppearance()
        navigationAppearance.configureWithTransparentBackground()
        navigationAppearance.backgroundColor = .clear
        navigationAppearance.largeTitleTextAttributes = [
            .font: UIFont.roundedPreferredFont(forTextStyle: .largeTitle, weight: .bold)
        ]
        navigationAppearance.titleTextAttributes = [
            .font: UIFont.roundedPreferredFont(forTextStyle: .headline, weight: .semibold)
        ]

        let navigationBar = UINavigationBar.appearance()
        navigationBar.standardAppearance = navigationAppearance
        navigationBar.scrollEdgeAppearance = navigationAppearance
        navigationBar.compactAppearance = navigationAppearance
        navigationBar.tintColor = accentColor

        let tabAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.roundedPreferredFont(forTextStyle: .caption1)
        ]
        let tabBarItem = UITabBarItem.appearance()
        tabBarItem.setTitleTextAttributes(tabAttributes, for: .normal)
        tabBarItem.setTitleTextAttributes(tabAttributes, for: .selected)

        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithTransparentBackground()
        tabBarAppearance.backgroundColor = surfaceColor.withAlphaComponent(0.92)
        tabBarAppearance.shadowColor = UIColor.white.withAlphaComponent(0.04)

        let normalItemColor = UIColor.secondaryLabel
        for itemAppearance in [
            tabBarAppearance.stackedLayoutAppearance,
            tabBarAppearance.inlineLayoutAppearance,
            tabBarAppearance.compactInlineLayoutAppearance
        ] {
            itemAppearance.normal.iconColor = normalItemColor
            itemAppearance.normal.titleTextAttributes = [.foregroundColor: normalItemColor]
            itemAppearance.selected.iconColor = accentColor
            itemAppearance.selected.titleTextAttributes = [.foregroundColor: accentColor]
        }

        let tabBar = UITabBar.appearance()
        tabBar.standardAppearance = tabBarAppearance
        tabBar.scrollEdgeAppearance = tabBarAppearance
        tabBar.tintColor = accentColor
        tabBar.unselectedItemTintColor = normalItemColor

        let segmentedAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.roundedPreferredFont(forTextStyle: .subheadline)
        ]
        let segmentedControl = UISegmentedControl.appearance()
        segmentedControl.setTitleTextAttributes(segmentedAttributes, for: .normal)
        segmentedControl.setTitleTextAttributes(segmentedAttributes, for: .selected)

        let barButtonAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.roundedPreferredFont(forTextStyle: .body)
        ]
        let barButtonItem = UIBarButtonItem.appearance()
        barButtonItem.setTitleTextAttributes(barButtonAttributes, for: .normal)
        barButtonItem.setTitleTextAttributes(barButtonAttributes, for: .highlighted)
        barButtonItem.setTitleTextAttributes(barButtonAttributes, for: .disabled)

        let textInputFont = UIFont.roundedPreferredFont(forTextStyle: .body)
        UITextField.appearance().font = textInputFont
        UITextView.appearance().font = textInputFont
    }
}

extension Font {
    static func lift(_ style: TextStyle, weight: Weight = .regular) -> Font {
        .system(style, design: .rounded, weight: weight)
    }
}

extension UIFont {
    static func roundedPreferredFont(forTextStyle textStyle: TextStyle, weight: Weight = .regular) -> UIFont {
        let preferredFont = UIFont.preferredFont(forTextStyle: textStyle)
        let weightedFont = UIFont.systemFont(ofSize: preferredFont.pointSize, weight: weight)
        let roundedDescriptor = weightedFont.fontDescriptor.withDesign(.rounded) ?? weightedFont.fontDescriptor
        return UIFont(descriptor: roundedDescriptor, size: preferredFont.pointSize)
    }
}

extension Color {
    static let liftSurface = Color("LiftSurface")
    static let liftCard = Color("LiftCard")
    static let liftStrength = Color("LiftStrength")
    static let liftGlow = Color("LiftGlow")
    static let liftHealthTint = Color(red: 1.00, green: 0.29, blue: 0.45)
    static let liftFitnessTint = Color(red: 0.74, green: 0.96, blue: 0.25)
    static let liftBodyTint = Color(red: 0.16, green: 0.86, blue: 0.79)
    static let liftMealsTint = Color(red: 0.26, green: 0.62, blue: 0.39)
    static let liftGuideTint = Color(red: 0.88, green: 0.46, blue: 0.84)
}

extension View {
    func liftScreenBackground() -> some View {
        modifier(LiftScreenBackgroundModifier())
    }

    func liftCardStyle() -> some View {
        modifier(LiftCardModifier())
    }
}

private struct LiftScreenBackgroundModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background {
                if colorScheme == .dark {
                    ZStack {
                        LinearGradient(
                            colors: [
                                Color.black,
                                Color(red: 0.02, green: 0.025, blue: 0.035)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )

                        RadialGradient(
                            colors: [
                                Color.liftGlow.opacity(0.22),
                                .clear
                            ],
                            center: .topLeading,
                            startRadius: 20,
                            endRadius: 380
                        )
                        .blur(radius: 18)
                        .offset(x: -70, y: -110)

                        RadialGradient(
                            colors: [
                                Color.accentColor.opacity(0.18),
                                .clear
                            ],
                            center: .bottomTrailing,
                            startRadius: 20,
                            endRadius: 360
                        )
                        .blur(radius: 28)
                        .offset(x: 90, y: 130)

                        RadialGradient(
                            colors: [
                                Color(red: 0.11, green: 0.44, blue: 0.55).opacity(0.12),
                                .clear
                            ],
                            center: .center,
                            startRadius: 10,
                            endRadius: 320
                        )
                        .blur(radius: 26)
                        .offset(y: -120)
                    }
                    .ignoresSafeArea()
                } else {
                    Color.liftSurface.ignoresSafeArea()
                }
            }
    }
}

private struct LiftCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background {
                RoundedRectangle(cornerRadius: LiftTheme.cardCornerRadius, style: .continuous)
                    .fill(cardFill)
                    .overlay {
                        if colorScheme == .dark {
                            RoundedRectangle(cornerRadius: LiftTheme.cardCornerRadius, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.06),
                                            Color.white.opacity(0.015),
                                            .clear
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }
                    }
            }
            .overlay(
                RoundedRectangle(cornerRadius: LiftTheme.cardCornerRadius, style: .continuous)
                    .strokeBorder(cardBorder, lineWidth: 1)
            )
            .shadow(color: shadowColor, radius: colorScheme == .dark ? 22 : 10, y: colorScheme == .dark ? 12 : 4)
    }

    private var cardFill: AnyShapeStyle {
        if colorScheme == .dark {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [
                        Color(red: 0.13, green: 0.14, blue: 0.16).opacity(0.96),
                        Color(red: 0.09, green: 0.10, blue: 0.12).opacity(0.98)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        } else {
            return AnyShapeStyle(.thinMaterial)
        }
    }

    private var cardBorder: Color {
        colorScheme == .dark ? .white.opacity(0.08) : .white.opacity(0.08)
    }

    private var shadowColor: Color {
        colorScheme == .dark ? Color.liftGlow.opacity(0.10) : .black.opacity(0.10)
    }
}
