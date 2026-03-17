import SwiftData
import SwiftUI

struct MealEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var mealName = ""
    @State private var loggedAt = Date.now
    @State private var note = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Meal") {
                    TextField("Meal name", text: $mealName)
                    DatePicker("Time", selection: $loggedAt)
                    TextField("Note", text: $note, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle("Add Meal")
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
                    .disabled(mealName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func save() {
        modelContext.insert(
            MealEntry(
                mealName: mealName.trimmingCharacters(in: .whitespacesAndNewlines),
                note: note.trimmingCharacters(in: .whitespacesAndNewlines),
                loggedAt: loggedAt
            )
        )
        try? modelContext.save()
        dismiss()
    }
}
