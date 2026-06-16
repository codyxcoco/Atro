import SwiftData
import SwiftUI

struct MealEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppModel.self) private var appModel
    @State private var mealName = ""
    @State private var loggedAt = Date.now
    @State private var note = ""
    private let displayedComponents: DatePickerComponents
    private let fixedDay: Date?

    init(
        defaultLoggedAt: Date = .now,
        displayedComponents: DatePickerComponents = [.date, .hourAndMinute],
        fixedDay: Date? = nil
    ) {
        self.displayedComponents = displayedComponents
        self.fixedDay = fixedDay
        _loggedAt = State(initialValue: defaultLoggedAt)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    MealEditorSectionCard(title: "Meal", systemImage: "fork.knife", tint: .liftMealsTint) {
                        VStack(alignment: .leading, spacing: 16) {
                            VStack(alignment: .leading, spacing: 8) {
                                MealEditorFieldTitle("Meal Name")
                                TextField("Meal name", text: $mealName)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .fill(Color.primary.opacity(0.05))
                                    )
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                MealEditorFieldTitle("Time")
                                DatePicker("Time", selection: $loggedAt, displayedComponents: displayedComponents)
                                    .labelsHidden()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .fill(Color.primary.opacity(0.05))
                                    )
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                MealEditorFieldTitle("Note")
                                TextField("Note", text: $note, axis: .vertical)
                                    .lineLimit(3...5)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .fill(Color.primary.opacity(0.05))
                                    )
                            }
                        }
                    }
                }
                .padding()
            }
            .liftKeyboardDismissable()
            .liftScreenBackground()
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
        Keyboard.dismiss()
        modelContext.insert(
            MealEntry(
                mealName: mealName.trimmingCharacters(in: .whitespacesAndNewlines),
                note: note.trimmingCharacters(in: .whitespacesAndNewlines),
                loggedAt: resolvedLoggedAt
            )
        )
        do {
            try modelContext.save()
            appModel.haptics.confirm()
            dismiss()
        } catch {
            appModel.showBanner("Couldn’t save meal", systemImage: "exclamationmark.triangle.fill")
        }
    }

    private var resolvedLoggedAt: Date {
        guard let fixedDay else { return loggedAt }

        let calendar = Calendar.current
        let time = calendar.dateComponents([.hour, .minute, .second], from: loggedAt)

        return calendar.date(
            bySettingHour: time.hour ?? 0,
            minute: time.minute ?? 0,
            second: time.second ?? 0,
            of: fixedDay
        ) ?? fixedDay
    }
}

private struct MealEditorSectionCard<Content: View>: View {
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

private struct MealEditorFieldTitle: View {
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
