import SwiftData
import SwiftUI

struct TodayView: View {
    let settings: AppSettings

    @Environment(AppModel.self) private var appModel
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutTemplate.updatedAt, order: .reverse) private var templates: [WorkoutTemplate]
    @Query(sort: \PlannedWorkout.scheduledFor) private var plannedWorkouts: [PlannedWorkout]
    @Query(sort: \MealEntry.loggedAt, order: .reverse) private var meals: [MealEntry]
    @Query(sort: \MoodCheckIn.createdAt, order: .reverse) private var moodCheckIns: [MoodCheckIn]
    @State private var showsTemplatePicker = false
    @State private var showsTemplateEditor = false
    @State private var showsScheduleSheet = false
    @State private var showsMealSheet = false
    @State private var feelingSheetItem: FeelingSheetItem?
    @State private var activeSession: SessionStart?
    @State private var stretchTimerSession: StretchTimerConfiguration?
    @State private var shareItem: ShareURLItem?

    private struct FeelingSheetItem: Identifiable {
        let id = UUID()
        let checkIn: MoodCheckIn?
    }

    private var todaysWorkout: PlannedWorkout? {
        let calendar = Calendar.current
        return plannedWorkouts.first { calendar.isDateInToday($0.scheduledFor) }
    }

    private var nextWorkout: PlannedWorkout? {
        plannedWorkouts.first { $0.scheduledFor >= .now && !Calendar.current.isDateInToday($0.scheduledFor) }
    }

    private var activeTemplates: [WorkoutTemplate] {
        templates.filter { !$0.isArchived && $0.kind == .workout }
    }

    private var todaysCheckIn: MoodCheckIn? {
        let calendar = Calendar.current
        return moodCheckIns.first { $0.workout == nil && calendar.isDateInToday($0.createdAt) }
    }

    private var todaysMeals: [MealEntry] {
        let calendar = Calendar.current
        return meals.filter { $0.isLogged(on: .now, calendar: calendar) }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let todaysWorkout {
                    TodayWorkoutCard(
                        plannedWorkout: todaysWorkout,
                        caption: "Today",
                        onQuickStart: { startSession(from: todaysWorkout) },
                        onPlan: { showsScheduleSheet = true }
                    )
                } else if let nextWorkout {
                    TodayWorkoutCard(
                        plannedWorkout: nextWorkout,
                        caption: "Next up",
                        onQuickStart: { startSession(from: nextWorkout) },
                        onPlan: { showsScheduleSheet = true }
                    )
                } else {
                    TodayEmptyStateCard(
                        onCreateTemplate: { showsTemplateEditor = true },
                        onPlanWorkout: { showsScheduleSheet = true }
                    )
                }

                if settings.healthIntegrationEnabled {
                    HealthSummaryCard(
                        summary: appModel.healthService.todaySummary,
                        authorizationState: appModel.healthService.authorizationState
                    )
                }

                if settings.feelingCheckInsEnabled {
                    FeelingPromptCard(checkIn: todaysCheckIn) {
                        feelingSheetItem = FeelingSheetItem(checkIn: todaysCheckIn)
                    }
                }

                if settings.mealsEnabled {
                    MealsPreviewCard(meals: Array(todaysMeals.prefix(3)), onAddMeal: { showsMealSheet = true })
                }
            }
            .padding()
        }
        .refreshable {
            await appModel.refreshIntegrations(using: settings, modelContext: modelContext)
        }
        .liftScreenBackground()
        .navigationTitle("Today")
        .navigationBarTitleDisplayMode(.large)
        .task(id: settings.healthIntegrationEnabled) {
            guard settings.healthIntegrationEnabled else { return }
            await appModel.refreshIntegrations(using: settings, modelContext: modelContext)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Quick Start", systemImage: "play.fill") {
                        if let todaysWorkout {
                            startSession(from: todaysWorkout)
                        } else if activeTemplates.isEmpty {
                            startLiveSession()
                        } else {
                            showsTemplatePicker = true
                        }
                    }

                    Button("Log Workout Now", systemImage: "record.circle.fill") {
                        startLiveSession()
                    }

                    Button("Stretch Timer", systemImage: "figure.cooldown") {
                        startStretchTimer()
                    }

                    Button("Plan Workout", systemImage: "calendar.badge.plus") {
                        showsScheduleSheet = true
                    }

                    Button("Create Template", systemImage: "square.and.pencil") {
                        showsTemplateEditor = true
                    }

                    if settings.mealsEnabled {
                        Button("Add Meal", systemImage: "fork.knife") {
                            showsMealSheet = true
                        }
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showsTemplatePicker) {
            NavigationStack {
                List {
                    Section {
                        Button {
                            startLiveSession()
                            showsTemplatePicker = false
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Label("Log Workout Now", systemImage: "record.circle.fill")
                                    .font(.lift(.body, weight: .semibold))
                                Text("Start a workout live and build the exercises as you go.")
                                    .font(.lift(.footnote))
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Button {
                            startStretchTimer()
                            showsTemplatePicker = false
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Label("Stretch Timer", systemImage: "figure.cooldown")
                                    .font(.lift(.body, weight: .semibold))
                                Text("A calm timer with soft switch cues and a five-second warmup countdown.")
                                    .font(.lift(.footnote))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    Section("Templates") {
                        if activeTemplates.isEmpty {
                            Text("No templates yet. You can still log a workout right now and build structure later.")
                                .font(.lift(.footnote))
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(activeTemplates) { template in
                                Button {
                                    startSession(from: template)
                                    showsTemplatePicker = false
                                } label: {
                                    HStack(alignment: .top, spacing: 12) {
                                        Image(systemName: template.kind.listSymbolName)
                                            .font(.system(size: 18, weight: .semibold))
                                            .foregroundStyle(Color.accentColor)
                                            .frame(width: 22)

                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(template.name)
                                                .font(.lift(.body, weight: .semibold))
                                            Text(template.summaryLine)
                                                .font(.lift(.footnote))
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .navigationTitle("Quick Start")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Close") {
                            showsTemplatePicker = false
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showsTemplateEditor) {
            TemplateEditorView()
        }
        .sheet(isPresented: $showsScheduleSheet) {
            ScheduleWorkoutSheet(
                settings: settings,
                templates: activeTemplates,
                defaultDate: .now
            ) { _, manualShareURL in
                if let manualShareURL {
                    shareItem = ShareURLItem(url: manualShareURL)
                }
            }
        }
        .sheet(item: $shareItem) { shareItem in
            ShareSheet(items: [shareItem.url])
        }
        .sheet(isPresented: $showsMealSheet) {
            MealEditorSheet(
                defaultLoggedAt: .now,
                displayedComponents: [.hourAndMinute],
                fixedDay: .now
            )
        }
        .fullScreenCover(item: $feelingSheetItem) { item in
            QuickFeelingCheckInSheet(checkIn: item.checkIn)
        }
        .fullScreenCover(item: $activeSession) { session in
            if session.draft.templateKind == .stretch {
                StretchSessionView(
                    draft: session.draft,
                    settings: settings,
                    plannedWorkout: session.plannedWorkout
                ) {
                    activeSession = nil
                }
            } else {
                WorkoutSessionView(
                    draft: session.draft,
                    settings: settings,
                    plannedWorkout: session.plannedWorkout
                ) {
                    activeSession = nil
                }
            }
        }
        .fullScreenCover(item: $stretchTimerSession) { session in
            StretchSessionView(configuration: session, settings: settings) {
                stretchTimerSession = nil
            }
        }
    }

    private func startSession(from plannedWorkout: PlannedWorkout) {
        var draft = WorkoutDraftFactory.session(from: plannedWorkout)
        if let progress = appModel.watchProgress(for: draft.plannedWorkoutID) {
            draft.applyWatchProgress(progress)
        }

        activeSession = SessionStart(
            draft: draft,
            plannedWorkout: plannedWorkout
        )
    }

    private func startSession(from template: WorkoutTemplate) {
        activeSession = SessionStart(
            draft: WorkoutDraftFactory.session(from: template),
            plannedWorkout: nil
        )
    }

    private func startLiveSession() {
        activeSession = SessionStart(
            draft: WorkoutDraftFactory.liveSession(),
            plannedWorkout: nil
        )
    }

    private func startStretchTimer() {
        stretchTimerSession = .quickStart
    }
}

private struct TodayWorkoutCard: View {
    let plannedWorkout: PlannedWorkout
    let caption: String
    let onQuickStart: () -> Void
    let onPlan: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(caption.uppercased())
                .font(.lift(.caption, weight: .semibold))
                .foregroundStyle(.secondary)

            Text(plannedWorkout.displayName)
                .font(.lift(.title2, weight: .bold))

            HStack(spacing: 12) {
                Label(plannedWorkout.scheduledFor.formatted(date: .omitted, time: .shortened), systemImage: "clock")
                Label("\(plannedWorkout.durationMinutes) min", systemImage: "timer")
                Label(plannedWorkout.isCalendarSynced ? "Synced" : "Not synced", systemImage: plannedWorkout.isCalendarSynced ? "checkmark.icloud" : "calendar.badge.plus")
            }
            .font(.lift(.footnote, weight: .medium))
            .foregroundStyle(.secondary)

            if let snapshot = plannedWorkout.snapshot {
                Text(snapshot.summaryLine)
                    .font(.lift(.subheadline))
                    .foregroundStyle(.secondary)
            }

            if plannedWorkout.templateKind == .stretch {
                Label("Guided stretch flow", systemImage: "figure.cooldown")
                    .font(.lift(.footnote, weight: .medium))
                    .foregroundStyle(Color.liftStrength)
            }

            HStack(spacing: 12) {
                Button("Quick Start", action: onQuickStart)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                Button("Plan", action: onPlan)
                    .buttonStyle(.bordered)
                    .controlSize(.large)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .liftCardStyle()
    }
}

private struct HealthSummaryCard: View {
    let summary: HealthTodaySummary
    let authorizationState: HealthAuthorizationState

    private var hasActivity: Bool {
        summary.exerciseMinutes > 0 || summary.activeEnergyKilocalories > 0 || summary.workoutCount > 0
    }

    private var statusMessage: String? {
        switch authorizationState {
        case .unavailable:
            return "Health data isn’t available on this device."
        case .notDetermined:
            return "Turn on Health access in Settings to pull in today’s activity."
        case .denied:
            return "Health access is off right now, so this summary can’t refresh."
        case .authorized where !hasActivity:
            return "No Apple Health activity has shown up for today yet."
        case .authorized:
            return nil
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            TodayCardHeader(
                title: "Health",
                systemImage: "heart.text.square.fill",
                tint: .liftHealthTint
            )

            HStack {
                StatBlock(value: "\(Int(summary.exerciseMinutes))", caption: "exercise min")
                StatBlock(value: "\(Int(summary.activeEnergyKilocalories))", caption: "active kcal")
                StatBlock(value: "\(summary.workoutCount)", caption: "workouts")
            }

            if let statusMessage {
                Text(statusMessage)
                    .font(.lift(.footnote))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .liftCardStyle()
    }
}

private struct FeelingPromptCard: View {
    let checkIn: MoodCheckIn?
    let onAdd: () -> Void

    var body: some View {
        Button(action: onAdd) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    TodayCardHeader(
                        title: "State of Body",
                        systemImage: "figure.stand",
                        tint: .liftBodyTint
                    )

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }

                MoodScalePicker(
                    title: nil,
                    prompt: nil,
                    value: .constant(checkIn?.moodLevel ?? 3),
                    isInteractive: false,
                    style: .compact,
                    lowerLabel: "Very Bad",
                    upperLabel: "Very Good",
                    showsSlider: false
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(RoundedRectangle(cornerRadius: LiftTheme.cardCornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .liftCardStyle()
    }
}

private struct TodayCardHeader: View {
    let title: String
    let systemImage: String
    var tint: Color = .primary

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 22, weight: .semibold))
                .frame(width: 28, alignment: .leading)
                .foregroundStyle(tint)
                .accessibilityHidden(true)

            Text(title)
                .font(.lift(.headline, weight: .semibold))
                .foregroundStyle(tint)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct QuickFeelingCheckInSheet: View {
    private enum QuickFeelingSheetMode: String, CaseIterable, Identifiable {
        case stateOfBody = "State of Body"
        case tags = "Tags"

        var id: String { rawValue }
    }

    private static let tagOptions = [
        "Sore",
        "Injury",
        "Tight",
        "Heavy",
        "Overtired",
        "Low Energy",
        "Recovered",
        "Restless",
        "Anxious",
        "Depressed"
    ]

    let checkIn: MoodCheckIn?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppModel.self) private var appModel
    @State private var isSaving = false
    @State private var moodLevel: Int
    @State private var moodProgress: CGFloat
    @State private var selectedMode: QuickFeelingSheetMode
    @State private var selectedTags: Set<String>
    @GestureState private var dismissDragOffset: CGFloat = 0

    init(checkIn: MoodCheckIn?) {
        self.checkIn = checkIn
        let initialMoodLevel = checkIn?.moodLevel ?? 3
        _moodLevel = State(initialValue: initialMoodLevel)
        _moodProgress = State(initialValue: CGFloat(min(max(initialMoodLevel, 1), 5) - 1) / 4)
        _selectedMode = State(initialValue: .stateOfBody)
        _selectedTags = State(initialValue: Set(checkIn?.tags ?? []))
    }

    private var panelTitle: String {
        selectedMode.rawValue
    }

    private var prompt: String {
        switch selectedMode {
        case .stateOfBody:
            "Choose how your body feels right now"
        case .tags:
            "Tag what your body is carrying today"
        }
    }

    private var accentColor: Color {
        ambientColor
    }

    private var ambientColor: Color {
        LiftMoodPalette.color(for: moodProgress)
    }

    private var orderedSelectedTags: [String] {
        let preferredOrder = Self.tagOptions.filter(selectedTags.contains)
        let customTags = selectedTags
            .filter { !Self.tagOptions.contains($0) }
            .sorted()

        return preferredOrder + customTags
    }

    private var panelDismissProgress: CGFloat {
        min(max(dismissDragOffset / 180, 0), 1)
    }

    var body: some View {
        GeometryReader { proxy in
            let safeTop = proxy.safeAreaInsets.top
            let safeBottom = proxy.safeAreaInsets.bottom

            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.06, blue: 0.06),
                        Color(red: 0.02, green: 0.03, blue: 0.03)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                    .ignoresSafeArea()

                RadialGradient(
                    colors: [
                        ambientColor.opacity(0.12),
                        .clear
                    ],
                    center: .center,
                    startRadius: 40,
                    endRadius: 420
                )
                .opacity(Double(1 - (panelDismissProgress * 0.28)))
                .ignoresSafeArea()

                VStack {
                    VStack(spacing: 0) {
                        HStack {
                            MoodSheetChromeButton(systemImage: "chevron.left", accessibilityLabel: "Back") {
                                dismiss()
                            }

                            Spacer()

                            Menu {
                                ForEach(QuickFeelingSheetMode.allCases) { mode in
                                    Button {
                                        selectedMode = mode
                                    } label: {
                                        Label(mode.rawValue, systemImage: mode == selectedMode ? "checkmark" : "circle")
                                    }
                                }
                            } label: {
                                MoodSheetChromeLabel(systemImage: "ellipsis")
                            }
                            .accessibilityLabel("More options")
                        }
                        .overlay(alignment: .center) {
                            Text(panelTitle)
                                .font(.lift(.headline, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.96))
                        }

                        Spacer(minLength: 22)

                        Text(prompt)
                            .font(.system(size: 34, weight: .black, design: .rounded))
                            .foregroundStyle(.white.opacity(0.96))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .minimumScaleFactor(0.82)

                        Spacer(minLength: 12)

                        Group {
                            switch selectedMode {
                            case .stateOfBody:
                                MoodScalePicker(
                                    title: nil,
                                    prompt: nil,
                                    value: $moodLevel,
                                    onProgressChanged: { moodProgress = $0 },
                                    lowerLabel: "Very\nBad",
                                    upperLabel: "Very\nGood"
                                )
                            case .tags:
                                QuickFeelingTagPicker(
                                    tags: Self.tagOptions,
                                    selectedTags: $selectedTags,
                                    tint: accentColor
                                )
                            }
                        }

                        Spacer(minLength: 12)

                        Button {
                            save()
                        } label: {
                            Text("Log")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 20)
                                .background {
                                    LiquidGlassCapsule(tint: accentColor)
                                }
                        }
                        .buttonStyle(.plain)
                        .disabled(isSaving)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, max(safeTop, 14) + 18)
                    .padding(.bottom, max(safeBottom, 18))
                    .frame(maxWidth: 500, maxHeight: .infinity, alignment: .top)
                    .background {
                        RoundedRectangle(cornerRadius: 36, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.25, green: 0.28, blue: 0.27),
                                        Color(red: 0.22, green: 0.25, blue: 0.24)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 36, style: .continuous)
                                    .fill(
                                        RadialGradient(
                                            colors: [
                                                ambientColor.opacity(0.16),
                                                .clear
                                            ],
                                            center: .center,
                                            startRadius: 30,
                                            endRadius: 320
                                        )
                                    )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 36, style: .continuous)
                                    .strokeBorder(.white.opacity(0.08), lineWidth: 1)
                            )
                            .overlay(alignment: .top) {
                                Capsule(style: .continuous)
                                    .fill(.white.opacity(0.18))
                                    .frame(width: 44, height: 5)
                                    .padding(.top, 14)
                            }
                            .shadow(color: .black.opacity(0.28), radius: 32, y: 16)
                    }
                    .offset(y: dismissDragOffset)
                    .simultaneousGesture(dismissGesture)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private var dismissGesture: some Gesture {
        DragGesture(minimumDistance: 12, coordinateSpace: .local)
            .updating($dismissDragOffset) { value, state, _ in
                guard value.translation.height > 0 else { return }
                guard value.translation.height > abs(value.translation.width) else { return }

                state = value.translation.height
            }
            .onEnded { value in
                guard value.translation.height > 0 else { return }
                guard value.translation.height > abs(value.translation.width) else { return }

                let shouldDismiss = value.translation.height > 120 || value.predictedEndTranslation.height > 220
                guard shouldDismiss else { return }

                appModel.haptics.softTap()
                dismiss()
            }
    }

    private func save() {
        guard !isSaving else { return }

        let target = checkIn ?? MoodCheckIn(phase: .checkIn, moodLevel: moodLevel, createdAt: .now)
        target.phase = MoodPhase.checkIn.rawValue
        target.moodLevel = moodLevel
        target.tagText = orderedSelectedTags.joined(separator: ", ")
        target.createdAt = .now

        if checkIn == nil {
            modelContext.insert(target)
        }

        do {
            try modelContext.save()
            isSaving = true

            Task {
                appModel.haptics.confirm()
                appModel.showBanner(checkIn == nil ? "State of Body saved" : "State of Body updated", systemImage: "figure.stand")

                isSaving = false
                dismiss()
            }
        } catch {
            isSaving = false
            appModel.showBanner("Couldn’t save State of Body", systemImage: "exclamationmark.triangle.fill")
        }
    }
}

private struct MoodSheetChromeButton: View {
    let systemImage: String
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            MoodSheetChromeLabel(systemImage: systemImage)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}

private struct MoodSheetChromeLabel: View {
    let systemImage: String

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 22, weight: .bold))
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

private struct LiquidGlassCapsule: View {
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

private struct TodayGlassActionButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let tint: Color
    var labelColor: Color = .white
    var intensity: CGFloat = 1
    var glowStrength: CGFloat = 1

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.lift(.subheadline, weight: .semibold))
            .foregroundStyle(labelColor.opacity(0.96))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background {
                LiquidGlassCapsule(tint: tint, intensity: intensity, glowStrength: glowStrength)
            }
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.94 : 1)
            .animation(LiftMotion.press(reduceMotion), value: configuration.isPressed)
    }
}

private struct QuickFeelingTagPicker: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let tags: [String]
    @Binding var selectedTags: Set<String>
    let tint: Color

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(tags, id: \.self) { tag in
                Button {
                    toggle(tag)
                } label: {
                    HStack(spacing: 10) {
                        Text(tag)
                            .font(.lift(.subheadline, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.96))
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        if selectedTags.contains(tag) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.white.opacity(0.9))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 15)
                    .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(selectedTags.contains(tag) ? tint.opacity(0.28) : .white.opacity(0.05))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(selectedTags.contains(tag) ? tint.opacity(0.82) : .white.opacity(0.10), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .animation(LiftMotion.selection(reduceMotion), value: selectedTags.contains(tag))
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func toggle(_ tag: String) {
        if selectedTags.contains(tag) {
            selectedTags.remove(tag)
        } else {
            selectedTags.insert(tag)
        }
    }
}

private struct MealsPreviewCard: View {
    let meals: [MealEntry]
    let onAddMeal: () -> Void

    var body: some View {
        Button(action: onAddMeal) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    TodayCardHeader(
                        title: "Meals",
                        systemImage: "fork.knife",
                        tint: .liftMealsTint
                    )

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }

                if meals.isEmpty {
                    Text("No meals logged today yet.")
                        .font(.lift(.body))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                } else {
                    ForEach(meals) { meal in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(meal.mealName)
                                    .font(.lift(.body, weight: .semibold))
                                Text(meal.loggedAt.formatted(date: .omitted, time: .shortened))
                                    .font(.lift(.footnote))
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(RoundedRectangle(cornerRadius: LiftTheme.cardCornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .liftCardStyle()
    }
}

private struct TodayEmptyStateCard: View {
    let onCreateTemplate: () -> Void
    let onPlanWorkout: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            EmptyStateCard(
                symbol: "dumbbell",
                title: "Nothing scheduled",
                message: "Keep it simple. Create a template or drop a workout onto the calendar when you’re ready."
            )

            HStack(spacing: 12) {
                Button("Create Template", action: onCreateTemplate)
                    .buttonStyle(
                        TodayGlassActionButtonStyle(
                            tint: Color.white.opacity(0.22),
                            labelColor: .accentColor,
                            intensity: 0.62,
                            glowStrength: 0.18
                        )
                    )

                Button("Plan Workout", action: onPlanWorkout)
                    .buttonStyle(
                        TodayGlassActionButtonStyle(
                            tint: .accentColor,
                            intensity: 0.92,
                            glowStrength: 0.62
                        )
                    )
            }
        }
    }
}

private struct StatBlock: View {
    let value: String
    let caption: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.lift(.title3, weight: .bold))
            Text(caption)
                .font(.lift(.caption))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SessionStart: Identifiable {
    let id = UUID()
    let draft: WorkoutSessionDraft
    let plannedWorkout: PlannedWorkout?
}

#Preview {
    PreviewContainer {
        NavigationStack {
            TodayView(settings: AppSettings())
        }
    }
}
