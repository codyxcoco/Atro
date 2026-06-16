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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
        templates.filter { !$0.isArchived && $0.kind == .workout }
    }

    private var selectedWeekWorkouts: [PlannedWorkout] {
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: selectedDate) else {
            return []
        }

        return plannedWorkouts.filter { weekInterval.contains($0.scheduledFor) }
    }

    private var selectedSegmentBinding: Binding<Segment> {
        Binding(
            get: { selectedSegment },
            set: { newValue in
                withAnimation(LiftMotion.selection(reduceMotion)) {
                    selectedSegment = newValue
                }
            }
        )
    }

    var body: some View {
        List {
            Section {
                Picker("Segment", selection: selectedSegmentBinding) {
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
                                    withAnimation(LiftMotion.selection(reduceMotion)) {
                                        selectedDate = date
                                    }
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
                            message: "Add a workout, mark a rest day, or copy this week forward."
                        )
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
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
                                Button(role: .destructive) {
                                    delete(plannedWorkout: workout)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }

                                Button {
                                    duplicate(workout: workout)
                                } label: {
                                    Label("Duplicate", systemImage: "plus.square.on.square")
                                }
                                .tint(.indigo)
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
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                    } else {
                        ForEach(activeTemplates) { template in
                            Button {
                                edit(template: template)
                            } label: {
                                TemplateRowCard(template: template)
                            }
                            .buttonStyle(.plain)
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                Button {
                                    edit(template: template)
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    delete(template: template)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .contextMenu {
                                Button("Edit", systemImage: "pencil") {
                                    edit(template: template)
                                }

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
        .liftScreenBackground()
        .navigationTitle("Plan")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if selectedSegment == .schedule {
                    Button("Copy Week") {
                        duplicateSelectedWeek()
                    }
                    .disabled(selectedWeekWorkouts.isEmpty)
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
                    Image(systemName: "plus")
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
            if item.draft.templateKind == .stretch {
                StretchSessionView(
                    draft: item.draft,
                    settings: settings,
                    plannedWorkout: item.plannedWorkout
                ) {
                    sessionSheetItem = nil
                }
            } else {
                WorkoutSessionView(
                    draft: item.draft,
                    settings: settings,
                    plannedWorkout: item.plannedWorkout
                ) {
                    sessionSheetItem = nil
                }
            }
        }
    }

    private func startWorkout(_ workout: PlannedWorkout) {
        var draft = WorkoutDraftFactory.session(from: workout)
        if let progress = appModel.watchProgress(for: draft.plannedWorkoutID) {
            draft.applyWatchProgress(progress)
        }

        sessionSheetItem = SessionSheetItem(
            draft: draft,
            plannedWorkout: workout
        )
    }

    private func edit(template: WorkoutTemplate) {
        templateSheetItem = TemplateSheetItem(template: template)
    }

    private func duplicate(template: WorkoutTemplate) {
        var duplicateDraft = TemplateDraft(template: template)
        duplicateDraft.name = "\(template.name) Copy"

        let duplicate = WorkoutTemplate(name: duplicateDraft.name)
        duplicateDraft.apply(to: duplicate)
        modelContext.insert(duplicate)
        try? modelContext.save()
        appModel.showBanner("Template duplicated")
    }

    private func duplicate(workout: PlannedWorkout) {
        let duplicate = duplicatedWorkout(from: workout)
        modelContext.insert(duplicate)
        try? modelContext.save()
        appModel.showBanner("Workout duplicated")
    }

    private func duplicatedWorkout(from workout: PlannedWorkout) -> PlannedWorkout {
        let nextWeekDate = calendar.date(byAdding: .day, value: 7, to: workout.scheduledFor) ?? workout.scheduledFor

        return PlannedWorkout(
            sourceTemplateID: workout.sourceTemplateID,
            templateName: workout.templateName,
            notes: workout.notes,
            scheduledFor: nextWeekDate,
            durationMinutes: workout.durationMinutes,
            isRestDay: workout.isRestDay,
            templateSnapshotData: workout.templateSnapshotData
        )
    }

    private func delete(template: WorkoutTemplate) {
        modelContext.delete(template)

        do {
            try modelContext.save()
            appModel.showBanner("Template deleted", systemImage: "trash.fill")
        } catch {
            appModel.showBanner("Couldn’t delete template", systemImage: "exclamationmark.triangle.fill")
        }
    }

    private func delete(plannedWorkout: PlannedWorkout) {
        let plannedWorkoutID = plannedWorkout.id.uuidString
        let descriptor = FetchDescriptor<CalendarSyncRecord>(
            predicate: #Predicate { $0.plannedWorkoutID == plannedWorkoutID }
        )

        if let existingRecord = try? modelContext.fetch(descriptor).first {
            modelContext.delete(existingRecord)
        }

        modelContext.delete(plannedWorkout)

        do {
            try modelContext.save()
            appModel.showBanner("Workout deleted", systemImage: "trash.fill")
        } catch {
            appModel.showBanner("Couldn’t delete workout", systemImage: "exclamationmark.triangle.fill")
        }
    }

    private func duplicateSelectedWeek() {
        guard !selectedWeekWorkouts.isEmpty else {
            appModel.showBanner("Nothing to copy for this week", systemImage: "calendar.badge.exclamationmark")
            return
        }

        for workout in selectedWeekWorkouts {
            modelContext.insert(duplicatedWorkout(from: workout))
        }

        do {
            try modelContext.save()
            appModel.showBanner("Week copied forward", systemImage: "calendar.badge.plus")
        } catch {
            appModel.showBanner("Couldn’t copy this week", systemImage: "exclamationmark.triangle.fill")
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

private struct TemplateRowCard: View {
    let template: WorkoutTemplate

    private var exercisePreview: String? {
        let names = template.activeExercises
            .map(\.name)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !names.isEmpty else {
            return nil
        }

        let preview = names.prefix(3).joined(separator: " • ")
        return names.count > 3 ? "\(preview) +" : preview
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.accentColor.opacity(0.16))
                .frame(width: 50, height: 50)
                .overlay {
                    Image(systemName: template.kind.listSymbolName)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(template.name)
                        .font(.lift(.body, weight: .semibold))

                    if template.kind == .stretch {
                        Text("Stretch")
                            .font(.lift(.caption, weight: .bold))
                            .foregroundStyle(Color.liftStrength)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(Color.liftStrength.opacity(0.14))
                            )
                    }
                }

                Text(template.summaryLine)
                    .font(.lift(.footnote))
                    .foregroundStyle(.secondary)

                if let exercisePreview {
                    Text(exercisePreview)
                        .font(.lift(.footnote))
                        .foregroundStyle(.secondary.opacity(0.9))
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 12)

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
        .contentShape(RoundedRectangle(cornerRadius: LiftTheme.cardCornerRadius, style: .continuous))
        .liftCardStyle()
    }
}

private struct PlannedWorkoutRow: View {
    let workout: PlannedWorkout
    let showsCalendarState: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: workout.isRestDay ? "figure.cooldown" : (workout.templateKind == .stretch ? "figure.cooldown" : "dumbbell"))
                .foregroundStyle(workout.isRestDay ? Color.secondary : (workout.templateKind == .stretch ? Color.liftStrength : Color.accentColor))

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
