import SwiftData
import SwiftUI

struct TemplateEditorView: View {
    let template: WorkoutTemplate?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var draft: TemplateDraft

    init(template: WorkoutTemplate? = nil) {
        self.template = template
        _draft = State(initialValue: TemplateDraft(template: template))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Template") {
                    TextField("Template name", text: $draft.name)
                    Stepper(value: $draft.defaultDurationMinutes, in: 15...180, step: 5) {
                        Text("Duration: \(draft.defaultDurationMinutes) min")
                    }
                    TextField("Notes", text: $draft.notes, axis: .vertical)
                        .lineLimit(2...5)
                }

                Section("Exercises") {
                    ForEach($draft.exercises) { $exercise in
                        ExerciseDraftEditor(exercise: $exercise)
                    }
                    .onDelete { offsets in
                        draft.exercises.remove(atOffsets: offsets)
                        if draft.exercises.isEmpty {
                            draft.exercises.append(ExerciseDraft())
                        }
                    }
                    .onMove { source, destination in
                        draft.exercises.move(fromOffsets: source, toOffset: destination)
                    }

                    Button {
                        draft.exercises.append(ExerciseDraft())
                    } label: {
                        Label("Add Exercise", systemImage: "plus.circle.fill")
                    }
                }
            }
            .navigationTitle(template == nil ? "New Template" : "Edit Template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    EditButton()
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

    private func save() {
        let currentTemplate = template ?? WorkoutTemplate(name: draft.name)
        draft.apply(to: currentTemplate)

        if template == nil {
            modelContext.insert(currentTemplate)
        }

        try? modelContext.save()
        dismiss()
    }
}

private struct ExerciseDraftEditor: View {
    @Binding var exercise: ExerciseDraft

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            TextField("Exercise name", text: $exercise.name)
                .font(.lift(.headline, weight: .semibold))

            TextField("Category", text: $exercise.category)

            Stepper(value: $exercise.defaultSets, in: 1...10) {
                Text("Sets: \(exercise.defaultSets)")
            }

            Stepper(value: $exercise.defaultReps, in: 1...30) {
                Text("Reps: \(exercise.defaultReps)")
            }

            Toggle("Track weight", isOn: $exercise.tracksWeight)
            if exercise.tracksWeight {
                TextField("Default weight", value: $exercise.defaultWeight, format: .number.precision(.fractionLength(0...1)))
                    .keyboardType(.decimalPad)
            }

            Toggle("Track duration", isOn: $exercise.tracksDuration)
            if exercise.tracksDuration {
                Stepper(value: $exercise.defaultDurationMinutes, in: 1...90) {
                    Text("Duration: \(exercise.defaultDurationMinutes) min")
                }
            }

            Stepper(value: $exercise.defaultRestSeconds, in: 0...300, step: 15) {
                Text("Rest: \(exercise.defaultRestSeconds) sec")
            }

            TextField("Notes or instructions", text: $exercise.notes, axis: .vertical)
                .lineLimit(2...4)
        }
        .padding(.vertical, 8)
    }
}
