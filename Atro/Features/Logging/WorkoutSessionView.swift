import SwiftData
import SwiftUI

private enum WorkoutSessionFieldFocus: Hashable {
    case exerciseName(UUID)
    case exerciseCategory(UUID)
    case reps(UUID, UUID)
    case weight(UUID, UUID)
    case duration(UUID, UUID)
    case rest(UUID, UUID)

    var exerciseID: UUID {
        switch self {
        case .exerciseName(let exerciseID),
             .exerciseCategory(let exerciseID),
             .reps(let exerciseID, _),
             .weight(let exerciseID, _),
             .duration(let exerciseID, _),
             .rest(let exerciseID, _):
            exerciseID
        }
    }
}

struct WorkoutSessionView: View {
    let settings: AppSettings
    let plannedWorkout: PlannedWorkout?
    let onClose: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppModel.self) private var appModel
    @State private var viewModel: WorkoutSessionViewModel
    @State private var isSaving = false
    @State private var expandedExerciseID: UUID?
    @State private var swipedExerciseID: UUID?
    @State private var stretchTimerSession: StretchTimerConfiguration?
    @FocusState private var focusedField: WorkoutSessionFieldFocus?

    init(
        draft: WorkoutSessionDraft,
        settings: AppSettings,
        plannedWorkout: PlannedWorkout? = nil,
        onClose: @escaping () -> Void
    ) {
        self.settings = settings
        self.plannedWorkout = plannedWorkout
        self.onClose = onClose
        _viewModel = State(initialValue: WorkoutSessionViewModel(draft: draft, plannedWorkout: plannedWorkout))
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 16) {
                        headerCard

                        if viewModel.draft.exercises.isEmpty {
                            WorkoutSessionEmptyState {
                                addExercise(using: proxy)
                            }
                        } else {
                            ForEach($viewModel.draft.exercises) { $exercise in
                                let exerciseID = exercise.id

                                ExerciseSwipeRevealCard(
                                    isRevealed: Binding(
                                        get: { swipedExerciseID == exerciseID },
                                        set: { isRevealed in
                                            if isRevealed {
                                                swipedExerciseID = exerciseID
                                            } else if swipedExerciseID == exerciseID {
                                                swipedExerciseID = nil
                                            }
                                        }
                                    ),
                                    isEnabled: focusedField == nil,
                                    onDelete: {
                                        removeExercise(exerciseID)
                                    }
                                ) {
                                    ExerciseSessionCard(
                                        exercise: $exercise,
                                        isExpanded: expandedExerciseID == exerciseID,
                                        focus: $focusedField,
                                        onToggleExpanded: {
                                            toggleExpanded(exerciseID, using: proxy)
                                        },
                                        onRemoveSet: { setID in
                                            viewModel.removeSet(setID, from: exerciseID)
                                        },
                                        onToggleSet: { setID in
                                            viewModel.completeSet(in: exerciseID, setID: setID) ?? false
                                        },
                                        onAddSet: {
                                            addSet(to: exerciseID, using: proxy)
                                        },
                                        onStartRest: { seconds in
                                            viewModel.startRestTimer(seconds: seconds)
                                        }
                                    )
                                }
                                .id(exerciseID)
                            }

                            WorkoutSessionFooterActionCard {
                                addExercise(using: proxy)
                            }
                        }
                    }
                    .padding()
                    .padding(.bottom, focusedField == nil ? 126 : 32)
                }
                .liftKeyboardDismissable()
                .liftScreenBackground()
                .navigationTitle(viewModel.draft.workoutName)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Close") {
                            dismiss()
                        }
                    }
                }
                .safeAreaInset(edge: .bottom) {
                    if focusedField == nil {
                        bottomActionTray
                    }
                }
                .animation(LiftMotion.settle(reduceMotion), value: focusedField == nil)
                .sheet(isPresented: $viewModel.showsSummary) {
                    WorkoutSummarySheet(settings: settings, onSave: saveWorkout, viewModel: viewModel)
                        .presentationDetents([.medium, .large])
                }
                .fullScreenCover(item: $stretchTimerSession) { session in
                    StretchSessionView(
                        configuration: session
                    ) {
                        stretchTimerSession = nil
                    }
                }
                .onAppear {
                    syncExpandedExercise()
                    applyPendingWatchProgress()
                }
                .onChange(of: viewModel.draft.exercises.map(\.id)) { _, _ in
                    syncExpandedExercise()
                    syncSwipedExercise()
                }
                .onChange(of: appModel.watchWorkoutProgressRevision) { _, _ in
                    applyPendingWatchProgress()
                }
                .onChange(of: focusedField) { _, field in
                    swipedExerciseID = nil

                    guard let exerciseID = field?.exerciseID else {
                        return
                    }

                    withAnimation(LiftMotion.settle(reduceMotion)) {
                        proxy.scrollTo(exerciseID, anchor: .center)
                    }
                }
            }
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                WorkoutElapsedTimerLabel(startedAt: viewModel.draft.startedAt)

                Label(exerciseCountText, systemImage: "list.bullet.rectangle.portrait")
            }
            .font(.lift(.subheadline))
            .foregroundStyle(.secondary)

            if let plannedWorkout {
                Text(plannedWorkout.scheduledFor.formatted(date: .abbreviated, time: .shortened))
                    .font(.lift(.footnote))
                    .foregroundStyle(.secondary)
            }

        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .liftCardStyle()
    }

    private var bottomActionTray: some View {
        HStack(spacing: 14) {
            if let restTimerEndDate = viewModel.restTimerEndDate, restTimerEndDate > .now {
                WorkoutRestTimerPill(endDate: restTimerEndDate)
            }

            Spacer(minLength: 0)

            Button {
                stretchTimerSession = .quickStart
            } label: {
                Label("Stretch Timer", systemImage: "figure.cooldown")
            }
            .buttonStyle(
                WorkoutGlassActionButtonStyle(
                    tint: Color(red: 0.32, green: 0.41, blue: 0.33),
                    intensity: 0.74,
                    glowStrength: 0.18,
                    horizontalPadding: 18,
                    verticalPadding: 14
                )
            )

            Button {
                viewModel.showsSummary = true
            } label: {
                Label("Finish Workout", systemImage: "checkmark.circle.fill")
            }
            .buttonStyle(
                WorkoutGlassActionButtonStyle(
                    tint: .accentColor,
                    intensity: 0.94,
                    glowStrength: 0.26,
                    horizontalPadding: 24,
                    verticalPadding: 15
                )
            )
        }
        .padding(.horizontal, 18)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private var exerciseCountText: String {
        let count = viewModel.draft.exercises.count
        return count == 1 ? "1 exercise" : "\(count) exercises"
    }

    private func scrollToExercise(_ exerciseID: UUID, using proxy: ScrollViewProxy) {
        DispatchQueue.main.async {
            withAnimation(LiftMotion.settle(reduceMotion)) {
                proxy.scrollTo(exerciseID, anchor: .center)
            }
        }
    }

    private func addExercise(using proxy: ScrollViewProxy) {
        let exerciseID = viewModel.addExercise()
        swipedExerciseID = nil
        expandedExerciseID = exerciseID

        scrollToExercise(exerciseID, using: proxy)
        DispatchQueue.main.async {
            focusedField = .exerciseName(exerciseID)
        }
    }

    private func addSet(to exerciseID: UUID, using proxy: ScrollViewProxy) {
        guard let setID = viewModel.addSet(to: exerciseID) else {
            return
        }

        swipedExerciseID = nil
        expandedExerciseID = exerciseID

        scrollToExercise(exerciseID, using: proxy)
        DispatchQueue.main.async {
            focusedField = .reps(exerciseID, setID)
        }
    }

    private func removeExercise(_ exerciseID: UUID) {
        if focusedField?.exerciseID == exerciseID {
            focusedField = nil
        }

        if swipedExerciseID == exerciseID {
            swipedExerciseID = nil
        }

        viewModel.removeExercise(exerciseID)
        syncExpandedExercise()
    }

    private func toggleExpanded(_ exerciseID: UUID, using proxy: ScrollViewProxy) {
        swipedExerciseID = nil

        withAnimation(LiftMotion.emphasis(reduceMotion)) {
            expandedExerciseID = expandedExerciseID == exerciseID ? nil : exerciseID
        }

        if expandedExerciseID == exerciseID {
            scrollToExercise(exerciseID, using: proxy)
        }
    }

    private func syncExpandedExercise() {
        let exerciseIDs = viewModel.draft.exercises.map(\.id)

        guard !exerciseIDs.isEmpty else {
            expandedExerciseID = nil
            return
        }

        if let expandedExerciseID, exerciseIDs.contains(expandedExerciseID) {
            return
        }

        expandedExerciseID = exerciseIDs.last
    }

    private func syncSwipedExercise() {
        let exerciseIDs = Set(viewModel.draft.exercises.map(\.id))

        guard let swipedExerciseID, exerciseIDs.contains(swipedExerciseID) else {
            self.swipedExerciseID = nil
            return
        }
    }

    private func applyPendingWatchProgress() {
        guard let progress = appModel.watchProgress(for: viewModel.draft.plannedWorkoutID) else {
            return
        }

        if viewModel.applyWatchProgress(progress) {
            syncExpandedExercise()
        }
    }

    private func saveWorkout() {
        guard !isSaving else {
            return
        }

        isSaving = true

        Task {
            defer { isSaving = false }
            do {
                _ = try await viewModel.finish(using: modelContext, settings: settings, appModel: appModel)
                appModel.clearWatchProgress(for: viewModel.draft.plannedWorkoutID)
                dismiss()
                onClose()
            } catch {
                appModel.showBanner("Couldn’t save workout", systemImage: "exclamationmark.triangle.fill")
            }
        }
    }
}

private struct WorkoutElapsedTimerLabel: View {
    let startedAt: Date

    var body: some View {
        TimelineView(.periodic(from: startedAt, by: 1)) { context in
            Label {
                Text(timerInterval: startedAt...context.date)
                    .monospacedDigit()
            } icon: {
                Image(systemName: "stopwatch")
            }
        }
    }
}

private struct WorkoutRestTimerPill: View {
    let endDate: Date

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            if context.date < endDate {
                HStack(spacing: 8) {
                    Image(systemName: "timer")

                    Text(timerInterval: context.date...endDate, countsDown: true)
                        .monospacedDigit()
                        .frame(minWidth: 44, alignment: .leading)
                }
                .font(.lift(.footnote, weight: .semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.white.opacity(0.06))
                )
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(.white.opacity(0.08), lineWidth: 1)
                )
            }
        }
    }
}

private struct ExerciseSessionCard: View {
    @Binding var exercise: LoggedExerciseDraft

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let isExpanded: Bool
    let focus: FocusState<WorkoutSessionFieldFocus?>.Binding
    let onToggleExpanded: () -> Void
    let onRemoveSet: (UUID) -> Void
    let onToggleSet: (UUID) -> Bool
    let onAddSet: () -> Void
    let onStartRest: (Int) -> Void

    private var tracksWeightBinding: Binding<Bool> {
        Binding(
            get: { exercise.sets.contains(where: \.tracksWeight) },
            set: { newValue in
                for index in exercise.sets.indices {
                    exercise.sets[index].tracksWeight = newValue
                    if !newValue {
                        exercise.sets[index].plannedWeight = 0
                        exercise.sets[index].actualWeight = 0
                    }
                }
            }
        )
    }

    private var tracksDurationBinding: Binding<Bool> {
        Binding(
            get: { exercise.sets.contains(where: \.tracksDuration) },
            set: { newValue in
                for index in exercise.sets.indices {
                    exercise.sets[index].tracksDuration = newValue
                    if newValue {
                        if exercise.sets[index].plannedDurationSeconds == 0 {
                            exercise.sets[index].plannedDurationSeconds = 300
                        }
                        if exercise.sets[index].actualDurationSeconds == 0 {
                            exercise.sets[index].actualDurationSeconds = exercise.sets[index].plannedDurationSeconds
                        }
                    } else {
                        exercise.sets[index].plannedDurationSeconds = 0
                        exercise.sets[index].actualDurationSeconds = 0
                    }
                }
            }
        )
    }

    private var exerciseTitle: String {
        let trimmed = exercise.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Exercise \(exercise.orderIndex + 1)" : trimmed
    }

    private var categoryText: String? {
        let trimmed = exercise.category.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private var summaryText: String {
        let completedSets = exercise.sets.filter(\.isCompleted).count
        var fragments = ["\(completedSets)/\(exercise.sets.count) sets"]

        if exercise.sets.contains(where: \.tracksWeight) {
            let topWeight = exercise.sets.map(\.actualWeight).max() ?? 0
            if topWeight > 0 {
                fragments.append("\(formattedWeight(topWeight)) lb top")
            } else {
                fragments.append("Weight")
            }
        }

        if exercise.sets.contains(where: \.tracksDuration) {
            let totalMinutes = exercise.sets.reduce(0) { partialResult, set in
                partialResult + max(set.actualDurationSeconds, 0)
            } / 60
            if totalMinutes > 0 {
                fragments.append("\(totalMinutes)m time")
            } else {
                fragments.append("Time")
            }
        }

        return fragments.joined(separator: " • ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Button(action: onToggleExpanded) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(exerciseTitle)
                            .font(.lift(.headline, weight: .semibold))
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)

                        if let categoryText {
                            Text(categoryText)
                                .font(.lift(.footnote))
                                .foregroundStyle(.secondary)
                        }

                        Text(summaryText)
                            .font(.lift(.footnote, weight: .medium))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Button(action: onToggleExpanded) {
                    Image(systemName: "chevron.down.circle.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .buttonStyle(.plain)
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 10) {
                        TextField("Exercise name", text: $exercise.name)
                            .font(.lift(.headline, weight: .semibold))
                            .textFieldStyle(.plain)
                            .textInputAutocapitalization(.words)
                            .focused(focus, equals: .exerciseName(exercise.id))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(Color.primary.opacity(0.05))
                            )

                        TextField("Category", text: $exercise.category)
                            .font(.lift(.footnote))
                            .foregroundStyle(.secondary)
                            .textFieldStyle(.plain)
                            .textInputAutocapitalization(.words)
                            .focused(focus, equals: .exerciseCategory(exercise.id))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(Color.primary.opacity(0.05))
                            )
                    }

                    HStack(spacing: 10) {
                        ExerciseMetricToggle(title: "Weight", systemImage: "scalemass.fill", isOn: tracksWeightBinding)
                        ExerciseMetricToggle(title: "Time", systemImage: "timer", isOn: tracksDurationBinding)
                    }

                    ForEach($exercise.sets) { $set in
                        VStack(spacing: 10) {
                            HStack(spacing: 10) {
                                Button {
                                    var transaction = Transaction()
                                    transaction.disablesAnimations = true

                                    let didComplete = withTransaction(transaction) {
                                        onToggleSet(set.id)
                                    }

                                    if didComplete {
                                        onStartRest(set.restSeconds)
                                    }
                                } label: {
                                    Image(systemName: set.isCompleted ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 22, weight: .medium, design: .rounded))
                                        .foregroundStyle(set.isCompleted ? Color.accentColor : Color.secondary)
                                }
                                .buttonStyle(.plain)

                                Text("Set \(set.orderIndex + 1)")
                                    .font(.lift(.subheadline, weight: .semibold))

                                Spacer()

                                if exercise.sets.count > 1 {
                                    Button(role: .destructive) {
                                        onRemoveSet(set.id)
                                    } label: {
                                        Image(systemName: "minus.circle")
                                            .foregroundStyle(.red)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }

                            HStack(spacing: 12) {
                                WorkoutIntegerField(
                                    title: "Reps",
                                    value: $set.actualReps,
                                    focus: focus,
                                    focusID: .reps(exercise.id, set.id)
                                )

                                if set.tracksWeight {
                                    WorkoutDecimalField(
                                        title: "Weight",
                                        value: $set.actualWeight,
                                        focus: focus,
                                        focusID: .weight(exercise.id, set.id)
                                    )
                                }

                                if set.tracksDuration {
                                    WorkoutIntegerField(
                                        title: "Time",
                                        value: Binding(
                                            get: { max(set.actualDurationSeconds / 60, 0) },
                                            set: { set.actualDurationSeconds = max($0, 0) * 60 }
                                        ),
                                        focus: focus,
                                        focusID: .duration(exercise.id, set.id)
                                    )
                                }

                                WorkoutIntegerField(
                                    title: "Rest",
                                    value: Binding(
                                        get: { max(set.restSeconds / 60, 0) },
                                        set: { set.restSeconds = max($0, 0) * 60 }
                                    ),
                                    focus: focus,
                                    focusID: .rest(exercise.id, set.id)
                                )
                            }
                        }
                        .padding(14)
                        .background(
                            Color.liftCard.opacity(0.6),
                            in: RoundedRectangle(cornerRadius: LiftTheme.compactCornerRadius, style: .continuous)
                        )
                    }

                    HStack {
                        Spacer()

                        Button(action: onAddSet) {
                            Image(systemName: "plus")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.primary)
                                .frame(width: 32, height: 32)
                                .background(
                                    Circle()
                                        .fill(Color.primary.opacity(0.07))
                                )
                                .overlay(
                                    Circle()
                                        .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)

                        Spacer()
                    }
                }
                .transition(
                    .asymmetric(
                        insertion: .opacity
                            .combined(with: .move(edge: .top))
                            .combined(with: .scale(scale: 0.985, anchor: .top)),
                        removal: .opacity
                            .combined(with: .move(edge: .top))
                            .combined(with: .scale(scale: 0.985, anchor: .top))
                    )
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .liftCardStyle()
        .contentShape(RoundedRectangle(cornerRadius: LiftTheme.cardCornerRadius, style: .continuous))
        .animation(LiftMotion.emphasis(reduceMotion), value: isExpanded)
    }

    private func formattedWeight(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }

        return value.formatted(.number.precision(.fractionLength(0...1)))
    }
}

private struct ExerciseSwipeRevealCard<Content: View>: View {
    @Binding var isRevealed: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let isEnabled: Bool
    let onDelete: () -> Void
    @ViewBuilder let content: () -> Content

    @GestureState private var dragTranslation: CGFloat = 0

    private let actionWidth: CGFloat = 68
    private let buttonSize: CGFloat = 42
    private let trailingInset: CGFloat = 10

    private var restingOffset: CGFloat {
        isRevealed ? -actionWidth : 0
    }

    private var contentOffset: CGFloat {
        min(0, max(-actionWidth, restingOffset + dragTranslation))
    }

    private var revealProgress: CGFloat {
        min(max(abs(contentOffset) / actionWidth, 0), 1)
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            deleteAction

            content()
                .offset(x: contentOffset)
                .contentShape(RoundedRectangle(cornerRadius: LiftTheme.cardCornerRadius, style: .continuous))
                .highPriorityGesture(swipeGesture)
        }
    }

    private var deleteAction: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)

            Button(role: .destructive) {
                closeReveal()
                onDelete()
            } label: {
                Image(systemName: "trash.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: buttonSize, height: buttonSize)
                    .background(
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.84, green: 0.24, blue: 0.24),
                                        Color(red: 0.67, green: 0.11, blue: 0.15)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .overlay(
                        Circle()
                            .strokeBorder(.white.opacity(0.16), lineWidth: 1)
                    )
                    .shadow(color: Color.red.opacity(0.18 * revealProgress), radius: 10, y: 6)
            }
            .buttonStyle(.plain)
            .opacity(revealProgress == 0 ? 0 : max(0.08, Double(revealProgress)))
            .scaleEffect(0.78 + (0.22 * revealProgress))
            .offset(x: (1 - revealProgress) * 18)
            .padding(.trailing, trailingInset)
            .allowsHitTesting(isRevealed || revealProgress > 0.72)
        }
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 12, coordinateSpace: .local)
            .updating($dragTranslation) { value, state, _ in
                guard isEnabled else {
                    return
                }

                guard abs(value.translation.width) > abs(value.translation.height) else {
                    return
                }

                state = value.translation.width
            }
            .onEnded { value in
                guard isEnabled else {
                    return
                }

                guard abs(value.translation.width) > abs(value.translation.height) else {
                    return
                }

                let predictedOffset = min(0, max(-actionWidth, restingOffset + value.predictedEndTranslation.width))
                let shouldReveal = predictedOffset < -(actionWidth * (isRevealed ? 0.30 : 0.55))

                withAnimation(LiftMotion.swipe(reduceMotion)) {
                    isRevealed = shouldReveal
                }
            }
    }

    private func closeReveal() {
        withAnimation(LiftMotion.reveal(reduceMotion)) {
            isRevealed = false
        }
    }
}

private struct WorkoutSessionFooterActionCard: View {
    let onAddExercise: () -> Void

    var body: some View {
        HStack {
            Button(action: onAddExercise) {
                Label("Add Exercise", systemImage: "plus.circle.fill")
            }
            .buttonStyle(
                WorkoutGlassActionButtonStyle(
                    tint: Color(red: 0.26, green: 0.29, blue: 0.34),
                    labelColor: .accentColor,
                    highlightTint: .accentColor,
                    intensity: 0.56,
                    glowStrength: 0.18,
                    horizontalPadding: 18,
                    verticalPadding: 13
                )
            )

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
        .padding(.top, 4)
    }
}

private struct WorkoutSessionEmptyState: View {
    let onAddExercise: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: "plus.circle.dashed")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(Color.accentColor)

            Text("Build this workout as you go")
                .font(.lift(.headline, weight: .semibold))

            Text("Add your first exercise, log sets live, and save the whole session straight to the journal when you finish.")
                .font(.lift(.body))
                .foregroundStyle(.secondary)

            Button("Add First Exercise", action: onAddExercise)
                .buttonStyle(
                    WorkoutGlassActionButtonStyle(
                        tint: Color(red: 0.28, green: 0.52, blue: 0.90),
                        intensity: 0.92,
                        glowStrength: 0.24,
                        horizontalPadding: 22,
                        verticalPadding: 14
                    )
                )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .liftCardStyle()
    }
}

private struct ExerciseMetricToggle: View {
    let title: String
    let systemImage: String
    @Binding var isOn: Bool

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            Label(title, systemImage: systemImage)
                .font(.lift(.footnote, weight: .semibold))
                .foregroundStyle(isOn ? Color.accentColor : .secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    Capsule(style: .continuous)
                        .fill(isOn ? Color.accentColor.opacity(0.14) : Color.primary.opacity(0.05))
                )
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(isOn ? Color.accentColor.opacity(0.4) : Color.primary.opacity(0.08), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

struct WorkoutGlassActionButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let tint: Color
    var labelColor: Color = .white
    var highlightTint: Color? = nil
    var intensity: CGFloat = 1
    var glowStrength: CGFloat = 1
    var horizontalPadding: CGFloat = 20
    var verticalPadding: CGFloat = 14

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.lift(.subheadline, weight: .semibold))
            .foregroundStyle(labelColor.opacity(0.97))
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background {
                WorkoutGlassCapsule(
                    tint: tint,
                    highlightTint: highlightTint,
                    intensity: intensity,
                    glowStrength: glowStrength
                )
            }
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.95 : 1)
            .animation(LiftMotion.press(reduceMotion), value: configuration.isPressed)
    }
}

private struct WorkoutGlassCapsule: View {
    let tint: Color
    var highlightTint: Color? = nil
    var intensity: CGFloat = 1
    var glowStrength: CGFloat = 1

    private var glowTint: Color {
        highlightTint ?? tint
    }

    var body: some View {
        Capsule(style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        tint.opacity(0.90 * intensity),
                        tint.opacity(0.72 * intensity)
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
                                    .white.opacity(0.26 + (0.16 * intensity)),
                                    .white.opacity(0.04 + (0.03 * intensity)),
                                    .clear
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .scaleEffect(x: 0.86, y: 0.58, anchor: .top)
                        .offset(y: -14)
                        .blur(radius: 3)

                    Ellipse()
                        .fill(glowTint.opacity((0.09 + (0.11 * intensity)) * glowStrength))
                        .scaleEffect(x: 0.92, y: 0.74, anchor: .bottom)
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
                                .white.opacity(0.24 + (0.16 * intensity)),
                                .white.opacity(0.08 + (0.06 * intensity)),
                                glowTint.opacity(0.18 + (0.18 * intensity))
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.1
                    )
            )
            .shadow(color: glowTint.opacity((0.09 + (0.06 * intensity)) * glowStrength), radius: 16, y: 7)
            .shadow(color: .black.opacity(0.12 + (0.04 * intensity)), radius: 14, y: 10)
    }
}

private struct WorkoutValueFieldModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .font(.lift(.title3, weight: .semibold))
            .foregroundStyle(.primary)
            .textFieldStyle(.plain)
            .padding(.horizontal, 14)
            .frame(minHeight: 54)
            .background {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(fieldFill)
                    .overlay {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        .white.opacity(colorScheme == .dark ? 0.05 : 0.18),
                                        .clear
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(fieldBorder, lineWidth: 1)
            )
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.18 : 0.05), radius: 10, y: 4)
            .tint(.accentColor)
    }

    private var fieldFill: AnyShapeStyle {
        if colorScheme == .dark {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.92),
                        Color(red: 0.06, green: 0.07, blue: 0.09).opacity(0.98)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        } else {
            return AnyShapeStyle(Color.white.opacity(0.94))
        }
    }

    private var fieldBorder: Color {
        colorScheme == .dark ? .white.opacity(0.10) : .black.opacity(0.06)
    }
}

private struct WorkoutIntegerField: View {
    let title: String
    @Binding var value: Int
    let focus: FocusState<WorkoutSessionFieldFocus?>.Binding
    let focusID: WorkoutSessionFieldFocus
    @State private var text: String

    init(
        title: String,
        value: Binding<Int>,
        focus: FocusState<WorkoutSessionFieldFocus?>.Binding,
        focusID: WorkoutSessionFieldFocus
    ) {
        self.title = title
        _value = value
        self.focus = focus
        self.focusID = focusID
        _text = State(initialValue: String(value.wrappedValue))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.lift(.caption, weight: .medium))
                .foregroundStyle(.secondary)

            TextField(title, text: $text)
                .keyboardType(.numberPad)
                .focused(focus, equals: focusID)
                .modifier(WorkoutValueFieldModifier())
                .onChange(of: text) { _, newValue in
                    let filtered = newValue.filter(\.isNumber)
                    if filtered != newValue {
                        text = filtered
                        return
                    }

                    value = Int(filtered) ?? 0
                }
                .onChange(of: value) { _, newValue in
                    guard focus.wrappedValue != focusID else {
                        return
                    }

                    text = String(newValue)
                }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct WorkoutDecimalField: View {
    let title: String
    @Binding var value: Double
    let focus: FocusState<WorkoutSessionFieldFocus?>.Binding
    let focusID: WorkoutSessionFieldFocus
    @State private var text: String

    init(
        title: String,
        value: Binding<Double>,
        focus: FocusState<WorkoutSessionFieldFocus?>.Binding,
        focusID: WorkoutSessionFieldFocus
    ) {
        self.title = title
        _value = value
        self.focus = focus
        self.focusID = focusID
        _text = State(initialValue: Self.string(for: value.wrappedValue))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.lift(.caption, weight: .medium))
                .foregroundStyle(.secondary)

            TextField(title, text: $text)
                .keyboardType(.decimalPad)
                .focused(focus, equals: focusID)
                .modifier(WorkoutValueFieldModifier())
                .onChange(of: text) { _, newValue in
                    let filtered = sanitizedDecimal(newValue)
                    if filtered != newValue {
                        text = filtered
                        return
                    }

                    value = Double(filtered) ?? 0
                }
                .onChange(of: value) { _, newValue in
                    guard focus.wrappedValue != focusID else {
                        return
                    }

                    text = Self.string(for: newValue)
                }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func sanitizedDecimal(_ value: String) -> String {
        var result = ""
        var hasDecimalSeparator = false

        for character in value {
            if character.isNumber {
                result.append(character)
            } else if character == ".", !hasDecimalSeparator {
                hasDecimalSeparator = true
                result.append(character)
            }
        }

        return result
    }

    private static func string(for value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }

        return value.formatted(.number.precision(.fractionLength(0...1)))
    }
}
