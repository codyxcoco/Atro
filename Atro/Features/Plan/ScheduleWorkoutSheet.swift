import SwiftData
import SwiftUI

struct ScheduleWorkoutSheet: View {
    let settings: AppSettings
    let templates: [WorkoutTemplate]
    let existingWorkout: PlannedWorkout?
    let defaultDate: Date
    let onSave: (PlannedWorkout, URL?) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppModel.self) private var appModel

    @State private var scheduledFor: Date
    @State private var selectedTemplateID: String
    @State private var durationMinutes: Int
    @State private var notes: String
    @State private var isRestDay: Bool
    @State private var syncToCalendar: Bool
    @State private var isSaving = false

    init(
        settings: AppSettings,
        templates: [WorkoutTemplate],
        existingWorkout: PlannedWorkout? = nil,
        defaultDate: Date = .now,
        onSave: @escaping (PlannedWorkout, URL?) -> Void
    ) {
        self.settings = settings
        self.templates = templates
        self.existingWorkout = existingWorkout
        self.defaultDate = defaultDate
        self.onSave = onSave

        let selectedTemplateID = existingWorkout?.sourceTemplateID ?? templates.first?.id.uuidString ?? ""
        _scheduledFor = State(initialValue: existingWorkout?.scheduledFor ?? defaultDate)
        _selectedTemplateID = State(initialValue: selectedTemplateID)
        _durationMinutes = State(initialValue: existingWorkout?.durationMinutes ?? templates.first?.defaultDurationMinutes ?? settings.defaultCalendarDurationMinutes)
        _notes = State(initialValue: existingWorkout?.notes ?? "")
        _isRestDay = State(initialValue: existingWorkout?.isRestDay ?? false)
        _syncToCalendar = State(initialValue: existingWorkout?.isCalendarSynced ?? false)
    }

    private var selectedTemplate: WorkoutTemplate? {
        templates.first { $0.id.uuidString == selectedTemplateID }
    }

    private var availableTemplates: [WorkoutTemplate] {
        templates.filter { !$0.isArchived }
    }

    private var canSave: Bool {
        isRestDay || selectedTemplate != nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ScheduleSheetSectionCard(title: "Day", systemImage: "calendar") {
                        VStack(alignment: .leading, spacing: 16) {
                            VStack(alignment: .leading, spacing: 8) {
                                ScheduleSheetFieldTitle("Date & Time")

                                DatePicker("Date & Time", selection: $scheduledFor)
                                    .labelsHidden()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .fill(Color.primary.opacity(0.05))
                                    )
                            }

                            Toggle("Rest day", isOn: $isRestDay)
                                .toggleStyle(.switch)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .fill(Color.primary.opacity(0.05))
                                )
                        }
                    }

                    if !isRestDay {
                        ScheduleSheetSectionCard(title: "Workout", systemImage: "dumbbell.fill") {
                            VStack(alignment: .leading, spacing: 16) {
                                VStack(alignment: .leading, spacing: 8) {
                                    ScheduleSheetFieldTitle("Template")

                                    Menu {
                                        if availableTemplates.isEmpty {
                                            Button("No templates yet") {}
                                                .disabled(true)
                                        } else {
                                            ForEach(availableTemplates) { template in
                                                Button {
                                                    selectedTemplateID = template.id.uuidString
                                                } label: {
                                                    Label(template.name, systemImage: template.id.uuidString == selectedTemplateID ? "checkmark" : "circle")
                                                }
                                            }
                                        }
                                    } label: {
                                        HStack(spacing: 12) {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(selectedTemplate?.name ?? "Choose a template")
                                                    .font(.lift(.body, weight: .semibold))
                                                    .foregroundStyle(availableTemplates.isEmpty ? .secondary : .primary)

                                                Text(selectedTemplate?.summaryLine ?? "Pick a saved template to plan from.")
                                                    .font(.lift(.footnote))
                                                    .foregroundStyle(.secondary)
                                            }

                                            Spacer()

                                            Image(systemName: "chevron.up.chevron.down")
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundStyle(.secondary)
                                        }
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 12)
                                        .background(
                                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                                .fill(Color.primary.opacity(0.05))
                                        )
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(availableTemplates.isEmpty)
                                }

                                Stepper(value: $durationMinutes, in: 15...180, step: 5) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        ScheduleSheetFieldTitle("Duration")
                                        Text("\(durationMinutes) min")
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
                                    ScheduleSheetFieldTitle("Notes")
                                    TextField("Optional notes", text: $notes, axis: .vertical)
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

                        if settings.calendarSyncEnabled {
                            ScheduleSheetSectionCard(title: "Calendar", systemImage: "calendar.badge.plus") {
                                Toggle("Sync to Calendar after saving", isOn: $syncToCalendar)
                                    .toggleStyle(.switch)
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
            .navigationTitle(existingWorkout == nil ? "Plan Workout" : "Edit Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await save()
                        }
                    }
                    .disabled(!canSave || isSaving)
                }
            }
            .onChange(of: selectedTemplateID) { _, _ in
                if let selectedTemplate {
                    durationMinutes = selectedTemplate.defaultDurationMinutes
                    if notes.isEmpty {
                        notes = selectedTemplate.notes
                    }
                }
            }
        }
    }

    private func save() async {
        guard !isSaving else {
            return
        }

        Keyboard.dismiss()
        isSaving = true
        defer { isSaving = false }

        let workout = existingWorkout ?? PlannedWorkout(templateName: "", scheduledFor: scheduledFor)
        workout.scheduledFor = scheduledFor
        workout.updatedAt = .now

        if isRestDay {
            workout.isRestDay = true
            workout.sourceTemplateID = ""
            workout.templateName = "Rest Day"
            workout.notes = ""
            workout.durationMinutes = 0
            workout.templateSnapshotData = nil
        } else if let selectedTemplate {
            let snapshot = selectedTemplate.makeSnapshot()
            workout.applySnapshot(snapshot)
            workout.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
            workout.durationMinutes = durationMinutes
            workout.isRestDay = false
        }

        if existingWorkout == nil {
            modelContext.insert(workout)
        }

        var manualShareURL: URL?

        if syncToCalendar && !isRestDay {
            do {
                let outcome = try await appModel.calendarService.sync(plannedWorkout: workout, settings: settings)
                switch outcome {
                case .synced(let payload):
                    workout.calendarEventIdentifier = payload.eventIdentifier
                    workout.calendarIdentifier = payload.calendarIdentifier
                    workout.calendarLastSyncedAt = payload.syncedAt
                    upsertCalendarRecord(payload: payload, workout: workout)
                    appModel.showBanner("Synced to Calendar")
                case .manualFallback(let url):
                    workout.calendarEventIdentifier = ""
                    workout.calendarIdentifier = ""
                    workout.calendarLastSyncedAt = nil
                    manualShareURL = url
                    appModel.showBanner("Calendar access denied", systemImage: "calendar.badge.exclamationmark")
                }
            } catch {
                manualShareURL = nil
                appModel.showBanner("Couldn’t sync calendar", systemImage: "calendar.badge.exclamationmark")
            }
        }

        do {
            try modelContext.save()
            appModel.haptics.confirm()
            onSave(workout, manualShareURL)
            dismiss()
        } catch {
            appModel.showBanner("Couldn’t save workout plan", systemImage: "exclamationmark.triangle.fill")
        }
    }

    private func upsertCalendarRecord(payload: CalendarSyncPayload, workout: PlannedWorkout) {
        let plannedWorkoutID = workout.id.uuidString
        let descriptor = FetchDescriptor<CalendarSyncRecord>(
            predicate: #Predicate { $0.plannedWorkoutID == plannedWorkoutID }
        )
        if let existingRecord = try? modelContext.fetch(descriptor).first {
            existingRecord.eventIdentifier = payload.eventIdentifier
            existingRecord.calendarIdentifier = payload.calendarIdentifier
            existingRecord.titleSnapshot = payload.title
            existingRecord.notesSnapshot = payload.notes
            existingRecord.syncedAt = payload.syncedAt
        } else {
            modelContext.insert(
                CalendarSyncRecord(
                    plannedWorkoutID: workout.id.uuidString,
                    eventIdentifier: payload.eventIdentifier,
                    calendarIdentifier: payload.calendarIdentifier,
                    titleSnapshot: payload.title,
                    notesSnapshot: payload.notes,
                    syncedAt: payload.syncedAt
                )
            )
        }
    }
}

private struct ScheduleSheetSectionCard<Content: View>: View {
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

private struct ScheduleSheetFieldTitle: View {
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
