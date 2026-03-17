import SwiftUI

struct WorkoutSummarySheet: View {
    let settings: AppSettings
    let onSave: () -> Void

    @Bindable var viewModel: WorkoutSessionViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Session") {
                    TextField("Workout name", text: $viewModel.draft.workoutName)
                    Toggle("Favorite this entry", isOn: $viewModel.draft.isFavorite)
                    TextField("Tags", text: $viewModel.draft.tagText, prompt: Text("legs, PR, morning"))
                }

                Section("Notes") {
                    TextField("How did it go?", text: $viewModel.draft.notes, axis: .vertical)
                        .lineLimit(4...8)
                }

                if settings.feelingCheckInsEnabled {
                    Section("How did it feel?") {
                        Toggle("Add a pre-workout check-in", isOn: $viewModel.draft.includePreCheckIn)
                        if viewModel.draft.includePreCheckIn {
                            MoodDraftEditor(title: "Before", draft: $viewModel.draft.preCheckIn)
                        }

                        Toggle("Add a post-workout check-in", isOn: $viewModel.draft.includePostCheckIn)
                        if viewModel.draft.includePostCheckIn {
                            MoodDraftEditor(title: "After", draft: $viewModel.draft.postCheckIn)
                        }
                    }
                }
            }
            .navigationTitle("Finish Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Back") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave()
                    }
                    .disabled(!viewModel.draft.isValid)
                }
            }
        }
    }
}

private struct MoodDraftEditor: View {
    let title: String
    @Binding var draft: MoodDraft

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.lift(.headline, weight: .semibold))

            MoodMetricRow(title: "Mood", value: $draft.moodLevel)
            MoodMetricRow(title: "Energy", value: $draft.energyLevel)
            MoodMetricRow(title: "Soreness", value: $draft.sorenessLevel)
            MoodMetricRow(title: "Effort", value: $draft.effortRating)
            MoodMetricRow(title: "Confidence", value: $draft.confidenceRating)
        }
        .padding(.vertical, 8)
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
                            .fill(level <= value ? Color.liftStrength : Color.secondary.opacity(0.18))
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(title) level \(level)")
                    .accessibilityAddTraits(level == value ? .isSelected : [])
                }
            }
        }
    }
}
