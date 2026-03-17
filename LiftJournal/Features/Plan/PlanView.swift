import SwiftData
import SwiftUI

struct PlanView: View {
    private struct TemplateSheetItem: Identifiable {
        let id = UUID()
        let template: WorkoutTemplate?
    }

    private struct ScheduleSheetItem: Identifiable {
        let id = UUID()
        let workout: PlannedWorkout?
        let date: Date
    }

    private struct SessionSheetItem: Identifiable {
        let id = UUID()
        let draft: WorkoutSessionDraft
        let plannedWorkout: PlannedWorkout?
    }

    enum Segment: String, CaseIterable, Identifiable {
        case schedule
        case templates

        var id: String { rawValue }

        var title: String {
            switch self {
            case .schedule:
                "Schedule"
            case .templates:
                "Templates"
            }
        }
    }

    let settings: AppSettings

    @State private var selectedSegment: Segment = .schedule
    @State private var selectedDate = Date.now
    @State private var templateSheetItem: TemplateSheetItem?
    @State private var scheduleSheetItem: ScheduleSheetItem?
    @State private var sessionSheetItem: SessionSheetItem?
    @State private var shareItem: ShareURLItem?
    @Query(sort: \PlannedWorkout.scheduledFor) private var plannedWorkouts: [PlannedWorkout]
    @Query(sort: \WorkoutTemplate.updatedAt, order: .reverse) private var templates: [WorkoutTemplate]
    @Environment(\.modelContext) private var modelContext
    @Environment(AppModel.self) private var appModel

    private let calendar = Calendar.autoupdatingCurrent

    private var visibleDates: [Date] {
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: selectedDate)?.start ?? calendar.startOfDay(for: selectedDate)
        return (0..<14).compactMap { calendar.date(byAdding: .day, value: $0, to: weekStart) }
    }

    private var selectedDayWorkouts: [PlannedWorkout] {
        plannedWorkouts.filter { calendar.isDate($0.scheduledFor, inSameDayAs: selectedDate) }
    }

    private var activeTemplates: [WorkoutTemplate] {
        templates.filter { !$0.isArchived }
    }

    var body: some View {
        List {
            Section {
                Picker("Segment", selection: $selectedSegment) {
                    ForEach(Segment.allCases) { segment in
                        Text(segment.title).tag(segment)
                    }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
            }

            if selectedSegment == .schedule {
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(visibleDates, id: \.self) { date in
                                Button {
                                    selectedDate = date
                                } label: {
                                    VStack(spacing: 4) {
                                        Text(date.formatted(.dateTime.weekday(.narrow)))
                                            .font(.lift(.caption, weight: .semibold))
                                        Text(date.formatted(.dateTime.day()))
                                            .font(.lift(.headline, weight: .bold))
                                    }
                                    .frame(width: 52, height: 62)
                                    .background(
                                        calendar.isDate(date, inSameDayAs: selectedDate) ? Color.liftStrength.opacity(0.18) : Color.clear,
                                        in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }

                Section(calendar.isDateInToday(selectedDate) ? "Today" : selectedDate.formatted(date: .complete, time: .omitted)) {
                    if selectedDayWorkouts.isEmpty {
                        EmptyStateCard(
                            symbol: "calendar.badge.plus",
                            title: "Nothing planned for this day",
                            message: "Add a workout, mark a rest day, or duplicate part of the week forward."
                        )
                    } else {
                        ForEach(selectedDayWorkouts) { workout in
                            Button {
                                scheduleSheetItem = ScheduleSheetItem(workout: workout, date: workout.scheduledFor)
                            } label: {
                                PlannedWorkoutRow(workout: workout, showsCalendarState: settings.calendarSyncEnabled)
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                if !workout.isRestDay {
                                    Button {
                                        startWorkout(workout)
                                    } label: {
                                        Label("Start", systemImage: "play.fill")
                                    }
                                    .tint(.green)

                                    Button {
                                        Task {
                                            await syncCalendar(for: workout)
                                        }
                                    } label: {
                                        Label(workout.isCalendarSynced ? "Resync" : "Sync", systemImage: "calendar.badge.plus")
                                    }
                                    .tint(.blue)
                                }
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button {
                                    duplicate(workout: workout)
                                } label: {
                                    Label("Duplicate", systemImage: "plus.square.on.square")
                                }
                                .tint(.indigo)

                                Button(role: .destructive) {
                                    modelContext.delete(workout)
                                    try? modelContext.save()
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            } else {
                Section("Templates") {
                    if activeTemplates.isEmpty {
                        EmptyStateCard(
                            symbol: "square.and.pencil",
                            title: "No templates yet",
                            message: "Create one simple workout template and reuse it across the week."
                        )
                    } else {
                        ForEach(activeTemplates) { template in
                            Button {
                                templateSheetItem = TemplateSheetItem(template: template)
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(template.name)
                                        .font(.lift(.body, weight: .semibold))
                                    Text(template.summaryLine)
                                        .font(.lift(.footnote))
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button("Duplicate", systemImage: "plus.square.on.square") {
                                    duplicate(template: template)
                                }

                                Button("Archive", systemImage: "archivebox") {
                                    template.isArchived = true
                                    template.touch()
                                    try? modelContext.save()
                                }
                            }
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.liftSurface.ignoresSafeArea())
        .navigationTitle("Plan")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if selectedSegment == .schedule {
                    Menu {
                        Button("Duplicate Selected Week", systemImage: "calendar.badge.plus") {
                            duplicateSelectedWeek()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    if selectedSegment == .schedule {
                        scheduleSheetItem = ScheduleSheetItem(workout: nil, date: selectedDate)
                    } else {
                        templateSheetItem = TemplateSheetItem(template: nil)
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
            }
        }
        .sheet(item: $templateSheetItem) { item in
            TemplateEditorView(template: item.template)
        }
        .sheet(item: $scheduleSheetItem) { item in
            ScheduleWorkoutSheet(
                settings: settings,
                templates: activeTemplates,
                existingWorkout: item.workout,
                defaultDate: item.date
            ) { _, manualShareURL in
                if let manualShareURL {
                    shareItem = ShareURLItem(url: manualShareURL)
                }
            }
        }
        .sheet(item: $shareItem) { shareItem in
            ShareSheet(items: [shareItem.url])
        }
        .fullScreenCover(item: $sessionSheetItem) { item in
            WorkoutSessionView(
                draft: item.draft,
                settings: settings,
                plannedWorkout: item.plannedWorkout
            ) {
                sessionSheetItem = nil
            }
        }
    }

    private func startWorkout(_ workout: PlannedWorkout) {
        sessionSheetItem = SessionSheetItem(
            draft: WorkoutDraftFactory.session(from: workout),
            plannedWorkout: workout
        )
    }

    private func duplicate(template: WorkoutTemplate) {
        let duplicate = WorkoutTemplate(name: "\(template.name) Copy")
        TemplateDraft(template: template).apply(to: duplicate)
        modelContext.insert(duplicate)
        try? modelContext.save()
        appModel.showBanner("Template duplicated")
    }

    private func duplicate(workout: PlannedWorkout) {
        let nextWeekDate = calendar.date(byAdding: .day, value: 7, to: workout.scheduledFor) ?? workout.scheduledFor
        let duplicate = PlannedWorkout(
            sourceTemplateID: workout.sourceTemplateID,
            templateName: workout.templateName,
            notes: workout.notes,
            scheduledFor: nextWeekDate,
            durationMinutes: workout.durationMinutes,
            isRestDay: workout.isRestDay,
            templateSnapshotData: workout.templateSnapshotData
        )
        modelContext.insert(duplicate)
        try? modelContext.save()
        appModel.showBanner("Workout duplicated")
    }

    private func duplicateSelectedWeek() {
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: selectedDate) else {
            return
        }

        let workouts = plannedWorkouts.filter { weekInterval.contains($0.scheduledFor) }
        for workout in workouts {
            duplicate(workout: workout)
        }
    }

    private func syncCalendar(for workout: PlannedWorkout) async {
        do {
            let outcome = try await appModel.calendarService.sync(plannedWorkout: workout, settings: settings)
            switch outcome {
            case .synced(let payload):
                workout.calendarEventIdentifier = payload.eventIdentifier
                workout.calendarIdentifier = payload.calendarIdentifier
                workout.calendarLastSyncedAt = payload.syncedAt
                upsertCalendarRecord(payload: payload, workout: workout)
                try? modelContext.save()
                appModel.showBanner("Calendar synced")
            case .manualFallback(let url):
                shareItem = ShareURLItem(url: url)
                appModel.showBanner("Use manual add to Calendar", systemImage: "calendar.badge.exclamationmark")
            }
        } catch {
            appModel.showBanner("Couldn’t sync calendar", systemImage: "calendar.badge.exclamationmark")
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

private struct PlannedWorkoutRow: View {
    let workout: PlannedWorkout
    let showsCalendarState: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: workout.isRestDay ? "figure.cooldown" : "dumbbell")
                .foregroundStyle(workout.isRestDay ? Color.secondary : Color.accentColor)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(workout.displayName)
                        .font(.lift(.body, weight: .semibold))

                    if !workout.completedLoggedWorkoutID.isEmpty {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }

                Text(workout.scheduledFor.formatted(date: .omitted, time: .shortened))
                    .font(.lift(.footnote))
                    .foregroundStyle(.secondary)

                if let snapshot = workout.snapshot {
                    Text(snapshot.summaryLine)
                        .font(.lift(.footnote))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if showsCalendarState {
                Image(systemName: workout.isCalendarSynced ? "checkmark.icloud.fill" : "icloud.slash")
                    .foregroundStyle(workout.isCalendarSynced ? Color.accentColor : Color.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    PreviewContainer {
        NavigationStack {
            PlanView(settings: AppSettings())
        }
    }
}
