import SwiftUI

struct WatchHomeView: View {
    let appModel: WatchAppModel

    var body: some View {
        @Bindable var appModel = appModel

        NavigationStack {
            Group {
                if let activeSession = appModel.activeSession {
                    WatchSessionView(
                        session: activeSession,
                        onToggleSet: appModel.toggleSet,
                        onFinish: appModel.finishSession,
                        onClear: appModel.clearSession
                    )
                } else {
                    List {
                        Section {
                            snapshotCard(snapshot: appModel.snapshot)
                        }

                        if let workout = appModel.snapshot?.workout, !workout.exercises.isEmpty {
                            Section("Exercises") {
                                ForEach(workout.exercises) { exercise in
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(exercise.name)
                                            .font(.headline)

                                        Text(exerciseSummary(for: exercise))
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }

                        if let errorMessage = appModel.errorMessage {
                            Section {
                                Text(errorMessage)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Section {
                            Button {
                                appModel.refresh()
                            } label: {
                                Label(appModel.isRefreshing ? "Refreshing..." : "Refresh from iPhone", systemImage: "arrow.clockwise")
                            }
                            .disabled(appModel.isRefreshing)

                            if let workout = appModel.snapshot?.workout, !workout.isRestDay {
                                Button {
                                    appModel.startSession()
                                } label: {
                                    Label("Start checklist", systemImage: "play.fill")
                                }
                            }
                        } footer: {
                            Text("The watch uses the workout planned on your iPhone and syncs checklist progress back.")
                        }
                    }
                }
            }
            .navigationTitle("Atro")
        }
        .task {
            if appModel.snapshot == nil {
                appModel.refresh()
            }
        }
    }

    @ViewBuilder
    private func snapshotCard(snapshot: WatchWorkoutSnapshot?) -> some View {
        if let workout = snapshot?.workout {
            VStack(alignment: .leading, spacing: 6) {
                Text(snapshot?.label.uppercased() ?? "TODAY")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Text(workout.title)
                    .font(.headline)

                Text(workout.summaryLine)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Text(workout.scheduledFor.formatted(date: .omitted, time: .shortened))
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if !workout.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(workout.notes)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Text("Nothing queued")
                    .font(.headline)

                Text("Open Atro on your iPhone to push today’s or next workout to the watch.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func exerciseSummary(for exercise: WatchWorkoutExercise) -> String {
        let setCount = exercise.sets.count
        let setLabel = setCount == 1 ? "set" : "sets"

        if let firstSet = exercise.sets.first {
            if let plannedDurationSeconds = firstSet.plannedDurationSeconds, plannedDurationSeconds > 0 {
                return "\(setCount) \(setLabel) • \(plannedDurationSeconds / 60) min"
            }

            var fragments = ["\(setCount) \(setLabel)"]

            if let plannedReps = firstSet.plannedReps, plannedReps > 0 {
                fragments.append("\(plannedReps) reps")
            }

            if let plannedWeight = firstSet.plannedWeight, plannedWeight > 0 {
                fragments.append("\(plannedWeight.formatted(.number.precision(.fractionLength(0...1)))) lb")
            }

            return fragments.joined(separator: " • ")
        }

        return "\(setCount) \(setLabel)"
    }
}

private struct WatchSessionView: View {
    let session: WatchSessionState
    let onToggleSet: (UUID, UUID) -> Void
    let onFinish: () -> Void
    let onClear: () -> Void

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text(session.workout.title)
                        .font(.headline)

                    WatchElapsedTimeLabel(startedAt: session.startedAt)
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Text(session.completionText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            ForEach(session.exercises) { exercise in
                Section(exercise.name) {
                    ForEach(exercise.sets) { set in
                        Button {
                            onToggleSet(exercise.id, set.id)
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: set.isCompleted ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(set.isCompleted ? Color.green : Color.secondary)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Set \(set.orderIndex + 1)")
                                        .font(.body.weight(.semibold))

                                    Text(setSummary(for: set))
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    if !exercise.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(exercise.notes)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                if session.finishedAt == nil {
                    Button("Finish checklist", action: onFinish)
                } else {
                    Button("Clear checklist", role: .destructive, action: onClear)
                }
            } footer: {
                if session.finishedAt == nil {
                    Text("Use this as a quick wrist checklist while you train. Save the full journal entry on iPhone.")
                } else {
                    Text("This checklist is finished and synced. Clear it when you’re ready for the next workout.")
                }
            }
        }
        .navigationTitle("Workout")
    }

    private func setSummary(for set: WatchSessionSetState) -> String {
        if let plannedDurationSeconds = set.plannedDurationSeconds, plannedDurationSeconds > 0 {
            return "\(plannedDurationSeconds / 60) min • \(set.restSeconds)s rest"
        }

        var fragments: [String] = []

        if let plannedReps = set.plannedReps, plannedReps > 0 {
            fragments.append("\(plannedReps) reps")
        }

        if let plannedWeight = set.plannedWeight, plannedWeight > 0 {
            fragments.append("\(plannedWeight.formatted(.number.precision(.fractionLength(0...1)))) lb")
        }

        fragments.append("\(set.restSeconds)s rest")
        return fragments.joined(separator: " • ")
    }
}

private struct WatchElapsedTimeLabel: View {
    let startedAt: Date

    var body: some View {
        TimelineView(.periodic(from: startedAt, by: 1)) { context in
            Text(elapsedString(from: context.date))
        }
    }

    private func elapsedString(from currentDate: Date) -> String {
        let totalSeconds = max(Int(currentDate.timeIntervalSince(startedAt)), 0)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d elapsed", minutes, seconds)
    }
}
