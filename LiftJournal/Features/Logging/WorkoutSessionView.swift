import SwiftData
import SwiftUI

struct WorkoutSessionView: View {
    let settings: AppSettings
    let plannedWorkout: PlannedWorkout?
    let onClose: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppModel.self) private var appModel
    @State private var viewModel: WorkoutSessionViewModel
    @State private var isSaving = false

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
            ScrollView {
                VStack(spacing: 16) {
                    headerCard

                    ForEach($viewModel.draft.exercises) { $exercise in
                        ExerciseSessionCard(exercise: $exercise) { setID in
                            viewModel.removeSet(setID, from: exercise.id)
                        } onToggleSet: { setID in
                            viewModel.completeSet(in: exercise.id, setID: setID)
                        } onAddSet: {
                            viewModel.addSet(to: exercise.id)
                        } onStartRest: { seconds in
                            viewModel.startRestTimer(seconds: seconds)
                        }
                    }
                }
                .padding()
            }
            .background(Color.liftSurface.ignoresSafeArea())
            .navigationTitle(viewModel.draft.workoutName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Finish") {
                        viewModel.showsSummary = true
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                HStack {
                    if let restTimerEndDate = viewModel.restTimerEndDate, restTimerEndDate > .now {
                        HStack(spacing: 8) {
                            Image(systemName: "timer")
                            Text(timerInterval: .now...restTimerEndDate, countsDown: true)
                                .monospacedDigit()
                        }
                        .font(.lift(.footnote, weight: .semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(.thinMaterial, in: Capsule(style: .continuous))
                    }

                    Spacer()

                    Button {
                        viewModel.showsSummary = true
                    } label: {
                        Label("Finish Workout", systemImage: "checkmark.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                .padding()
                .background(.ultraThinMaterial)
            }
            .sheet(isPresented: $viewModel.showsSummary) {
                WorkoutSummarySheet(settings: settings, onSave: saveWorkout, viewModel: viewModel)
                    .presentationDetents([.medium, .large])
            }
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(viewModel.draft.workoutName)
                .font(.lift(.title2, weight: .bold))

            HStack(spacing: 12) {
                Label {
                    Text(timerInterval: viewModel.draft.startedAt...Date.now)
                        .monospacedDigit()
                } icon: {
                    Image(systemName: "stopwatch")
                }

                Label("\(viewModel.draft.exercises.count) exercises", systemImage: "list.bullet.rectangle.portrait")
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

    private func saveWorkout() {
        guard !isSaving else {
            return
        }

        isSaving = true

        Task {
            defer { isSaving = false }
            do {
                _ = try await viewModel.finish(using: modelContext, settings: settings, appModel: appModel)
                dismiss()
                onClose()
            } catch {
                appModel.showBanner("Couldn’t save workout", systemImage: "exclamationmark.triangle.fill")
            }
        }
    }
}

private struct ExerciseSessionCard: View {
    @Binding var exercise: LoggedExerciseDraft

    let onRemoveSet: (UUID) -> Void
    let onToggleSet: (UUID) -> Void
    let onAddSet: () -> Void
    let onStartRest: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(exercise.name)
                        .font(.lift(.headline, weight: .semibold))
                    if !exercise.category.isEmpty {
                        Text(exercise.category)
                            .font(.lift(.footnote))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Button {
                    onAddSet()
                } label: {
                    Label("Add set", systemImage: "plus.circle.fill")
                }
                .font(.lift(.subheadline, weight: .semibold))
            }

            ForEach($exercise.sets) { $set in
                VStack(spacing: 10) {
                    HStack(spacing: 10) {
                        Button {
                            onToggleSet(set.id)
                            if set.isCompleted {
                                onStartRest(set.restSeconds)
                            }
                        } label: {
                            Image(systemName: set.isCompleted ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 22, weight: .medium))
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
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    HStack(spacing: 12) {
                        NumberField(title: "Reps", value: $set.actualReps)

                        if set.tracksWeight {
                            DecimalField(title: "Weight", value: $set.actualWeight)
                        }

                        if set.tracksDuration {
                            NumberField(
                                title: "Time",
                                value: Binding(
                                    get: { max(set.actualDurationSeconds / 60, 0) },
                                    set: { set.actualDurationSeconds = max($0, 0) * 60 }
                                )
                            )
                        }

                        NumberField(
                            title: "Rest",
                            value: Binding(
                                get: { max(set.restSeconds / 60, 0) },
                                set: { set.restSeconds = max($0, 0) * 60 }
                            )
                        )
                    }
                }
                .padding(14)
                .background(Color.liftCard.opacity(0.6), in: RoundedRectangle(cornerRadius: LiftTheme.compactCornerRadius, style: .continuous))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .liftCardStyle()
    }
}

private struct NumberField: View {
    let title: String
    @Binding var value: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.lift(.caption, weight: .medium))
                .foregroundStyle(.secondary)
            TextField(title, value: $value, format: .number)
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct DecimalField: View {
    let title: String
    @Binding var value: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.lift(.caption, weight: .medium))
                .foregroundStyle(.secondary)
            TextField(title, value: $value, format: .number.precision(.fractionLength(0...1)))
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
