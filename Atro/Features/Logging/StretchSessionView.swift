import Observation
import SwiftUI

private enum StretchTimerLimits {
    static let maximumDurationMinutes = 120
    static let maximumDurationSeconds = maximumDurationMinutes * 60
}

struct StretchTimerConfiguration: Identifiable, Hashable, Sendable {
    let id: UUID
    let title: String
    let initialTotalDurationSeconds: Int
    let initialIntervalSeconds: Int

    init(
        id: UUID = UUID(),
        title: String = "Stretch",
        totalDurationSeconds: Int = 10 * 60,
        intervalSeconds: Int = 30
    ) {
        self.id = id
        self.title = title
        self.initialTotalDurationSeconds = min(max(totalDurationSeconds, 0), StretchTimerLimits.maximumDurationSeconds)
        self.initialIntervalSeconds = max(intervalSeconds, 15)
    }

    init(
        title: String = "Stretch",
        intervalSeconds: Int = 30,
        roundCount: Int = 8
    ) {
        let safeInterval = max(intervalSeconds, 15)
        let safeRounds = max(roundCount, 1)

        self.init(
            title: title,
            totalDurationSeconds: safeInterval * safeRounds,
            intervalSeconds: safeInterval
        )
    }

    init(
        id: UUID = UUID(),
        title: String = "Stretch",
        steps: [GuidedStretchStep]
    ) {
        let durations = steps.map(\.durationSeconds).filter { $0 > 0 }
        self.init(
            id: id,
            title: title,
            totalDurationSeconds: durations.reduce(0, +),
            intervalSeconds: durations.first ?? 30
        )
    }

    static let quickStart = StretchTimerConfiguration()
}

@MainActor
@Observable
final class StretchTimerController {
    private(set) var totalDurationSeconds: Int
    private(set) var intervalDurationSeconds: Int
    private(set) var totalRemainingSeconds: Int
    private(set) var intervalRemainingSeconds: Int
    private(set) var elapsedSeconds = 0
    private(set) var isActive = false
    private(set) var isPaused = false
    private(set) var isFinished = false

    @ObservationIgnored private let cuePlayer: any StretchCuePlaying
    @ObservationIgnored private var timerTask: Task<Void, Never>?

    init(
        totalDurationSeconds: Int,
        intervalDurationSeconds: Int,
        cuePlayer: (any StretchCuePlaying)? = nil
    ) {
        let safeTotalDuration = min(max(totalDurationSeconds, 0), StretchTimerLimits.maximumDurationSeconds)
        let safeIntervalDuration = max(intervalDurationSeconds, 15)

        self.totalDurationSeconds = safeTotalDuration
        self.intervalDurationSeconds = safeIntervalDuration
        self.totalRemainingSeconds = safeTotalDuration
        self.intervalRemainingSeconds = min(safeIntervalDuration, max(safeTotalDuration, 0))
        self.cuePlayer = cuePlayer ?? StretchCuePlayer()
    }

    var sessionProgress: CGFloat {
        guard totalDurationSeconds > 0 else { return 0 }
        return min(max(CGFloat(elapsedSeconds) / CGFloat(totalDurationSeconds), 0), 1)
    }

    func configure(totalDurationSeconds: Int, intervalDurationSeconds: Int) {
        cancelTimer(stopCue: true)
        let safeTotalDuration = min(max(totalDurationSeconds, 0), StretchTimerLimits.maximumDurationSeconds)
        let safeIntervalDuration = max(intervalDurationSeconds, 15)

        self.totalDurationSeconds = safeTotalDuration
        self.intervalDurationSeconds = safeIntervalDuration
        self.totalRemainingSeconds = safeTotalDuration
        self.intervalRemainingSeconds = min(safeIntervalDuration, max(safeTotalDuration, 0))
        self.elapsedSeconds = 0
        self.isActive = false
        self.isPaused = false
        self.isFinished = false
    }

    func start() {
        guard totalDurationSeconds > 0 else { return }

        configure(totalDurationSeconds: totalDurationSeconds, intervalDurationSeconds: intervalDurationSeconds)
        cuePlayer.stop()
        isActive = true
        beginTimerLoop()
    }

    func pause() {
        guard isActive, !isFinished else { return }
        isPaused = true
    }

    func resume() {
        guard isActive, !isFinished else { return }
        isPaused = false
    }

    func stop() {
        cancelTimer(stopCue: true)
        totalRemainingSeconds = totalDurationSeconds
        intervalRemainingSeconds = min(intervalDurationSeconds, max(totalDurationSeconds, 0))
        elapsedSeconds = 0
        isActive = false
        isPaused = false
        isFinished = false
    }

    func tick() {
        guard isActive, !isPaused, !isFinished, totalDurationSeconds > 0 else {
            return
        }

        guard totalRemainingSeconds > 1 else {
            totalRemainingSeconds = 0
            intervalRemainingSeconds = 0
            elapsedSeconds = totalDurationSeconds
            cuePlayer.playTransitionCue(isFinalStep: true)
            isActive = false
            isPaused = false
            isFinished = true
            cancelTimer(stopCue: false)
            return
        }

        totalRemainingSeconds -= 1
        elapsedSeconds = min(elapsedSeconds + 1, totalDurationSeconds)

        if intervalRemainingSeconds <= 1 {
            cuePlayer.playTransitionCue(isFinalStep: false)
            intervalRemainingSeconds = min(intervalDurationSeconds, totalRemainingSeconds)
            return
        }

        intervalRemainingSeconds -= 1

        if (1...5).contains(intervalRemainingSeconds) {
            cuePlayer.playCountdownCue(remainingSeconds: intervalRemainingSeconds)
        }
    }

    private func beginTimerLoop() {
        cancelTimer(stopCue: false)
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .seconds(1))
                } catch {
                    break
                }

                guard !Task.isCancelled else {
                    break
                }

                self?.tick()
            }
        }
    }

    private func cancelTimer(stopCue: Bool) {
        timerTask?.cancel()
        timerTask = nil

        if stopCue {
            cuePlayer.stop()
        }
    }
}

struct StretchSessionView: View {
    let configuration: StretchTimerConfiguration
    let settings: AppSettings?
    let onClose: () -> Void
    private let sourceDraft: WorkoutSessionDraft?
    private let plannedWorkout: PlannedWorkout?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(AppModel.self) private var appModel

    @Namespace private var actionNamespace
    @State private var controller: StretchTimerController
    @State private var selectedTotalDurationSeconds: Int
    @State private var intervalUnit: StretchIntervalUnit
    @State private var intervalValue: Int
    @State private var showsIntervalPicker = false
    @State private var pendingLogSummary: StretchSessionLogSummary?
    @State private var isSavingLog = false

    init(
        configuration: StretchTimerConfiguration = .quickStart,
        settings: AppSettings? = nil,
        sourceDraft: WorkoutSessionDraft? = nil,
        plannedWorkout: PlannedWorkout? = nil,
        onClose: @escaping () -> Void
    ) {
        self.configuration = configuration
        self.settings = settings
        self.sourceDraft = sourceDraft
        self.plannedWorkout = plannedWorkout
        self.onClose = onClose

        let intervalSelection = StretchIntervalUnit.selection(for: configuration.initialIntervalSeconds)
        let normalizedTotalDuration = min(
            max(Int((Double(configuration.initialTotalDurationSeconds) / 60).rounded()) * 60, 0),
            StretchTimerLimits.maximumDurationSeconds
        )
        _controller = State(
            initialValue: StretchTimerController(
                totalDurationSeconds: normalizedTotalDuration,
                intervalDurationSeconds: configuration.initialIntervalSeconds
            )
        )
        _selectedTotalDurationSeconds = State(initialValue: normalizedTotalDuration)
        _intervalUnit = State(initialValue: intervalSelection.unit)
        _intervalValue = State(initialValue: intervalSelection.value)
    }

    init(
        draft: WorkoutSessionDraft,
        settings: AppSettings,
        plannedWorkout: PlannedWorkout? = nil,
        onClose: @escaping () -> Void
    ) {
        let title = draft.workoutName.trimmingCharacters(in: .whitespacesAndNewlines)
        let steps = draft.exercises.map(GuidedStretchStep.init(exercise:))
        let configuration = StretchTimerConfiguration(
            title: title.isEmpty ? "Stretch" : title,
            steps: steps.isEmpty ? [GuidedStretchStep(id: UUID(), title: "", instructions: "", durationSeconds: 30)] : steps
        )

        self.init(
            configuration: configuration,
            settings: settings,
            sourceDraft: draft,
            plannedWorkout: plannedWorkout,
            onClose: onClose
        )
    }

    private var selectedIntervalSeconds: Int {
        intervalUnit.seconds(for: intervalValue)
    }

    private var intervalDisplayText: String {
        StretchDisplayFormatter.intervalSelectionLabel(seconds: selectedIntervalSeconds)
    }

    private var selectedTotalDurationMinutes: Int {
        StretchDurationDialModel.minutes(for: selectedTotalDurationSeconds)
    }

    private var selectedTotalDurationMinutesBinding: Binding<Int> {
        Binding(
            get: { selectedTotalDurationMinutes },
            set: { newMinutes in
                selectedTotalDurationSeconds = StretchDurationDialModel.seconds(for: newMinutes)
            }
        )
    }

    private var overallStatusText: String {
        if pendingLogSummary != nil {
            return "Ready to log stretch"
        }

        if controller.isFinished {
            return "Stretch complete"
        }

        if controller.isActive || controller.isPaused {
            return "Overall \(StretchDisplayFormatter.clockString(for: controller.totalRemainingSeconds)) remaining"
        }

        return "Choose your stretch session"
    }

    private var supportingText: String {
        if let pendingLogSummary {
            return pendingLogSummary.summaryLine
        }

        if controller.isFinished {
            return "A calm final tone marked the end of your stretch."
        }

        if controller.isActive || controller.isPaused {
            return controller.isPaused
                ? "Paused right where you left it."
                : "Soft ticks begin in the last five seconds, then the final cue tells you to switch."
        }

        return "Scroll to set your total time, then tap the center timer to choose your switch cue."
    }

    private var orbProgress: CGFloat {
        if pendingLogSummary != nil {
            return 1
        }

        if controller.isFinished {
            return 1
        }

        if controller.isActive || controller.isPaused {
            return min(max(0.36 + (controller.sessionProgress * 0.64), 0), 1)
        }

        return min(max(0.44 + (CGFloat(selectedTotalDurationSeconds) / CGFloat(StretchTimerLimits.maximumDurationSeconds) * 0.12), 0), 1)
    }

    private var orbTint: Color {
        LiftMoodPalette.color(for: orbProgress)
    }

    private var actionTint: Color {
        controller.isActive || controller.isPaused || controller.isFinished || pendingLogSummary != nil
            ? orbTint
            : Color(red: 0.72, green: 0.78, blue: 0.86)
    }

    private var primaryButtonTitle: String {
        pendingLogSummary != nil ? "Log Stretch" : (controller.isFinished ? "Start Again" : "Start")
    }

    private var centerHeadline: String {
        if let pendingLogSummary {
            return pendingLogSummary.activeTimeDescription
        }

        if controller.isFinished {
            return "Done"
        }

        if controller.isActive || controller.isPaused {
            return StretchDisplayFormatter.clockString(for: controller.intervalRemainingSeconds)
        }

        return intervalDisplayText
    }

    private var centerSubheadline: String {
        if pendingLogSummary != nil {
            return "Active Time"
        }

        if controller.isFinished {
            return "Session"
        }

        if controller.isActive {
            return "Switch In"
        }

        if controller.isPaused {
            return "Paused"
        }

        return "Tap To Edit"
    }

    private var isRunningState: Bool {
        controller.isActive || controller.isPaused
    }

    private var isPostRunState: Bool {
        pendingLogSummary != nil
    }

    private var allowsLogging: Bool {
        settings != nil
    }

    var body: some View {
        GeometryReader { geometry in
            let safeTop = geometry.safeAreaInsets.top
            let safeBottom = geometry.safeAreaInsets.bottom
            let compactLayout = geometry.size.height < 900
            let extraCompactLayout = geometry.size.height < 820
            let headerWidth: CGFloat = extraCompactLayout ? 340 : (compactLayout ? 360 : 420)

            ZStack {
                stretchBackdrop

                VStack(spacing: 0) {
                    topBar

                    Spacer(minLength: extraCompactLayout ? 8 : (compactLayout ? 12 : 22))

                    Text(overallStatusText)
                        .font(.system(size: extraCompactLayout ? 28 : (compactLayout ? 30 : 34), weight: .black, design: .rounded))
                        .foregroundStyle(.white.opacity(0.96))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: headerWidth)
                        .minimumScaleFactor(0.76)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, compactLayout ? 10 : 0)

                    Text(supportingText)
                        .font(.system(size: extraCompactLayout ? 16 : 18, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.70))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: headerWidth)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 10)
                        .padding(.horizontal, compactLayout ? 12 : 6)

                    Spacer(minLength: extraCompactLayout ? 4 : (compactLayout ? 10 : 16))

                    orbSection
                        .scaleEffect(extraCompactLayout ? 0.82 : (compactLayout ? 0.92 : 1.05))

                    Spacer(minLength: extraCompactLayout ? 6 : (compactLayout ? 12 : 18))

                    StretchDurationWheel(
                        selectedMinutes: selectedTotalDurationMinutesBinding,
                        isInteractive: !isRunningState && !isPostRunState && !controller.isFinished,
                        tint: orbTint
                    )

                    Spacer(minLength: extraCompactLayout ? 10 : (compactLayout ? 16 : 22))

                    actionSection
                }
                .padding(.horizontal, 24)
                .padding(.top, safeTop + 8)
                .padding(.bottom, max(safeBottom, 16))
                .frame(maxWidth: 540, maxHeight: .infinity, alignment: .top)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .sheet(isPresented: $showsIntervalPicker) {
            StretchIntervalPickerSheet(
                intervalUnit: $intervalUnit,
                intervalValue: $intervalValue
            )
            .presentationDetents([.height(408)])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(28)
        }
        .onAppear {
            syncControllerConfiguration()
        }
        .onDisappear {
            controller.stop()
            pendingLogSummary = nil
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase != .active else { return }
            controller.pause()
        }
        .onChange(of: controller.isFinished) { _, isFinished in
            guard isFinished, allowsLogging, pendingLogSummary == nil else { return }
            pendingLogSummary = buildLogSummary(endedAt: .now)
        }
        .animation(LiftMotion.emphasis(reduceMotion), value: isRunningState)
        .animation(LiftMotion.selection(reduceMotion), value: controller.sessionProgress)
        .animation(LiftMotion.selection(reduceMotion), value: controller.isFinished)
    }

    private var stretchBackdrop: some View {
        ZStack {
            Color.black.opacity(0.56)
                .ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color(red: 0.06, green: 0.07, blue: 0.08),
                    Color(red: 0.04, green: 0.05, blue: 0.06)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [
                    orbTint.opacity(0.18),
                    .clear
                ],
                center: .center,
                startRadius: 20,
                endRadius: 420
            )
            .blur(radius: 24)
            .ignoresSafeArea()
        }
    }

    private var topBar: some View {
        HStack {
            Button {
                close()
            } label: {
                StretchChromeLabel(systemImage: "xmark")
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close stretch timer")

            Spacer()

            Text(configuration.title)
                .font(.lift(.headline, weight: .semibold))
                .foregroundStyle(.white.opacity(0.96))

            Spacer()

            Color.clear
                .frame(width: 52, height: 52)
        }
    }

    private var orbSection: some View {
        ZStack {
            StretchOrb(progress: orbProgress, tint: orbTint)
            StretchStarField(progress: orbProgress)
                .frame(width: MoodScalePickerStyle.regular.orbFrameSize, height: MoodScalePickerStyle.regular.orbFrameSize)

            Button {
                guard !isRunningState, !isPostRunState else { return }
                showsIntervalPicker = true
            } label: {
                VStack(spacing: 6) {
                    Text(centerHeadline)
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(.white.opacity(0.98))
                        .monospacedDigit()
                        .minimumScaleFactor(0.72)

                    Text(centerSubheadline.uppercased())
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.68))
                        .tracking(0.9)
                }
                .frame(width: 124, height: 124)
                .background {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.black.opacity(0.76),
                                    Color(red: 0.11, green: 0.12, blue: 0.14).opacity(0.94)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            Circle()
                                .strokeBorder(.white.opacity(0.16), lineWidth: 1.2)
                        )
                        .shadow(color: .black.opacity(0.32), radius: 18, y: 10)
                }
            }
            .buttonStyle(.plain)
            .disabled(isRunningState || isPostRunState)
            .accessibilityLabel("Switch interval")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
    }

    @ViewBuilder
    private var actionSection: some View {
        if isRunningState {
            HStack(spacing: 12) {
                Button {
                    stopTimer()
                } label: {
                    Text("Stop")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(
                    StretchActionButtonStyle(
                        tint: Color(red: 0.33, green: 0.36, blue: 0.38),
                        horizontalPadding: 0
                    )
                )
                .matchedGeometryEffect(id: "stretch-stop", in: actionNamespace)

                Button {
                    if controller.isPaused {
                        controller.resume()
                    } else {
                        controller.pause()
                    }
                } label: {
                    Text(controller.isPaused ? "Resume" : "Pause")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(
                    StretchActionButtonStyle(
                        tint: actionTint,
                        horizontalPadding: 0
                    )
                )
                .matchedGeometryEffect(id: "stretch-pause", in: actionNamespace)
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        } else if pendingLogSummary != nil {
            VStack(spacing: 12) {
                Button {
                    logStretch()
                } label: {
                    Text(isSavingLog ? "Logging..." : primaryButtonTitle)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(
                    StretchActionButtonStyle(
                        tint: actionTint,
                        intensity: isSavingLog ? 0.72 : 1,
                        glowStrength: isSavingLog ? 0.16 : 1,
                        verticalPadding: 16
                    )
                )
                .disabled(isSavingLog)
                .opacity(isSavingLog ? 0.72 : 1)

                Button {
                    restartTimer()
                } label: {
                    Text("Start Again")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(
                    StretchActionButtonStyle(
                        tint: Color(red: 0.33, green: 0.36, blue: 0.38),
                        intensity: 0.76,
                        glowStrength: 0.18,
                        verticalPadding: 14
                    )
                )
                .disabled(isSavingLog)
                .opacity(isSavingLog ? 0.62 : 1)
            }
            .transition(.scale(scale: 0.98).combined(with: .opacity))
        } else {
            Button {
                startTimer()
            } label: {
                Text(primaryButtonTitle)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(
                StretchActionButtonStyle(
                    tint: actionTint,
                    intensity: isStartDisabled ? 0.72 : 1,
                    glowStrength: isStartDisabled ? 0.16 : 1,
                    verticalPadding: 16
                )
            )
            .disabled(isStartDisabled)
            .opacity(isStartDisabled ? 0.62 : 1)
            .transition(.scale(scale: 0.98).combined(with: .opacity))
        }
    }

    private var isStartDisabled: Bool {
        !StretchDurationDialModel.canStart(minutes: selectedTotalDurationMinutes)
    }

    private func syncControllerConfiguration() {
        controller.configure(
            totalDurationSeconds: selectedTotalDurationSeconds,
            intervalDurationSeconds: selectedIntervalSeconds
        )
    }

    private func startTimer() {
        pendingLogSummary = nil
        syncControllerConfiguration()
        controller.start()
    }

    private func stopTimer() {
        if allowsLogging {
            pendingLogSummary = buildLogSummary(endedAt: .now)
        }
        controller.stop()
    }

    private func close() {
        controller.stop()
        pendingLogSummary = nil
        dismiss()
        onClose()
    }

    private func restartTimer() {
        pendingLogSummary = nil
        startTimer()
    }

    private func buildLogSummary(endedAt: Date) -> StretchSessionLogSummary? {
        WorkoutDraftFactory.stretchTimerLogSummary(
            title: configuration.title,
            intervalSeconds: controller.intervalDurationSeconds,
            elapsedSeconds: controller.elapsedSeconds,
            endedAt: endedAt,
            sourceDraft: sourceDraft
        )
    }

    private func logStretch() {
        guard !isSavingLog, let settings, let pendingLogSummary else {
            return
        }

        isSavingLog = true

        let viewModel = WorkoutSessionViewModel(draft: pendingLogSummary.draft, plannedWorkout: plannedWorkout)

        Task {
            defer { isSavingLog = false }

            do {
                _ = try await viewModel.finish(using: modelContext, settings: settings, appModel: appModel)
                dismiss()
                onClose()
            } catch {
                appModel.showBanner("Couldn’t save stretch", systemImage: "exclamationmark.triangle.fill")
            }
        }
    }
}

private enum StretchIntervalUnit: String, CaseIterable, Identifiable {
    case seconds
    case minutes

    var id: String { rawValue }

    var title: String {
        switch self {
        case .seconds:
            "Seconds"
        case .minutes:
            "Minutes"
        }
    }

    var values: [Int] {
        switch self {
        case .seconds:
            Array(stride(from: 15, through: 180, by: 15))
        case .minutes:
            Array(1...10)
        }
    }

    func seconds(for value: Int) -> Int {
        switch self {
        case .seconds:
            value
        case .minutes:
            value * 60
        }
    }

    static func selection(for seconds: Int) -> (unit: StretchIntervalUnit, value: Int) {
        let safeSeconds = max(seconds, 15)

        if safeSeconds.isMultiple(of: 60), (1...10).contains(safeSeconds / 60) {
            return (.minutes, safeSeconds / 60)
        }

        let normalizedSeconds = min(max(Int((Double(safeSeconds) / 15).rounded()) * 15, 15), 180)
        return (.seconds, normalizedSeconds)
    }
}

private enum StretchDisplayFormatter {
    static func clockString(for totalSeconds: Int) -> String {
        let minutes = max(totalSeconds, 0) / 60
        let seconds = max(totalSeconds, 0) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    static func durationSelectionLabel(seconds: Int) -> String {
        let minutes = max(seconds, 0) / 60

        if minutes == 1 {
            return "1 minute"
        }

        return "\(minutes) minutes"
    }

    static func intervalSelectionLabel(seconds: Int) -> String {
        if seconds.isMultiple(of: 60) {
            let minutes = seconds / 60
            return minutes == 1 ? "1 min" : "\(minutes) min"
        }

        return "\(seconds) sec"
    }
}

enum StretchDurationDialModel {
    static let maximumMinutes = StretchTimerLimits.maximumDurationMinutes
    static let supportedMinutes = Array(0...maximumMinutes)
    static let tickSlotWidth: CGFloat = 28
    static let tickViewportHeight: CGFloat = 56
    static let centerGuideWidth: CGFloat = 7
    static let centerGuideHeight: CGFloat = 44
    static let maximumWidth: CGFloat = 420
    static let coordinateSpaceName = "StretchDurationWheel"

    static func clampedMinute(_ minute: Int) -> Int {
        min(max(minute, 0), maximumMinutes)
    }

    static func minutes(for seconds: Int) -> Int {
        clampedMinute(Int((Double(max(seconds, 0)) / 60).rounded()))
    }

    static func seconds(for minute: Int) -> Int {
        clampedMinute(minute) * 60
    }

    static func readoutText(for minute: Int) -> String {
        StretchDisplayFormatter.clockString(for: seconds(for: minute))
    }

    static func canStart(minutes: Int) -> Bool {
        clampedMinute(minutes) > 0
    }

    static func isMajorTick(_ minute: Int) -> Bool {
        minute.isMultiple(of: 5)
    }

    static func emphasis(forDistance distance: CGFloat) -> CGFloat {
        let normalizedDistance = min(max(distance / (tickSlotWidth * 4.4), 0), 1)
        return 1 - pow(normalizedDistance, 0.72)
    }

    static func tickOpacity(for minute: Int, emphasis: CGFloat) -> CGFloat {
        let baseOpacity: CGFloat = isMajorTick(minute) ? 0.24 : 0.13
        return min(baseOpacity + (emphasis * 0.72), 0.96)
    }

    static func tickWidth(for minute: Int, emphasis: CGFloat) -> CGFloat {
        let baseWidth: CGFloat = isMajorTick(minute) ? 5 : 3
        let accentWidth: CGFloat = isMajorTick(minute) ? 2.4 : 1.8
        return baseWidth + (emphasis * accentWidth)
    }

    static func tickHeight(for minute: Int, emphasis: CGFloat) -> CGFloat {
        let baseHeight: CGFloat = isMajorTick(minute) ? 30 : 18
        let accentHeight: CGFloat = isMajorTick(minute) ? 12 : 10
        return baseHeight + (emphasis * accentHeight)
    }
}

private struct StretchChromeLabel: View {
    let systemImage: String

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 20, weight: .bold))
            .foregroundStyle(.white.opacity(0.94))
            .frame(width: 52, height: 52)
            .background(
                Circle()
                    .fill(.white.opacity(0.04))
            )
            .overlay(
                Circle()
                    .strokeBorder(.white.opacity(0.14), lineWidth: 1.2)
            )
    }
}

private struct StretchActionButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let tint: Color
    var intensity: CGFloat = 1
    var glowStrength: CGFloat = 1
    var horizontalPadding: CGFloat = 22
    var verticalPadding: CGFloat = 16

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 24, weight: .bold, design: .rounded))
            .foregroundStyle(.white.opacity(0.98))
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background {
                StretchLiquidGlassCapsule(
                    tint: tint,
                    intensity: intensity,
                    glowStrength: glowStrength
                )
            }
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.94 : 1)
            .animation(LiftMotion.press(reduceMotion), value: configuration.isPressed)
    }
}

private struct StretchLiquidGlassCapsule: View {
    let tint: Color
    var intensity: CGFloat = 1
    var glowStrength: CGFloat = 1

    var body: some View {
        Capsule(style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        tint.opacity(0.92 * intensity),
                        tint.opacity(0.76 * intensity)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                Capsule(style: .continuous)
                    .fill(.ultraThinMaterial)
                    .opacity(0.18 + (0.10 * intensity))
            )
            .overlay {
                ZStack {
                    Ellipse()
                        .fill(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.24 + (0.18 * intensity)),
                                    .white.opacity(0.03 + (0.03 * intensity)),
                                    .clear
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .scaleEffect(x: 0.86, y: 0.56, anchor: .top)
                        .offset(y: -14)
                        .blur(radius: 3)

                    Ellipse()
                        .fill(tint.opacity((0.10 + (0.12 * intensity)) * glowStrength))
                        .scaleEffect(x: 0.92, y: 0.72, anchor: .bottom)
                        .offset(y: 18)
                        .blur(radius: 14)
                }
                .blendMode(.screen)
                .clipShape(Capsule(style: .continuous))
            }
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.26 + (0.18 * intensity)),
                                .white.opacity(0.08 + (0.08 * intensity)),
                                tint.opacity(0.22 + (0.26 * intensity))
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.2
                    )
            )
            .shadow(color: tint.opacity((0.10 + (0.08 * intensity)) * glowStrength), radius: 18, y: 8)
            .shadow(color: .black.opacity(0.12 + (0.04 * intensity)), radius: 14, y: 10)
    }
}

private struct StretchDurationWheel: View {
    @Binding var selectedMinutes: Int

    let isInteractive: Bool
    let tint: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var scrollSelection: Int?

    private let settleAnimation = Animation.interactiveSpring(response: 0.28, dampingFraction: 0.84, blendDuration: 0.14)

    init(selectedMinutes: Binding<Int>, isInteractive: Bool, tint: Color) {
        _selectedMinutes = selectedMinutes
        self.isInteractive = isInteractive
        self.tint = tint
        _scrollSelection = State(initialValue: StretchDurationDialModel.clampedMinute(selectedMinutes.wrappedValue))
    }

    private var selectionAnimation: Animation? {
        reduceMotion ? nil : settleAnimation
    }

    var body: some View {
        GeometryReader { geometry in
            let sideInset = max((geometry.size.width - StretchDurationDialModel.tickSlotWidth) / 2, 0)
            let displayedMinutes = StretchDurationDialModel.clampedMinute(scrollSelection ?? selectedMinutes)

            VStack(spacing: 10) {
                VStack(spacing: 4) {
                    Text("Overall stretch time")
                        .font(.lift(.footnote, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.72))

                    Text(StretchDurationDialModel.readoutText(for: displayedMinutes))
                        .font(.system(size: 27, weight: .black, design: .rounded))
                        .foregroundStyle(.white.opacity(0.96))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

                ZStack {
                    ScrollView(.horizontal) {
                        LazyHStack(spacing: 0) {
                            ForEach(StretchDurationDialModel.supportedMinutes, id: \.self) { minute in
                                StretchDurationDialTick(
                                    minute: minute,
                                    tint: tint,
                                    viewportMidX: geometry.size.width / 2,
                                    isInteractive: isInteractive
                                ) {
                                    guard isInteractive else { return }

                                    withAnimation(selectionAnimation) {
                                        scrollSelection = minute
                                    }
                                }
                                .id(minute)
                            }
                        }
                        .scrollTargetLayout()
                        .padding(.horizontal, sideInset)
                    }
                    .scrollIndicators(.hidden)
                    .scrollClipDisabled()
                    .scrollTargetBehavior(.viewAligned)
                    .scrollPosition(id: $scrollSelection, anchor: .center)
                    .scrollDisabled(!isInteractive)
                    .coordinateSpace(name: StretchDurationDialModel.coordinateSpaceName)
                    .opacity(isInteractive ? 1 : 0.58)
                    .mask {
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0),
                                .init(color: .black, location: 0.12),
                                .init(color: .black, location: 0.88),
                                .init(color: .clear, location: 1)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    }

                    Capsule(style: .continuous)
                        .fill(.white.opacity(0.96))
                        .frame(
                            width: StretchDurationDialModel.centerGuideWidth,
                            height: StretchDurationDialModel.centerGuideHeight
                        )
                        .shadow(color: tint.opacity(0.28), radius: 12, y: 4)
                        .allowsHitTesting(false)
                }
                .frame(height: StretchDurationDialModel.tickViewportHeight)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .onAppear {
                scrollSelection = StretchDurationDialModel.clampedMinute(selectedMinutes)
            }
            .onChange(of: scrollSelection) { _, newValue in
                guard let newValue else { return }

                let clampedSelection = StretchDurationDialModel.clampedMinute(newValue)
                guard selectedMinutes != clampedSelection else { return }
                selectedMinutes = clampedSelection
            }
            .onChange(of: selectedMinutes) { _, newValue in
                let clampedSelection = StretchDurationDialModel.clampedMinute(newValue)
                guard scrollSelection != clampedSelection else { return }

                withAnimation(selectionAnimation) {
                    scrollSelection = clampedSelection
                }
            }
        }
        .frame(height: 102)
        .frame(maxWidth: StretchDurationDialModel.maximumWidth)
        .frame(maxWidth: .infinity)
    }
}

private struct StretchDurationDialTick: View {
    let minute: Int
    let tint: Color
    let viewportMidX: CGFloat
    let isInteractive: Bool
    let onTap: () -> Void

    var body: some View {
        GeometryReader { geometry in
            let frame = geometry.frame(in: .named(StretchDurationDialModel.coordinateSpaceName))
            let emphasis = StretchDurationDialModel.emphasis(forDistance: abs(frame.midX - viewportMidX))
            let tickOpacity = StretchDurationDialModel.tickOpacity(for: minute, emphasis: emphasis)
            let tickWidth = StretchDurationDialModel.tickWidth(for: minute, emphasis: emphasis)
            let tickHeight = StretchDurationDialModel.tickHeight(for: minute, emphasis: emphasis)

            Button(action: onTap) {
                Capsule(style: .continuous)
                    .fill(.white.opacity(tickOpacity))
                    .frame(width: tickWidth, height: tickHeight)
                    .shadow(color: tint.opacity(emphasis * 0.22), radius: 8, y: 3)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!isInteractive)
            .accessibilityLabel("\(minute) minutes")
        }
        .frame(
            width: StretchDurationDialModel.tickSlotWidth,
            height: StretchDurationDialModel.tickViewportHeight
        )
    }
}

private struct StretchIntervalPickerSheet: View {
    @Binding var intervalUnit: StretchIntervalUnit
    @Binding var intervalValue: Int

    @Environment(\.dismiss) private var dismiss
    @State private var draftUnit: StretchIntervalUnit
    @State private var draftValue: Int

    init(intervalUnit: Binding<StretchIntervalUnit>, intervalValue: Binding<Int>) {
        _intervalUnit = intervalUnit
        _intervalValue = intervalValue
        _draftUnit = State(initialValue: intervalUnit.wrappedValue)
        _draftValue = State(initialValue: intervalValue.wrappedValue)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Switch Interval")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text("Choose how often the stretch timer should cue you to switch.")
                    .font(.lift(.body))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 0) {
                    Picker("Value", selection: $draftValue) {
                        ForEach(draftUnit.values, id: \.self) { value in
                            Text(label(for: value))
                                .tag(value)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: .infinity)
                    .clipped()

                    Picker("Unit", selection: $draftUnit) {
                        ForEach(StretchIntervalUnit.allCases) { unit in
                            Text(unit.title)
                                .tag(unit)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: .infinity)
                    .clipped()
                }
                .frame(height: 176)
                .onChange(of: draftUnit) { _, newUnit in
                    if !newUnit.values.contains(draftValue) {
                        draftValue = newUnit.values.first ?? draftValue
                    }
                }

                Spacer(minLength: 16)

                Button {
                    intervalUnit = draftUnit
                    intervalValue = draftValue
                    dismiss()
                } label: {
                    Text("Set Interval")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background {
                            StretchLiquidGlassCapsule(
                                tint: Color(red: 0.70, green: 0.77, blue: 0.84)
                            )
                        }
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 20)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func label(for value: Int) -> String {
        switch draftUnit {
        case .seconds:
            "\(value) sec"
        case .minutes:
            value == 1 ? "1 min" : "\(value) min"
        }
    }
}

private struct StretchOrb: View {
    let progress: CGFloat
    let tint: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let style = MoodScalePickerStyle.regular

    var body: some View {
        Group {
            if reduceMotion {
                orbBody(at: 0)
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 28.0, paused: false)) { timeline in
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
        let glassMotionAmount = style.orbSize * 0.034 * easedBadProgress
        let glassOffset = CGFloat(sin(time * 0.58)) * glassMotionAmount
        let secondaryGlassOffset = CGFloat(cos(time * 0.42)) * glassMotionAmount * 0.75
        let coreRotation = (-3.8 * Double(easedBadProgress))
            + (sin((time * 1.04) + 0.4) * Double(easedBadProgress) * 1.7)
        let coreContour = StretchContourShape(
            progress: progress,
            motionTime: (time * 0.92) + (Double(easedBadProgress) * 1.15),
            motionAmount: coreMotion,
            bottomPokeAmount: coreBottomPoke
        )
        let auraContour = StretchContourShape(
            progress: auraProgress,
            motionTime: time * 0.46,
            motionAmount: coreMotion * 0.34
        )

        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            tint.opacity(0.24),
                            tint.opacity(0.08),
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
                .blur(radius: 22)
                .opacity(0.88 + (pulse * 0.16))

            ForEach(Array(style.ringSizes.enumerated()), id: \.offset) { index, ringSize in
                let fillOpacity = [0.02, 0.05, 0.10, 0.18][index]
                let strokeOpacity = [0.16, 0.22, 0.34, 0.50][index]
                let ringRotation = (Double(index) * 4)
                    - (Double(progress) * 6)
                    + ((index.isMultiple(of: 2) ? 1 : -1) * time * 3.4)
                let currentMotion = ringMotion + (easedBadProgress * CGFloat(index) * 0.012)
                let ringPulseScale = 1 + (CGFloat(0.018 + (Double(index) * 0.008)) * CGFloat(sin((time * 1.18) + (Double(index) * 0.82))))
                let contour = StretchContourShape(
                    progress: progress,
                    motionTime: time + Double(index) * 0.73,
                    motionAmount: currentMotion
                )

                contour
                    .fill(tint.opacity(fillOpacity))
                    .overlay(
                        contour
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        .white.opacity(strokeOpacity * 1.15),
                                        .white.opacity(strokeOpacity * 0.42),
                                        tint.opacity(strokeOpacity * 0.72)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: index == 0 ? 1.5 : 2
                            )
                    )
                    .overlay(
                        contour
                            .stroke(tint.opacity(fillOpacity * 1.8), lineWidth: 8)
                            .blur(radius: 10)
                            .opacity(0.36)
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
                            .white.opacity(0.34),
                            tint.opacity(0.56),
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
                                    .white.opacity(0.28),
                                    .white.opacity(0.02),
                                    tint.opacity(0.12)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.6
                        )
                        .blur(radius: 4)
                )
                .frame(width: style.orbFrameSize * 0.86, height: style.orbFrameSize * 0.86)
                .blur(radius: 14)
                .opacity(0.86 + (pulse * 0.14))
                .scaleEffect(auraPulseScale)

            coreContour
                .fill(
                    RadialGradient(
                        colors: [
                            .white.opacity(0.92),
                            tint.opacity(0.74),
                            tint.opacity(0.22)
                        ],
                        center: .center,
                        startRadius: 12,
                        endRadius: style.orbSize * 0.52
                    )
                )
                .overlay {
                    ZStack {
                        Ellipse()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        .white.opacity(0.46),
                                        .white.opacity(0.04)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(
                                width: style.orbSize * 0.58,
                                height: style.orbSize * 0.34
                            )
                            .offset(
                                x: (-style.orbSize * 0.16) + glassOffset,
                                y: -style.orbSize * 0.19
                            )
                            .blur(radius: 8)

                        Ellipse()
                            .fill(.white.opacity(0.18))
                            .frame(
                                width: style.orbSize * 0.72,
                                height: style.orbSize * 0.24
                            )
                            .offset(
                                x: (style.orbSize * 0.10) - glassOffset,
                                y: (style.orbSize * 0.17) + secondaryGlassOffset
                            )
                            .blur(radius: 18)
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
                                    .white.opacity(0.54),
                                    .white.opacity(0.14),
                                    .white.opacity(0.28)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2.2
                        )
                        .blendMode(.screen)
                )
                .overlay(
                    coreContour
                        .stroke(tint.opacity(0.28), lineWidth: 10)
                        .blur(radius: 12)
                        .opacity(0.30)
                )
                .shadow(color: tint.opacity(0.36), radius: 46, y: 14)
                .rotationEffect(.degrees(coreRotation))

        }
        .frame(width: style.orbFrameSize, height: style.orbFrameSize)
    }

    private func smoothstep(_ value: CGFloat) -> CGFloat {
        let clamped = min(max(value, 0), 1)
        return clamped * clamped * (3 - (2 * clamped))
    }
}

private struct StretchStarField: View {
    let progress: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let stars: [(x: CGFloat, y: CGFloat, size: CGFloat)] = [
        (0.18, 0.18, 4), (0.28, 0.30, 3), (0.37, 0.12, 3), (0.64, 0.20, 3),
        (0.74, 0.28, 4), (0.83, 0.18, 3), (0.24, 0.66, 3), (0.34, 0.78, 4),
        (0.68, 0.72, 3), (0.79, 0.62, 4), (0.50, 0.84, 3), (0.56, 0.10, 2)
    ]

    private var starOpacity: CGFloat {
        min(max((progress - 0.52) / 0.48, 0), 1)
    }

    var body: some View {
        Group {
            if starOpacity > 0.01 {
                if reduceMotion {
                    starsBody(at: 0)
                } else {
                    TimelineView(.animation(minimumInterval: 1.0 / 20.0, paused: false)) { timeline in
                        starsBody(at: timeline.date.timeIntervalSinceReferenceDate)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func starsBody(at time: TimeInterval) -> some View {
        GeometryReader { geometry in
            ForEach(Array(stars.enumerated()), id: \.offset) { index, star in
                let twinkle = 0.45 + (0.55 * sin((time * 1.6) + Double(index) * 0.72))

                Circle()
                    .fill(.white.opacity(0.18 + (0.42 * starOpacity * twinkle)))
                    .frame(width: star.size, height: star.size)
                    .shadow(color: .white.opacity(0.18 * starOpacity), radius: 8)
                    .position(
                        x: geometry.size.width * star.x,
                        y: geometry.size.height * star.y
                    )
            }
        }
        .allowsHitTesting(false)
    }
}

private struct StretchContourShape: Shape {
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
