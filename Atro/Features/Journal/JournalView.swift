import SwiftData
import SwiftUI

struct JournalView: View {
    let settings: AppSettings

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.modelContext) private var modelContext
    @Environment(AppModel.self) private var appModel
    @State private var searchText = ""
    @State private var filter = JournalFilter()

    @Query(sort: \LoggedWorkout.endedAt, order: .reverse) private var workouts: [LoggedWorkout]
    @Query(sort: \PlannedWorkout.scheduledFor) private var plannedWorkouts: [PlannedWorkout]
    @Query(sort: \WorkoutTemplate.updatedAt, order: .reverse) private var templates: [WorkoutTemplate]
    @Query(sort: \MealEntry.loggedAt, order: .reverse) private var meals: [MealEntry]
    @Query(sort: \MoodCheckIn.createdAt, order: .reverse) private var moodCheckIns: [MoodCheckIn]

    private var standaloneCheckIns: [MoodCheckIn] {
        moodCheckIns.filter { $0.workout == nil }
    }

    private var availableTemplates: [WorkoutTemplate] {
        templates.filter { !$0.isArchived }
    }

    private var selectedTemplateName: String {
        guard let selectedTemplateID = filter.selectedTemplateID,
              !selectedTemplateID.isEmpty else {
            return "Any Template"
        }

        return availableTemplates.first { $0.id.uuidString == selectedTemplateID }?.name ?? "Template"
    }

    private var filteredWorkouts: [LoggedWorkout] {
        workouts.filter { workout in
            matchesSearch(for: workout) && filter.matches(workout)
        }
    }

    private var filteredMeals: [MealEntry] {
        guard settings.mealsEnabled else { return [] }
        return meals.filter(matchesSearch(for:))
    }

    private var filteredCheckIns: [MoodCheckIn] {
        guard settings.feelingCheckInsEnabled else { return [] }
        return standaloneCheckIns.filter(matchesSearch(for:))
    }

    private var timelineItems: [JournalTimelineItem] {
        let items =
            filteredWorkouts.map(JournalTimelineItem.workout) +
            filteredMeals.map(JournalTimelineItem.meal) +
            filteredCheckIns.map(JournalTimelineItem.checkIn)

        return items.sorted { $0.date > $1.date }
    }

    private var hasAnyJournalEntries: Bool {
        !workouts.isEmpty || !filteredSourceMeals.isEmpty || !filteredSourceCheckIns.isEmpty
    }

    private var filteredSourceMeals: [MealEntry] {
        settings.mealsEnabled ? meals : []
    }

    private var filteredSourceCheckIns: [MoodCheckIn] {
        settings.feelingCheckInsEnabled ? standaloneCheckIns : []
    }

    var body: some View {
        List {
            if !hasAnyJournalEntries {
                EmptyStateCard(
                    symbol: "clock.arrow.trianglehead.counterclockwise.rotate.90",
                    title: "Your timeline is empty",
                    message: "Workouts, meals, and State of Body entries will show up here in one chronological feed."
                )
                .journalListRow()
            } else if timelineItems.isEmpty {
                JournalNoTimelineResultsView(
                    hasSearchText: !searchText.isEmpty,
                    hasActiveWorkoutFilters: filter.hasActiveSelections
                ) {
                    withAnimation(LiftMotion.selection(reduceMotion)) {
                        searchText = ""
                        clearWorkoutFilters()
                    }
                }
                .journalListRow(bottomSpacing: 0)
            } else {
                ForEach(timelineItems) { item in
                    timelineRow(for: item)
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search journal")
        .scrollContentBackground(.hidden)
        .liftScreenBackground()
        .navigationTitle("Journal")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Section("Workout Filters") {
                        Button {
                            filter.favoritesOnly.toggle()
                        } label: {
                            FilterMenuLabel(
                                title: "Favorites Only",
                                systemImage: "star.fill",
                                isSelected: filter.favoritesOnly
                            )
                        }

                        Menu {
                            ForEach(JournalDateRange.allCases) { range in
                                Button {
                                    filter.dateRange = range
                                } label: {
                                    FilterMenuLabel(title: range.title, isSelected: filter.dateRange == range)
                                }
                            }
                        } label: {
                            Label(filter.dateRange == .all ? "Any Time" : filter.dateRange.title, systemImage: "calendar")
                        }

                        if !availableTemplates.isEmpty {
                            Menu {
                                Button {
                                    filter.selectedTemplateID = nil
                                } label: {
                                    FilterMenuLabel(title: "Any Template", isSelected: filter.selectedTemplateID == nil)
                                }

                                ForEach(availableTemplates) { template in
                                    Button {
                                        filter.selectedTemplateID = template.id.uuidString
                                    } label: {
                                        FilterMenuLabel(
                                            title: template.name,
                                            isSelected: filter.selectedTemplateID == template.id.uuidString
                                        )
                                    }
                                }
                            } label: {
                                Label(selectedTemplateName, systemImage: "square.stack.3d.up")
                            }
                        }
                    }

                    if filter.hasActiveSelections {
                        Section {
                            Button("Clear Filters", systemImage: "line.3.horizontal.decrease.circle.badge.xmark") {
                                clearWorkoutFilters()
                            }
                        }
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease")
                        .foregroundStyle(filter.hasActiveSelections ? Color.accentColor : .primary)
                }
            }
        }
    }

    private func delete(workout: LoggedWorkout) {
        let loggedWorkoutID = workout.id.uuidString

        for plannedWorkout in plannedWorkouts where plannedWorkout.completedLoggedWorkoutID == loggedWorkoutID {
            plannedWorkout.completedLoggedWorkoutID = ""
            plannedWorkout.updatedAt = .now
        }

        modelContext.delete(workout)

        do {
            try modelContext.save()
            appModel.showBanner("Workout deleted", systemImage: "trash.fill")
        } catch {
            appModel.showBanner("Couldn’t delete workout", systemImage: "exclamationmark.triangle.fill")
        }
    }

    private func delete(meal: MealEntry) {
        modelContext.delete(meal)

        do {
            try modelContext.save()
            appModel.showBanner("Meal deleted", systemImage: "trash.fill")
        } catch {
            appModel.showBanner("Couldn’t delete meal", systemImage: "exclamationmark.triangle.fill")
        }
    }

    private func delete(checkIn: MoodCheckIn) {
        modelContext.delete(checkIn)

        do {
            try modelContext.save()
            appModel.showBanner("State of Body deleted", systemImage: "trash.fill")
        } catch {
            appModel.showBanner("Couldn’t delete State of Body", systemImage: "exclamationmark.triangle.fill")
        }
    }

    private func clearWorkoutFilters() {
        filter = JournalFilter()
    }

    private func matchesSearch(for workout: LoggedWorkout) -> Bool {
        let query = searchQuery
        guard !query.isEmpty else { return true }

        return workout.workoutName.localizedCaseInsensitiveContains(query) ||
            workout.notes.localizedCaseInsensitiveContains(query) ||
            workout.tags.contains(where: { $0.localizedCaseInsensitiveContains(query) })
    }

    private func matchesSearch(for meal: MealEntry) -> Bool {
        let query = searchQuery
        guard !query.isEmpty else { return true }

        return meal.mealName.localizedCaseInsensitiveContains(query) ||
            meal.note.localizedCaseInsensitiveContains(query)
    }

    private func matchesSearch(for checkIn: MoodCheckIn) -> Bool {
        let query = searchQuery
        guard !query.isEmpty else { return true }

        return checkIn.moodTitle.localizedCaseInsensitiveContains(query) ||
            checkIn.phaseValue.title.localizedCaseInsensitiveContains(query) ||
            checkIn.tags.contains(where: { $0.localizedCaseInsensitiveContains(query) })
    }

    private var searchQuery: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    @ViewBuilder
    private func timelineRow(for item: JournalTimelineItem) -> some View {
        switch item {
        case .workout(let workout):
            NavigationLink {
                LoggedWorkoutDetailView(workout: workout)
            } label: {
                JournalWorkoutRow(workout: workout)
            }
            .buttonStyle(.plain)
            .journalCardRow()
            .swipeActions(edge: .trailing) {
                Button(role: .destructive) {
                    delete(workout: workout)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }

        case .meal(let meal):
            JournalMealRow(meal: meal)
                .journalCardRow()
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        delete(meal: meal)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }

        case .checkIn(let checkIn):
            JournalCheckInRow(checkIn: checkIn)
                .journalCardRow()
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        delete(checkIn: checkIn)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
        }
    }
}

struct LoggedWorkoutDetailView: View {
    let workout: LoggedWorkout

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppModel.self) private var appModel
    @Query(sort: \LoggedWorkout.endedAt, order: .reverse) private var allWorkouts: [LoggedWorkout]

    private var attachmentCandidates: [LoggedWorkout] {
        appModel.healthService.attachmentCandidates(for: workout, among: allWorkouts)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 12) {
                        if workout.isPureHealthImport {
                            Image(systemName: workout.importedWorkoutSymbolName)
                                .font(.system(size: 28, weight: .bold))
                                .foregroundStyle(Color.liftFitnessTint)
                                .frame(width: 42, height: 42)
                                .background(Color.liftFitnessTint.opacity(0.12), in: Circle())
                                .accessibilityHidden(true)
                        }

                        Text(workout.workoutName)
                            .font(.lift(.largeTitle, weight: .bold))
                            .foregroundStyle(workout.isPureHealthImport ? Color.liftFitnessTint : .primary)
                    }

                    Text(workout.endedAt.formatted(date: .complete, time: .shortened))
                        .font(.lift(.subheadline))
                        .foregroundStyle(.secondary)

                    Text(workout.detailSummaryText)
                        .font(.lift(.body))

                    if workout.isImportedFromHealth {
                        Label(
                            workout.isPureHealthImport ? "Imported from Apple Health" : "Apple Health linked",
                            systemImage: "heart.text.square.fill"
                        )
                            .font(.lift(.footnote, weight: .semibold))
                            .foregroundStyle(Color.liftHealthTint)
                    }

                    if workout.isHealthLinkedSession, !workout.importedMetadataSummary.isEmpty {
                        Text(workout.importedMetadataSummary)
                            .font(.lift(.footnote))
                            .foregroundStyle(.secondary)
                    }

                    if !workout.sourceTemplateName.isEmpty {
                        Text("Linked template: \(workout.sourceTemplateName)")
                            .font(.lift(.footnote))
                            .foregroundStyle(.secondary)
                    }
                }
                .liftCardStyle()

                if workout.isPureHealthImport, !attachmentCandidates.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Attach to a logged workout")
                            .font(.lift(.headline, weight: .semibold))

                        Text("If this matches something you tracked in Atro, attach it so the journal keeps one workout instead of two.")
                            .font(.lift(.footnote))
                            .foregroundStyle(.secondary)

                        Menu {
                            ForEach(Array(attachmentCandidates.prefix(6))) { candidate in
                                Button {
                                    attach(to: candidate)
                                } label: {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(candidate.workoutName)
                                        Text(candidate.endedAt.formatted(date: .abbreviated, time: .shortened))
                                    }
                                }
                            }
                        } label: {
                            HStack {
                                Label("Attach Apple Workout", systemImage: "link")
                                    .font(.lift(.body, weight: .semibold))
                                Spacer()
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .liftCardStyle()
                }

                if !workout.displayNotes.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes")
                            .font(.lift(.headline, weight: .semibold))
                        Text(workout.displayNotes)
                            .font(.lift(.body))
                    }
                    .liftCardStyle()
                }

                if !workout.tags.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tags")
                            .font(.lift(.headline, weight: .semibold))
                        FlowTagView(tags: workout.tags)
                    }
                    .liftCardStyle()
                }

                if let preMood = workout.mood(for: .pre) ?? workout.mood(for: .post) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("State of Body")
                            .font(.lift(.headline, weight: .semibold))
                        Text("\(preMood.phaseValue.title): \(preMood.moodTitle) • Energy \(preMood.energyLevel)/5 • Confidence \(preMood.confidenceRating)/5")
                            .font(.lift(.body))
                        if !preMood.tags.isEmpty {
                            Text(preMood.tags.joined(separator: " • "))
                                .font(.lift(.subheadline, weight: .semibold))
                                .foregroundStyle(Color.liftBodyTint.opacity(0.82))
                        }
                    }
                    .liftCardStyle()
                }

                ForEach(workout.loggedExercises.sorted(using: SortDescriptor(\.orderIndex))) { exercise in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(exercise.name)
                            .font(.lift(.headline, weight: .semibold))

                        ForEach(exercise.loggedSets.sorted(using: SortDescriptor(\.orderIndex))) { set in
                            HStack {
                                Image(systemName: set.isCompleted ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(set.isCompleted ? Color.accentColor : Color.secondary)
                                Text("Set \(set.orderIndex + 1)")
                                Spacer()
                                if !set.detailMetricText.isEmpty {
                                    Text(set.detailMetricText)
                                }
                            }
                            .font(.lift(.subheadline))
                        }
                    }
                    .liftCardStyle()
                }
            }
            .padding()
        }
        .liftScreenBackground()
        .navigationBarTitleDisplayMode(.inline)
    }

    private func attach(to targetWorkout: LoggedWorkout) {
        do {
            try appModel.healthService.attachImportedWorkout(workout, to: targetWorkout, in: modelContext)
            appModel.showBanner("Apple workout attached", systemImage: "link")
            dismiss()
        } catch {
            appModel.showBanner("Couldn’t attach Apple workout", systemImage: "exclamationmark.triangle.fill")
        }
    }
}

private struct JournalMealRow: View {
    let meal: MealEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            JournalCardLabel(
                title: "Meal",
                systemImage: "fork.knife",
                tint: .liftMealsTint
            )

            Text(meal.mealName)
                .font(.lift(.body, weight: .semibold))

            Text(meal.loggedAt.formatted(date: .abbreviated, time: .shortened))
                .font(.lift(.footnote))
                .foregroundStyle(.secondary)

            if !meal.note.isEmpty {
                Text(meal.note)
                    .font(.lift(.subheadline))
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
        }
    }
}

private struct JournalCheckInRow: View {
    let checkIn: MoodCheckIn

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            JournalCardLabel(
                title: "State of Body",
                systemImage: "figure.stand",
                tint: .liftBodyTint
            )

            HStack(spacing: 10) {
                Circle()
                    .fill(LiftMoodPalette.color(for: checkIn.moodLevel))
                    .frame(width: 12, height: 12)

                Text(checkIn.moodTitle)
                    .font(.lift(.body, weight: .semibold))
            }

            Text(checkIn.createdAt.formatted(date: .abbreviated, time: .shortened))
                .font(.lift(.footnote))
                .foregroundStyle(.secondary)

            if !checkIn.tags.isEmpty {
                Text(checkIn.tags.joined(separator: " • "))
                    .font(.lift(.caption, weight: .semibold))
                    .foregroundStyle(Color.liftBodyTint.opacity(0.82))
                    .lineLimit(2)
            }
        }
    }
}

private struct JournalWorkoutRow: View {
    let workout: LoggedWorkout

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                JournalCardLabel(
                    title: "Workout",
                    systemImage: "dumbbell.fill",
                    tint: .accentColor
                )

                Spacer(minLength: 12)

                if workout.isFavorite {
                    Image(systemName: "star.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.yellow)
                        .accessibilityLabel("Favorite workout")
                }
            }

            if workout.isPureHealthImport {
                HStack(spacing: 10) {
                    Image(systemName: workout.importedWorkoutSymbolName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.liftFitnessTint)
                        .accessibilityHidden(true)

                    Text(workout.workoutName)
                        .font(.lift(.body, weight: .semibold))
                        .foregroundStyle(Color.liftFitnessTint)
                }
            } else {
                Text(workout.workoutName)
                    .font(.lift(.body, weight: .semibold))
                    .foregroundStyle(.primary)
            }

            Text(workout.endedAt.formatted(date: .abbreviated, time: .shortened))
                .font(.lift(.footnote))
                .foregroundStyle(.secondary)

            Text(workout.journalSummaryText)
                .font(.lift(.footnote))
                .foregroundStyle(.secondary)

            if workout.isHealthLinkedSession {
                Label("Apple Health linked", systemImage: "heart.text.square.fill")
                    .font(.lift(.caption, weight: .semibold))
                    .foregroundStyle(Color.liftHealthTint)
            }

            if !workout.displayNotes.isEmpty {
                Text(workout.displayNotes)
                    .font(.lift(.subheadline))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: LiftTheme.cardCornerRadius, style: .continuous))
    }
}

private struct JournalCardLabel: View {
    let title: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(tint)
                .accessibilityHidden(true)

            Text(title)
                .font(.lift(.caption, weight: .bold))
                .foregroundStyle(tint)
                .textCase(.uppercase)
        }
    }
}

private struct FlowTagView: View {
    let tags: [String]

    var body: some View {
        FlowLayout(tags: tags)
    }
}

private struct FilterMenuLabel: View {
    let title: String
    var systemImage: String? = nil
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            if let systemImage {
                Image(systemName: systemImage)
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
            }

            Text(title)
            Spacer()
            if isSelected {
                Image(systemName: "checkmark")
            }
        }
    }
}

private struct JournalNoTimelineResultsView: View {
    let hasSearchText: Bool
    let hasActiveWorkoutFilters: Bool
    let onClear: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Nothing matches the current timeline view.")
                .font(.lift(.headline, weight: .semibold))

            Text(message)
                .font(.lift(.body))
                .foregroundStyle(.secondary)

            Button(clearButtonTitle) {
                onClear()
            }
            .font(.lift(.subheadline, weight: .semibold))
            .foregroundStyle(Color.accentColor)
        }
        .liftCardStyle()
    }

    private var message: String {
        switch (hasSearchText, hasActiveWorkoutFilters) {
        case (true, true):
            "Try clearing your search or workout filters to bring the full journal timeline back."
        case (true, false):
            "Try a different search term for workout names, meals, check-ins, notes, or tags."
        case (false, true):
            "Try loosening the workout filters to bring more timeline entries back into view."
        case (false, false):
            "Your journal entries will show up here once they’re logged or imported."
        }
    }

    private var clearButtonTitle: String {
        switch (hasSearchText, hasActiveWorkoutFilters) {
        case (true, true):
            "Clear Search & Filters"
        case (true, false):
            "Clear Search"
        case (false, true):
            "Clear Filters"
        case (false, false):
            "Reset View"
        }
    }
}

private enum JournalTimelineItem: Identifiable {
    case workout(LoggedWorkout)
    case meal(MealEntry)
    case checkIn(MoodCheckIn)

    var id: String {
        switch self {
        case .workout(let workout):
            "workout-\(workout.id.uuidString)"
        case .meal(let meal):
            "meal-\(meal.id.uuidString)"
        case .checkIn(let checkIn):
            "checkin-\(checkIn.id.uuidString)"
        }
    }

    var date: Date {
        switch self {
        case .workout(let workout):
            workout.endedAt
        case .meal(let meal):
            meal.loggedAt
        case .checkIn(let checkIn):
            checkIn.createdAt
        }
    }
}

private struct FlowLayout: View {
    let tags: [String]

    var body: some View {
        HStack {
            WrapView(items: tags) { tag in
                Text(tag)
                    .font(.lift(.footnote, weight: .semibold))
                    .foregroundStyle(tag == "Apple Health" ? Color.liftHealthTint : .primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        (tag == "Apple Health" ? Color.liftHealthTint : Color.liftStrength)
                            .opacity(0.14),
                        in: Capsule(style: .continuous)
                    )
            }
        }
    }
}

private struct WrapView<Item: Hashable, Content: View>: View {
    let items: [Item]
    let content: (Item) -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(items, id: \.self) { item in
                content(item)
            }
        }
    }
}

private extension View {
    func journalCardRow(bottomSpacing: CGFloat = 10) -> some View {
        self
            .liftCardStyle()
            .journalListRow(bottomSpacing: bottomSpacing)
    }

    func journalListRow(bottomSpacing: CGFloat = 10) -> some View {
        self
            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: bottomSpacing, trailing: 0))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }
}

#Preview {
    PreviewContainer {
        NavigationStack {
            JournalView(settings: AppSettings())
        }
    }
}
