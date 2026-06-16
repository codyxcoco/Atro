import SwiftUI

struct WorkoutSummarySheet: View {
    let settings: AppSettings
    let onSave: () -> Void

    @Bindable var viewModel: WorkoutSessionViewModel
    @Environment(\.dismiss) private var dismiss

    private var exerciseCountText: String {
        let count = viewModel.draft.exercises.count
        let noun = count == 1 ? viewModel.draft.templateKind.summaryItemName : "\(viewModel.draft.templateKind.summaryItemName)s"
        return "\(count) \(noun)"
    }

    private var setCountText: String {
        let completed = viewModel.draft.exercises.flatMap(\.sets).filter(\.isCompleted).count
        let total = viewModel.draft.exercises.reduce(0) { $0 + $1.sets.count }
        let noun = viewModel.draft.templateKind == .stretch ? "completed" : "sets"
        return "\(completed)/\(total) \(noun)"
    }

    private var durationText: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        formatter.maximumUnitCount = 2
        return formatter.string(from: max(Date.now.timeIntervalSince(viewModel.draft.startedAt), 0)) ?? "0m"
    }

    private var trimmedTemplateName: String {
        viewModel.draft.sourceTemplateName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    WorkoutSummaryHeroCard(
                        workoutName: viewModel.draft.workoutName,
                        exerciseCountText: exerciseCountText,
                        setCountText: setCountText,
                        durationText: durationText,
                        templateName: trimmedTemplateName,
                        templateKind: viewModel.draft.templateKind
                    )

                    FinishWorkoutSectionCard(
                        title: viewModel.draft.templateKind == .stretch ? "Stretch Session" : "Session",
                        systemImage: viewModel.draft.templateKind == .stretch ? "figure.cooldown" : "figure.strengthtraining.traditional",
                        tint: .accentColor
                    ) {
                        VStack(alignment: .leading, spacing: 16) {
                            VStack(alignment: .leading, spacing: 8) {
                                FinishWorkoutFieldTitle(viewModel.draft.templateKind == .stretch ? "Session Name" : "Workout Name")
                                TextField(viewModel.draft.templateKind == .stretch ? "Stretch session name" : "Workout name", text: $viewModel.draft.workoutName)
                                    .textInputAutocapitalization(.words)
                                    .modifier(FinishWorkoutFieldModifier())
                            }

                            FinishWorkoutToggleRow(
                                title: "Favorite This Entry",
                                subtitle: "Keep this one easy to find later.",
                                systemImage: "star.fill",
                                tint: Color(red: 0.96, green: 0.78, blue: 0.28),
                                isOn: $viewModel.draft.isFavorite
                            )

                            VStack(alignment: .leading, spacing: 8) {
                                FinishWorkoutFieldTitle("Tags")
                                TextField("legs, PR, morning", text: $viewModel.draft.tagText)
                                    .textInputAutocapitalization(.never)
                                    .modifier(FinishWorkoutFieldModifier())
                            }
                        }
                    }

                    FinishWorkoutSectionCard(
                        title: "Notes",
                        systemImage: "note.text",
                        tint: .liftMealsTint
                    ) {
                        VStack(alignment: .leading, spacing: 8) {
                            FinishWorkoutFieldTitle(viewModel.draft.templateKind == .stretch ? "How Did It Feel?" : "How Did It Go?")
                            TextField(
                                viewModel.draft.templateKind == .stretch ? "Any cues or recovery notes worth keeping?" : "Anything worth remembering?",
                                text: $viewModel.draft.notes,
                                axis: .vertical
                            )
                                .lineLimit(4...8)
                                .modifier(FinishWorkoutFieldModifier())
                        }
                    }

                    if settings.feelingCheckInsEnabled {
                        FinishWorkoutSectionCard(
                            title: "State of Body",
                            systemImage: "figure.walk",
                            tint: .liftBodyTint
                        ) {
                            VStack(alignment: .leading, spacing: 14) {
                                FinishWorkoutToggleRow(
                                    title: "Before Workout",
                                    subtitle: "Capture how you were coming in.",
                                    systemImage: "arrow.left.circle.fill",
                                    tint: .liftBodyTint,
                                    isOn: $viewModel.draft.includePreCheckIn
                                )

                                if viewModel.draft.includePreCheckIn {
                                    FinishWorkoutSubcard(title: "Before") {
                                        MoodDraftEditor(title: "Before", draft: $viewModel.draft.preCheckIn)
                                    }
                                }

                                FinishWorkoutToggleRow(
                                    title: "After Workout",
                                    subtitle: "Log how you feel heading out.",
                                    systemImage: "arrow.right.circle.fill",
                                    tint: .liftBodyTint,
                                    isOn: $viewModel.draft.includePostCheckIn
                                )

                                if viewModel.draft.includePostCheckIn {
                                    FinishWorkoutSubcard(title: "After") {
                                        MoodDraftEditor(title: "After", draft: $viewModel.draft.postCheckIn)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding()
                .padding(.bottom, 124)
            }
            .liftKeyboardDismissable()
            .liftScreenBackground()
            .navigationTitle(viewModel.draft.templateKind == .stretch ? "Finish Stretch" : "Finish Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Back") {
                        dismiss()
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                saveBar
            }
        }
    }

    private var saveBar: some View {
        VStack(spacing: 10) {
            if !viewModel.draft.isValid {
                Text(viewModel.draft.templateKind == .stretch ? "Add a session name and one named stretch to save." : "Add a workout name and one named exercise to save.")
                    .font(.lift(.caption, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 18)
            }

            Button {
                Keyboard.dismiss()
                onSave()
            } label: {
                Label(viewModel.draft.templateKind == .stretch ? "Save Stretch Session" : "Save Workout", systemImage: "checkmark.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(
                WorkoutGlassActionButtonStyle(
                    tint: .accentColor,
                    intensity: 0.94,
                    glowStrength: 0.24,
                    horizontalPadding: 24,
                    verticalPadding: 15
                )
            )
            .disabled(!viewModel.draft.isValid)
            .opacity(viewModel.draft.isValid ? 1 : 0.72)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
        .padding(.top, 10)
        .background(
            LinearGradient(
                colors: [
                    .clear,
                    Color.black.opacity(0.16)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}

private struct WorkoutSummaryHeroCard: View {
    let workoutName: String
    let exerciseCountText: String
    let setCountText: String
    let durationText: String
    let templateName: String
    let templateKind: WorkoutTemplateKind

    private var displayName: String {
        let trimmed = workoutName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Workout" : trimmed
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Ready to Save")
                        .font(.lift(.caption, weight: .bold))
                        .foregroundStyle(Color.accentColor)
                        .textCase(.uppercase)

                    Text(displayName)
                        .font(.lift(.title3, weight: .bold))
                }

                Spacer()

                Image(systemName: templateKind == .stretch ? "figure.cooldown" : "checkmark.circle.badge.clock")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
            }

            HStack(spacing: 10) {
                WorkoutSummaryMetricPill(value: durationText, label: "Time")
                WorkoutSummaryMetricPill(value: exerciseCountText, label: "Logged")
                WorkoutSummaryMetricPill(value: setCountText, label: "Sets")
            }

            if !templateName.isEmpty {
                Label(templateName, systemImage: "square.stack.3d.up.fill")
                    .font(.lift(.footnote, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.primary.opacity(0.05))
                    )
            }
        }
        .liftCardStyle()
    }
}

private struct WorkoutSummaryMetricPill: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.lift(.subheadline, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.82)

            Text(label)
                .font(.lift(.caption, weight: .medium))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.primary.opacity(0.05))
        )
    }
}

private struct FinishWorkoutSectionCard<Content: View>: View {
    let title: String
    let systemImage: String
    var tint: Color = .accentColor
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label {
                Text(title)
                    .font(.lift(.caption, weight: .bold))
                    .textCase(.uppercase)
            } icon: {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(tint)

            content
        }
        .liftCardStyle()
    }
}

private struct FinishWorkoutSubcard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.lift(.caption, weight: .bold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            content
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: LiftTheme.compactCornerRadius, style: .continuous)
                .fill(Color.primary.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: LiftTheme.compactCornerRadius, style: .continuous)
                .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
        )
    }
}

private struct FinishWorkoutToggleRow: View {
    let title: String
    let subtitle: String
    let systemImage: String
    var tint: Color = .accentColor
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.lift(.body, weight: .semibold))

                    Text(subtitle)
                        .font(.lift(.footnote))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .tint(tint)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: LiftTheme.compactCornerRadius, style: .continuous)
                .fill(Color.primary.opacity(0.05))
        )
    }
}

private struct FinishWorkoutFieldTitle: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.lift(.caption, weight: .bold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
    }
}

private struct FinishWorkoutFieldModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: LiftTheme.compactCornerRadius, style: .continuous)
                    .fill(Color.primary.opacity(0.05))
            )
    }
}

private struct MoodDraftEditor: View {
    let title: String
    @Binding var draft: MoodDraft

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            MoodScalePicker(
                title: title,
                prompt: nil,
                value: $draft.moodLevel,
                style: .compact
            )

            VStack(alignment: .leading, spacing: 12) {
                MoodMetricRow(title: "Energy", value: $draft.energyLevel)
                MoodMetricRow(title: "Soreness", value: $draft.sorenessLevel)
                MoodMetricRow(title: "Effort", value: $draft.effortRating)
                MoodMetricRow(title: "Confidence", value: $draft.confidenceRating)
            }
        }
    }
}

private struct MoodMetricRow: View {
    let title: String
    @Binding var value: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.lift(.subheadline, weight: .medium))

            HStack(spacing: 10) {
                ForEach(1...5, id: \.self) { level in
                    Button {
                        value = level
                    } label: {
                        Circle()
                            .fill(LiftMoodPalette.color(for: level))
                            .opacity(level <= value ? 1 : 0.28)
                            .overlay {
                                if level == value {
                                    Circle()
                                        .strokeBorder(.primary.opacity(0.18), lineWidth: 1.5)
                                }
                            }
                            .frame(width: 28, height: 28)
                            .scaleEffect(level == value ? 1.08 : 1)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(title) level \(level)")
                    .accessibilityAddTraits(level == value ? .isSelected : [])
                }
            }
        }
    }
}
