import SwiftUI

struct JournalFilterSheet: View {
    let templates: [WorkoutTemplate]
    let onApply: (JournalFilter) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var workingFilter: JournalFilter
    @State private var selectedTemplateID: String

    init(templates: [WorkoutTemplate], filter: JournalFilter, onApply: @escaping (JournalFilter) -> Void) {
        self.templates = templates
        self.onApply = onApply
        _workingFilter = State(initialValue: filter)
        _selectedTemplateID = State(initialValue: filter.selectedTemplateID ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Template") {
                    Picker("Workout template", selection: $selectedTemplateID) {
                        Text("All templates").tag("")
                        ForEach(templates.filter { !$0.isArchived }) { template in
                            Text(template.name).tag(template.id.uuidString)
                        }
                    }
                }

                Section("Filters") {
                    Toggle("Favorites only", isOn: $workingFilter.favoritesOnly)

                    Picker("Date range", selection: $workingFilter.dateRange) {
                        ForEach(JournalDateRange.allCases) { range in
                            Text(range.title).tag(range)
                        }
                    }

                    TextField("Tag contains", text: $workingFilter.tagSearch)
                }
            }
            .liftKeyboardDismissable()
            .navigationTitle("Filter Journal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Reset") {
                        workingFilter = JournalFilter()
                        selectedTemplateID = ""
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        Keyboard.dismiss()
                        workingFilter.selectedTemplateID = selectedTemplateID.isEmpty ? nil : selectedTemplateID
                        onApply(workingFilter)
                        dismiss()
                    }
                }
            }
        }
    }
}
