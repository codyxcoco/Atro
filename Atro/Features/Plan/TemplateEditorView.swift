import SwiftData
import SwiftUI

struct TemplateEditorView: View {
    let template: WorkoutTemplate?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppModel.self) private var appModel
    @State private var draft: TemplateDraft

    init(template: WorkoutTemplate? = nil) {
        self.template = template

        var initialDraft = TemplateDraft(template: template)
        if template == nil {
            initialDraft.kind = .workout
            initialDraft.exercises = [ExerciseDraft(template: nil, kind: .workout)]
        }

        _draft = State(initialValue: initialDraft)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    TemplateEditorSectionCard(title: "Template", systemImage: "square.and.pencil") {
                        VStack(alignment: .leading, spacing: 16) {
                            VStack(alignment: .leading, spacing: 8) {
                                TemplateEditorFieldTitle("Template Name")
                                TextField("Template name", text: $draft.name)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .fill(Color.primary.opacity(0.05))
                                    )
                            }

                            Stepper(value: $draft.defaultDurationMinutes, in: 15...180, step: 5) {
                                VStack(alignment: .leading, spacing: 4) {
                                    TemplateEditorFieldTitle("Duration")
                                    Text("\(draft.defaultDurationMinutes) min")
                                        .font(.lift(.body, weight: .semibold))
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(Color.primary.opacity(0.05))
                            )

                            VStack(alignment: .leading, spacing: 8) {
                                TemplateEditorFieldTitle("Notes")
                                TextField("Notes", text: $draft.notes, axis: .vertical)
                                    .lineLimit(3...6)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .fill(Color.primary.opacity(0.05))
                                    )
                            }
                        }
                    }

                    TemplateEditorSectionCard(
                        title: draft.kind.templateSectionTitle,
                        systemImage: "list.bullet.rectangle.portrait"
                    ) {
                        VStack(alignment: .leading, spacing: 14) {
                            ForEach($draft.exercises) { $exercise in
                                let exerciseID = exercise.id

                                if let currentIndex = index(of: exerciseID) {
                                    ExerciseDraftEditor(
                                        exercise: $exercise,
                                        kind: draft.kind,
                                        index: currentIndex,
                                        canMoveUp: currentIndex > 0,
                                        canMoveDown: currentIndex < draft.exercises.count - 1,
                                        canDelete: draft.exercises.count > 1,
                                        onMoveUp: { moveExercise(id: exerciseID, offset: -1) },
                                        onMoveDown: { moveExercise(id: exerciseID, offset: 1) },
                                        onDelete: { removeExercise(id: exerciseID) }
                                    )
                                }
                            }

                            Button {
                                draft.exercises.append(ExerciseDraft(template: nil, kind: draft.kind))
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 18, weight: .semibold))
                                    Text("Add Exercise")
                                        .font(.lift(.body, weight: .semibold))
                                }
                                .foregroundStyle(Color.accentColor)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .fill(Color.accentColor.opacity(0.10))
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding()
            }
            .liftKeyboardDismissable()
            .liftScreenBackground()
            .navigationTitle(template == nil ? "New Template" : "Edit Template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .disabled(!draft.canSave)
                }
            }
        }
    }

    private func index(of exerciseID: UUID) -> Int? {
        draft.exercises.firstIndex { $0.id == exerciseID }
    }

    private func removeExercise(id exerciseID: UUID) {
        guard let index = index(of: exerciseID) else { return }
        draft.exercises.remove(at: index)

        if draft.exercises.isEmpty {
            draft.exercises.append(ExerciseDraft(template: nil, kind: draft.kind))
        }
    }

    private func moveExercise(id exerciseID: UUID, offset: Int) {
        guard let source = index(of: exerciseID) else { return }
        let destination = source + offset
        guard draft.exercises.indices.contains(destination) else { return }

        let exercise = draft.exercises.remove(at: source)
        draft.exercises.insert(exercise, at: destination)
    }

    private func save() {
        Keyboard.dismiss()
        let currentTemplate = template ?? WorkoutTemplate(name: draft.name)
        draft.apply(to: currentTemplate)

        if template == nil {
            modelContext.insert(currentTemplate)
        }

        do {
            try modelContext.save()
            appModel.haptics.confirm()
            dismiss()
        } catch {
            appModel.showBanner("Couldn’t save template", systemImage: "exclamationmark.triangle.fill")
        }
    }
}

private struct ExerciseDraftEditor: View {
    @Binding var exercise: ExerciseDraft
    let kind: WorkoutTemplateKind
    let index: Int
    let canMoveUp: Bool
    let canMoveDown: Bool
    let canDelete: Bool
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(kind.templateItemTitle) \(index + 1)")
                        .font(.lift(.caption, weight: .bold))
                        .foregroundStyle(Color.accentColor)
                        .textCase(.uppercase)

                    if !exercise.name.isEmpty {
                        Text(exercise.name)
                            .font(.lift(.headline, weight: .semibold))
                    }
                }

                Spacer()

                HStack(spacing: 8) {
                    Button(action: onMoveUp) {
                        Image(systemName: "arrow.up")
                    }
                    .disabled(!canMoveUp)

                    Button(action: onMoveDown) {
                        Image(systemName: "arrow.down")
                    }
                    .disabled(!canMoveDown)

                    Button(role: .destructive, action: onDelete) {
                        Image(systemName: "trash")
                    }
                    .disabled(!canDelete)
                }
                .font(.system(size: 14, weight: .semibold))
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                TemplateEditorFieldTitle(kind == .stretch ? "Stretch Name" : "Exercise Name")
                TextField(kind == .stretch ? "Stretch name" : "Exercise name", text: $exercise.name)
                    .font(.lift(.headline, weight: .semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.primary.opacity(0.05))
                    )
            }

            if kind == .workout {
                VStack(alignment: .leading, spacing: 8) {
                    TemplateEditorFieldTitle("Category")
                    TextField("Category", text: $exercise.category)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color.primary.opacity(0.05))
                        )
                }

                Stepper(value: $exercise.defaultSets, in: 1...10) {
                    VStack(alignment: .leading, spacing: 4) {
                        TemplateEditorFieldTitle("Sets")
                        Text("\(exercise.defaultSets)")
                            .font(.lift(.body, weight: .semibold))
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.primary.opacity(0.05))
                )

                Stepper(value: $exercise.defaultReps, in: 1...30) {
                    VStack(alignment: .leading, spacing: 4) {
                        TemplateEditorFieldTitle("Reps")
                        Text("\(exercise.defaultReps)")
                            .font(.lift(.body, weight: .semibold))
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.primary.opacity(0.05))
                )

                Toggle("Track weight", isOn: $exercise.tracksWeight)
                    .toggleStyle(.switch)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.primary.opacity(0.05))
                    )

                if exercise.tracksWeight {
                    VStack(alignment: .leading, spacing: 8) {
                        TemplateEditorFieldTitle("Default Weight")
                        TextField("Default weight", value: $exercise.defaultWeight, format: .number.precision(.fractionLength(0...1)))
                            .keyboardType(.decimalPad)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(Color.primary.opacity(0.05))
                            )
                    }
                }

                Toggle("Track duration", isOn: $exercise.tracksDuration)
                    .toggleStyle(.switch)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.primary.opacity(0.05))
                    )

                if exercise.tracksDuration {
                    durationField(range: 1...90)
                }

                Stepper(value: $exercise.defaultRestSeconds, in: 0...300, step: 15) {
                    VStack(alignment: .leading, spacing: 4) {
                        TemplateEditorFieldTitle("Rest")
                        Text("\(exercise.defaultRestSeconds) sec")
                            .font(.lift(.body, weight: .semibold))
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.primary.opacity(0.05))
                )
            } else {
                durationField(range: 1...30)
            }

            VStack(alignment: .leading, spacing: 8) {
                TemplateEditorFieldTitle(kind == .stretch ? "Instructions" : "Notes or Instructions")
                TextField(kind == .stretch ? "Coaching cues or breathing instructions" : "Notes or instructions", text: $exercise.notes, axis: .vertical)
                    .lineLimit(2...4)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.primary.opacity(0.05))
                    )
            }
        }
        .onAppear {
            exercise.normalize(for: kind)
        }
        .liftCardStyle()
    }

    @ViewBuilder
    private func durationField(range: ClosedRange<Int>) -> some View {
        Stepper(value: $exercise.defaultDurationMinutes, in: range) {
            VStack(alignment: .leading, spacing: 4) {
                TemplateEditorFieldTitle("Duration")
                Text("\(exercise.defaultDurationMinutes) min")
                    .font(.lift(.body, weight: .semibold))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.primary.opacity(0.05))
        )
    }
}

private struct TemplateEditorSectionCard<Content: View>: View {
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

private struct TemplateEditorFieldTitle: View {
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
