import SwiftUI

enum MoodScaleValuePlacement: Equatable {
    case aboveOrb
    case belowOrb
}

enum MoodScalePickerStyle {
    case regular
    case compact

    var isRegular: Bool {
        switch self {
        case .regular:
            true
        case .compact:
            false
        }
    }

    var orbSize: CGFloat {
        switch self {
        case .regular:
            198
        case .compact:
            170
        }
    }

    var orbFrameSize: CGFloat {
        switch self {
        case .regular:
            312
        case .compact:
            170
        }
    }

    var ringSizes: [CGFloat] {
        switch self {
        case .regular:
            [280, 242, 204, 154]
        case .compact:
            [170, 136, 102]
        }
    }

    var titleFont: Font {
        switch self {
        case .regular:
            .lift(.headline, weight: .semibold)
        case .compact:
            .lift(.subheadline, weight: .semibold)
        }
    }

    var valueFont: Font {
        switch self {
        case .regular:
            .system(size: 40, weight: .black, design: .rounded)
        case .compact:
            .lift(.title2, weight: .bold)
        }
    }

    var bodyFont: Font {
        switch self {
        case .regular:
            .lift(.body)
        case .compact:
            .lift(.footnote)
        }
    }

    var bodyColor: Color {
        switch self {
        case .regular:
            .white.opacity(0.76)
        case .compact:
            .primary.opacity(0.62)
        }
    }

    var verticalSpacing: CGFloat {
        switch self {
        case .regular:
            20
        case .compact:
            18
        }
    }

    var contentPadding: EdgeInsets {
        switch self {
        case .regular:
            EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0)
        case .compact:
            EdgeInsets()
        }
    }

    var valuePlacement: MoodScaleValuePlacement {
        switch self {
        case .regular:
            .belowOrb
        case .compact:
            .aboveOrb
        }
    }

    var sliderKnobSize: CGFloat {
        switch self {
        case .regular:
            36
        case .compact:
            34
        }
    }

    var sliderTrackHeight: CGFloat {
        switch self {
        case .regular:
            26
        case .compact:
            26
        }
    }

    var usesFilledSliderTrack: Bool {
        switch self {
        case .regular:
            false
        case .compact:
            true
        }
    }

    var sliderLabelFont: Font {
        switch self {
        case .regular:
            .system(size: 13, weight: .black, design: .rounded)
        case .compact:
            .lift(.caption, weight: .semibold)
        }
    }

    var sliderLabelColor: Color {
        switch self {
        case .regular:
            .white.opacity(0.72)
        case .compact:
            .primary.opacity(0.58)
        }
    }
}

struct MoodScalePicker: View {
    let title: String?
    let prompt: String?
    @Binding var value: Int
    var onProgressChanged: ((CGFloat) -> Void)? = nil
    var isInteractive = true
    var style: MoodScalePickerStyle = .regular
    var lowerLabel = "Very Bad"
    var upperLabel = "Very Good"
    var showsSlider = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var liveProgress: CGFloat
    @State private var isDragging = false

    init(
        title: String?,
        prompt: String?,
        value: Binding<Int>,
        onProgressChanged: ((CGFloat) -> Void)? = nil,
        isInteractive: Bool = true,
        style: MoodScalePickerStyle = .regular,
        lowerLabel: String = "Very Bad",
        upperLabel: String = "Very Good",
        showsSlider: Bool = true
    ) {
        self.title = title
        self.prompt = prompt
        _value = value
        self.onProgressChanged = onProgressChanged
        self.isInteractive = isInteractive
        self.style = style
        self.lowerLabel = lowerLabel
        self.upperLabel = upperLabel
        self.showsSlider = showsSlider
        _liveProgress = State(initialValue: CGFloat(min(max(value.wrappedValue, 1), 5) - 1) / 4)
    }

    private var clampedValue: Int {
        min(max(value, 1), 5)
    }

    private var normalizedValue: CGFloat {
        CGFloat(clampedValue - 1) / 4
    }

    private var displayProgress: CGFloat {
        min(max(isInteractive ? liveProgress : normalizedValue, 0), 1)
    }

    @ViewBuilder
    private var selectionLabel: some View {
        Text(LiftMoodPalette.title(for: clampedValue))
            .font(style.valueFont)
            .frame(maxWidth: .infinity, alignment: .center)
            .multilineTextAlignment(.center)
            .minimumScaleFactor(0.75)
            .transaction { transaction in
                transaction.animation = nil
            }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: style.verticalSpacing) {
            if let title {
                Text(title)
                    .font(style.titleFont)
                    .frame(maxWidth: .infinity, alignment: style.isRegular ? .center : .leading)
                    .multilineTextAlignment(style.isRegular ? .center : .leading)
            }

            if let prompt {
                Text(prompt)
                    .font(style.bodyFont)
                    .foregroundStyle(style.bodyColor)
                    .frame(maxWidth: .infinity, alignment: style.isRegular ? .center : .leading)
                    .multilineTextAlignment(style.isRegular ? .center : .leading)
            }

            if style.valuePlacement == .aboveOrb {
                selectionLabel
            }

            MoodOrb(progress: displayProgress, style: style)
                .frame(maxWidth: .infinity)

            if style.valuePlacement == .belowOrb {
                selectionLabel
            }

            if showsSlider {
                MoodStepSlider(
                    progress: Binding(
                        get: { displayProgress },
                        set: { newValue in
                            let clampedProgress = min(max(newValue, 0), 1)
                            liveProgress = clampedProgress
                            value = LiftMoodPalette.level(for: clampedProgress)
                        }
                    ),
                    lowerLabel: lowerLabel,
                    upperLabel: upperLabel,
                    isInteractive: isInteractive,
                    style: style,
                    onEditingChanged: { editing in
                        isDragging = editing
                    }
                )
            }
        }
        .padding(style.contentPadding)
        .onAppear {
            onProgressChanged?(displayProgress)
        }
        .onChange(of: displayProgress) { _, newValue in
            onProgressChanged?(newValue)
        }
        .onChange(of: value) { _, newValue in
            guard !isDragging else { return }
            liveProgress = CGFloat(min(max(newValue, 1), 5) - 1) / 4
        }
        .animation(LiftMotion.selection(reduceMotion), value: displayProgress)
    }
}

private struct MoodOrb: View {
    let progress: CGFloat
    let style: MoodScalePickerStyle
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var selectedColor: Color {
        LiftMoodPalette.color(for: progress)
    }

    var body: some View {
        Group {
            if reduceMotion {
                orbBody(at: 0)
            } else {
                TimelineView(.animation(minimumInterval: style.isRegular ? (1.0 / 28.0) : (1.0 / 24.0), paused: false)) { timeline in
                    orbBody(at: timeline.date.timeIntervalSinceReferenceDate)
                }
            }
        }
    }

    @ViewBuilder
    private func orbBody(at time: TimeInterval) -> some View {
        let pulse = 0.5 + (0.5 * sin(time * 1.02))
        let glowScale = 1 + (0.08 * sin(time * 0.72))
        let auraPulseScale = 1 + (0.04 * sin(time * 0.94))
        let badSideProgress = max(0, (0.5 - progress) / 0.5)
        let easedBadProgress = smoothstep(badSideProgress)
        let ringMotion = 0.108 * pow(easedBadProgress, 0.92)
        let coreMotion = 0.068 * pow(easedBadProgress, 0.90)
        let coreBottomPoke = 0.074 * pow(easedBadProgress, 1.04)
        let auraProgress = min(max(0.5 + ((progress - 0.5) * 0.84), 0), 1)
        let glassMotionAmount = style.orbSize * (style.isRegular ? 0.034 : 0.026) * easedBadProgress
        let glassOffset = CGFloat(sin(time * 0.58)) * glassMotionAmount
        let secondaryGlassOffset = CGFloat(cos(time * 0.42)) * glassMotionAmount * 0.75
        let coreRotation = (-3.8 * Double(easedBadProgress))
            + (sin((time * 1.04) + 0.4) * Double(easedBadProgress) * 1.7)
        let coreContour = MoodContourShape(
            progress: progress,
            motionTime: (time * 0.92) + (Double(easedBadProgress) * 1.15),
            motionAmount: coreMotion,
            bottomPokeAmount: coreBottomPoke
        )
        let auraContour = MoodContourShape(
            progress: auraProgress,
            motionTime: time * 0.46,
            motionAmount: coreMotion * 0.34
        )

        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            selectedColor.opacity(style.isRegular ? 0.24 : 0.14),
                            selectedColor.opacity(style.isRegular ? 0.08 : 0.03),
                            .clear
                        ],
                        center: .center,
                        startRadius: style.orbSize * 0.16,
                        endRadius: style.orbFrameSize * 0.54
                    )
                )
                .frame(
                    width: style.orbFrameSize * 1.02 * glowScale,
                    height: style.orbFrameSize * 1.02 * glowScale
                )
                .blur(radius: style.isRegular ? 22 : 14)
                .opacity(style.isRegular ? (0.88 + (pulse * 0.16)) : (0.86 + (pulse * 0.12)))

            ForEach(Array(style.ringSizes.enumerated()), id: \.offset) { index, ringSize in
                let fillOpacity = style.isRegular
                    ? [0.02, 0.05, 0.10, 0.18][index]
                    : max(0.09 - (Double(index) * 0.018), 0.03)
                let strokeOpacity = style.isRegular
                    ? [0.16, 0.22, 0.34, 0.50][index]
                    : max(0.22 - (Double(index) * 0.05), 0.07)
                let ringRotation = (style.isRegular ? Double(index) * 4 : Double(index) * 8)
                    - (Double(progress) * (style.isRegular ? 6 : 10))
                    + ((index.isMultiple(of: 2) ? 1 : -1) * time * (style.isRegular ? 3.4 : 4.8))
                let currentMotion = ringMotion + (easedBadProgress * CGFloat(index) * 0.012)
                let ringPulseScale = 1 + (CGFloat(0.018 + (Double(index) * 0.008)) * CGFloat(sin((time * 1.18) + (Double(index) * 0.82))))
                let contour = MoodContourShape(
                    progress: progress,
                    motionTime: time + Double(index) * 0.73,
                    motionAmount: currentMotion
                )

                contour
                    .fill(selectedColor.opacity(fillOpacity))
                    .overlay(
                        contour
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        .white.opacity(strokeOpacity * 1.15),
                                        .white.opacity(strokeOpacity * 0.42),
                                        selectedColor.opacity(strokeOpacity * 0.72)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: style.isRegular ? (index == 0 ? 1.5 : 2) : 2
                            )
                    )
                    .overlay(
                        contour
                            .stroke(selectedColor.opacity(fillOpacity * 1.8), lineWidth: style.isRegular ? 8 : 5)
                            .blur(radius: style.isRegular ? 10 : 6)
                            .opacity(style.isRegular ? 0.36 : 0.28)
                    )
                    .frame(width: ringSize, height: ringSize)
                    .rotationEffect(.degrees(ringRotation))
                    .scaleEffect(ringPulseScale)
                    .opacity(0.88 + (pulse * 0.12))
            }

            auraContour
                .fill(
                    RadialGradient(
                        colors: [
                            .white.opacity(style.isRegular ? 0.34 : 0.18),
                            selectedColor.opacity(style.isRegular ? 0.56 : 0.30),
                            .clear
                        ],
                        center: .center,
                        startRadius: 8,
                        endRadius: style.orbFrameSize * 0.42
                    )
                )
                .overlay(
                    auraContour
                        .stroke(
                            LinearGradient(
                                colors: [
                                    .white.opacity(style.isRegular ? 0.28 : 0.16),
                                    .white.opacity(0.02),
                                    selectedColor.opacity(style.isRegular ? 0.12 : 0.08)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: style.isRegular ? 1.6 : 1
                        )
                        .blur(radius: style.isRegular ? 4 : 2)
                )
                .frame(width: style.orbFrameSize * 0.86, height: style.orbFrameSize * 0.86)
                .blur(radius: style.isRegular ? 14 : 8)
                .opacity(0.86 + (pulse * 0.14))
                .scaleEffect(auraPulseScale)

            coreContour
                .fill(
                    RadialGradient(
                        colors: [
                            .white.opacity(0.92),
                            selectedColor.opacity(style.isRegular ? 0.74 : 0.85),
                            selectedColor.opacity(style.isRegular ? 0.22 : 0.18)
                        ],
                        center: .center,
                        startRadius: style.isRegular ? 12 : 6,
                        endRadius: style.orbSize * 0.52
                    )
                )
                .overlay {
                    ZStack {
                        Ellipse()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        .white.opacity(style.isRegular ? 0.46 : 0.28),
                                        .white.opacity(0.04)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(
                                width: style.orbSize * (style.isRegular ? 0.58 : 0.54),
                                height: style.orbSize * (style.isRegular ? 0.34 : 0.30)
                            )
                            .offset(
                                x: (-style.orbSize * 0.16) + glassOffset,
                                y: -style.orbSize * 0.19
                            )
                            .blur(radius: style.isRegular ? 8 : 5)

                        Ellipse()
                            .fill(.white.opacity(style.isRegular ? 0.18 : 0.12))
                            .frame(
                                width: style.orbSize * (style.isRegular ? 0.72 : 0.66),
                                height: style.orbSize * (style.isRegular ? 0.24 : 0.22)
                            )
                            .offset(
                                x: (style.orbSize * 0.10) - glassOffset,
                                y: (style.orbSize * 0.17) + secondaryGlassOffset
                            )
                            .blur(radius: style.isRegular ? 18 : 10)
                    }
                    .blendMode(.screen)
                    .mask(coreContour)
                }
                .frame(width: style.orbSize, height: style.orbSize)
                .overlay(
                    coreContour
                        .stroke(
                            LinearGradient(
                                colors: [
                                    .white.opacity(style.isRegular ? 0.54 : 0.34),
                                    .white.opacity(style.isRegular ? 0.14 : 0.08),
                                    .white.opacity(style.isRegular ? 0.28 : 0.18)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: style.isRegular ? 2.2 : 1.5
                        )
                        .blendMode(.screen)
                )
                .overlay(
                    coreContour
                        .stroke(selectedColor.opacity(style.isRegular ? 0.28 : 0.20), lineWidth: style.isRegular ? 10 : 6)
                        .blur(radius: style.isRegular ? 12 : 7)
                        .opacity(style.isRegular ? 0.30 : 0.24)
                )
                .shadow(color: selectedColor.opacity(style.isRegular ? 0.36 : 0.26), radius: style.isRegular ? 46 : 30, y: style.isRegular ? 14 : 8)
                .rotationEffect(.degrees(coreRotation))

            Circle()
                .fill(.regularMaterial)
                .frame(
                    width: style.isRegular ? 18 : style.orbSize * 0.07,
                    height: style.isRegular ? 18 : style.orbSize * 0.07
                )
                .overlay(
                    Circle()
                        .strokeBorder(.white.opacity(style.isRegular ? 0.24 : 0.12), lineWidth: 1)
                )
        }
        .frame(width: style.orbFrameSize, height: style.orbFrameSize)
    }

    private func smoothstep(_ value: CGFloat) -> CGFloat {
        let clamped = min(max(value, 0), 1)
        return clamped * clamped * (3 - (2 * clamped))
    }
}

private struct MoodContourShape: Shape {
    var progress: CGFloat
    var motionTime: TimeInterval = 0
    var motionAmount: CGFloat = 0
    var bottomPokeAmount: CGFloat = 0

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let boundedProgress = min(max(progress, 0), 1)
        let baseRadii = interpolatedRadii(progress: boundedProgress)
        let count = baseRadii.count
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let baseRadius = min(rect.width, rect.height) * 0.44
        let phase = Double(1 - boundedProgress) * 0.18
        let badSideProgress = max(0, (0.5 - boundedProgress) / 0.5)
        let stepAngle = (Double.pi * 2) / Double(count)
        var points: [CGPoint] = []
        points.reserveCapacity(count)

        for (index, radiusScale) in baseRadii.enumerated() {
            let baseAngle = (Double(index) * stepAngle) - (.pi / 2)
            let angleOffset = chaosAngleOffset(for: index) * Double(badSideProgress)
            let angle = baseAngle + phase + angleOffset
            let dynamicOffset = animatedOffset(for: index, angle: angle, progress: boundedProgress)
            let radius = baseRadius * (radiusScale + dynamicOffset)
            let point = CGPoint(
                x: center.x + CGFloat(cos(angle)) * radius,
                y: center.y + CGFloat(sin(angle)) * radius
            )
            points.append(point)
        }

        var path = Path()
        guard let firstPoint = points.first else { return path }
        let start = midpoint(between: points[count - 1], and: firstPoint)
        path.move(to: start)

        for index in 0..<count {
            let current = points[index]
            let next = points[(index + 1) % count]
            let mid = midpoint(between: current, and: next)
            path.addQuadCurve(to: mid, control: current)
        }

        path.closeSubpath()
        return path
    }

    private func interpolatedRadii(progress: CGFloat) -> [CGFloat] {
        let bad: [CGFloat] = [1.28, 0.70, 1.08, 1.02, 1.22, 0.76, 0.88, 1.12, 1.19, 0.80]
        let neutral = Array(repeating: CGFloat(1), count: bad.count)
        let good: [CGFloat] = [1.18, 0.78, 1.18, 0.80, 1.18, 0.77, 1.18, 0.81, 1.18, 0.79]

        if progress <= 0.5 {
            let transition = progress / 0.5
            return zip(bad, neutral).map { start, end in
                start + ((end - start) * transition)
            }
        }

        let transition = (progress - 0.5) / 0.5
        return zip(neutral, good).map { start, end in
            start + ((end - start) * transition)
        }
    }

    private func chaosAngleOffset(for index: Int) -> Double {
        let offsets: [Double] = [0.02, 0.10, -0.07, 0.14, -0.11, 0.05, -0.15, 0.10, -0.08, 0.07]
        return offsets[index % offsets.count]
    }

    private func animatedOffset(for index: Int, angle: Double, progress: CGFloat) -> CGFloat {
        guard motionAmount > 0 || bottomPokeAmount > 0 else { return 0 }

        let wobble = sin((motionTime * 0.82) + (Double(index) * 0.58) + (angle * 1.08))
        let counterWobble = cos((motionTime * 1.14) - (Double(index) * 0.37) + (angle * 1.72))
        let tertiaryWobble = sin((motionTime * 1.46) + (Double(index) * 0.91) - (angle * 2.08))
        let shapeBias = 0.32 + ((1 - progress) * 0.92)
        let baseOffset = CGFloat((wobble * 0.56) + (counterWobble * 0.30) + (tertiaryWobble * 0.14)) * motionAmount * shapeBias
        let downwardBias = pow(max(0, sin(angle)), 3.1)
        let bottomWave = 0.5 + (0.5 * sin((motionTime * 1.84) - 0.72 + (Double(index) * 0.16)))
        let bottomSurge = pow(bottomWave, 1.9)
        let bottomPoke = CGFloat(downwardBias * bottomSurge) * bottomPokeAmount

        return baseOffset + bottomPoke
    }

    private func midpoint(between first: CGPoint, and second: CGPoint) -> CGPoint {
        CGPoint(
            x: (first.x + second.x) / 2,
            y: (first.y + second.y) / 2
        )
    }
}

private struct MoodStepSlider: View {
    @Binding var progress: CGFloat
    let lowerLabel: String
    let upperLabel: String
    let isInteractive: Bool
    let style: MoodScalePickerStyle
    let onEditingChanged: (Bool) -> Void

    var body: some View {
        VStack(spacing: 12) {
            GeometryReader { geometry in
                let width = geometry.size.width
                let knobSize = style.sliderKnobSize
                let trackHeight = style.sliderTrackHeight
                let travelWidth = max(width - knobSize, 1)
                let clampedProgress = min(max(progress, 0), 1)
                let knobOffset = clampedProgress * travelWidth
                let fillWidth = knobOffset + (knobSize / 2)

                ZStack(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    .white.opacity(style.isRegular ? 0.14 : 0.12),
                                    .white.opacity(style.isRegular ? 0.08 : 0.08)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: trackHeight)
                        .overlay(
                            Capsule(style: .continuous)
                                .strokeBorder(.white.opacity(style.isRegular ? 0.04 : 0.05))
                        )

                    if style.usesFilledSliderTrack {
                        Capsule(style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: (1...5).map(LiftMoodPalette.color(for:)),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(fillWidth, knobSize / 2), height: trackHeight)
                            .mask(alignment: .leading) {
                                Capsule(style: .continuous)
                                    .frame(width: max(fillWidth, knobSize / 2), height: trackHeight)
                            }
                    }

                    Circle()
                        .fill(.white)
                        .frame(width: knobSize, height: knobSize)
                        .shadow(color: .black.opacity(style.isRegular ? 0.20 : 0.14), radius: style.isRegular ? 14 : 8, y: style.isRegular ? 8 : 4)
                        .offset(x: knobOffset)
                }
                .frame(height: max(knobSize, trackHeight))
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { gesture in
                            guard isInteractive else { return }
                            onEditingChanged(true)
                            updateProgress(for: gesture.location.x, width: width)
                        }
                        .onEnded { gesture in
                            guard isInteractive else { return }
                            updateProgress(for: gesture.location.x, width: width)
                            onEditingChanged(false)
                        }
                )
            }
            .frame(height: style.sliderKnobSize)

            HStack {
                Text(lowerLabel.uppercased())
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .layoutPriority(1)

                Text(upperLabel.uppercased())
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .layoutPriority(1)
            }
            .font(style.sliderLabelFont)
            .foregroundStyle(style.sliderLabelColor)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Mood")
        .accessibilityValue(LiftMoodPalette.title(for: progress))
        .accessibilityAdjustableAction { direction in
            guard isInteractive else { return }

            switch direction {
            case .increment:
                progress = min(progress + 0.25, 1)
            case .decrement:
                progress = max(progress - 0.25, 0)
            @unknown default:
                break
            }
        }
    }

    private func updateProgress(for locationX: CGFloat, width: CGFloat) {
        let knobSize = style.sliderKnobSize
        let boundedX = min(max(locationX - (knobSize / 2), 0), max(width - knobSize, 0))
        let rawProgress = boundedX / max(width - knobSize, 1)

        if rawProgress < 0.08 {
            progress = 0
        } else if rawProgress > 0.92 {
            progress = 1
        } else {
            progress = rawProgress
        }
    }
}

#Preview {
    @Previewable @State var value = 3

    return MoodScalePicker(
        title: "State of Body",
        prompt: "Capture your overall tone in a way that stays light and fast.",
        value: $value
    )
    .padding()
    .background(Color.liftSurface)
}
