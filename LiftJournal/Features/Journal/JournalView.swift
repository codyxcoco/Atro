import SwiftData
import SwiftUI

struct JournalView: View {
    let settings: AppSettings

    @State private var searchText = ""
    @State private var filter = JournalFilter()
    @State private var showsFilterSheet = false
    @State private var showsMealSheet = false

    @Query(sort: \LoggedWorkout.endedAt, order: .reverse) private var workouts: [LoggedWorkout]
    @Query(sort: \WorkoutTemplate.updatedAt, order: .reverse) private var templates: [WorkoutTemplate]
    @Query(sort: \MealEntry.loggedAt, order: .reverse) private var meals: [MealEntry]

    private var filteredWorkouts: [LoggedWorkout] {
        workouts.filter { workout in
            let matchesSearch: Bool
            if searchText.isEmpty {
                matchesSearch = true
            } else {
                let query = searchText.lowercased()
                matchesSearch =
                    workout.workoutName.lowercased().contains(query) ||
                    workout.notes.lowercased().contains(query) ||
                    workout.tags.contains(where: { $0.lowercased().contains(query) })
            }

            return matchesSearch && filter.matches(workout)
        }
    }

    var body: some View {
        List {
            if settings.mealsEnabled {
                Section("Meals") {
                    if meals.isEmpty {
                        Text("No meals logged yet.")
                            .font(.lift(.body))
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(meals.prefix(5)) { meal in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(meal.mealName)
                                    .font(.lift(.body, weight: .semibold))
                                Text(meal.loggedAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.lift(.footnote))
                                    .foregroundStyle(.secondary)
                                if !meal.note.isEmpty {
                                    Text(meal.note)
                                        .font(.lift(.subheadline))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }

            ForEach(filteredWorkouts) { workout in
                NavigationLink {
                    LoggedWorkoutDetailView(workout: workout)
                } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(workout.workoutName)
                                .font(.lift(.body, weight: .semibold))

                            if workout.isFavorite {
                                Image(systemName: "star.fill")
                                    .foregroundStyle(.yellow)
                            }
                        }

                        Text(workout.endedAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.lift(.footnote))
                            .foregroundStyle(.secondary)

                        Text("\(workout.exerciseCount) exercises • \(workout.completedSetCount)/\(workout.totalSetCount) sets • \(workout.durationMinutes) min")
                            .font(.lift(.footnote))
                            .foregroundStyle(.secondary)

                        if !workout.notes.isEmpty {
                            Text(workout.notes)
                                .font(.lift(.subheadline))
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search workouts")
        .scrollContentBackground(.hidden)
        .background(Color.liftSurface.ignoresSafeArea())
        .navigationTitle("Journal")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if settings.mealsEnabled {
                    Button {
                        showsMealSheet = true
                    } label: {
                        Image(systemName: "fork.knife.circle.fill")
                    }
                }

                Button {
                    showsFilterSheet = true
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                }
            }
        }
        .sheet(isPresented: $showsFilterSheet) {
            JournalFilterSheet(templates: templates, filter: filter) { newFilter in
                filter = newFilter
            }
        }
        .sheet(isPresented: $showsMealSheet) {
            MealEditorSheet()
        }
    }
}

struct LoggedWorkoutDetailView: View {
    let workout: LoggedWorkout

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(workout.workoutName)
                        .font(.lift(.largeTitle, weight: .bold))

                    Text(workout.endedAt.formatted(date: .complete, time: .shortened))
                        .font(.lift(.subheadline))
                        .foregroundStyle(.secondary)

                    Text("\(workout.completedSetCount)/\(workout.totalSetCount) sets completed • \(Int(workout.totalVolume)) lb volume")
                        .font(.lift(.body))
                }
                .liftCardStyle()

                if !workout.notes.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes")
                            .font(.lift(.headline, weight: .semibold))
                        Text(workout.notes)
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
                        Text("Feeling")
                            .font(.lift(.headline, weight: .semibold))
                        Text("\(preMood.phaseValue.title): \(preMood.moodTitle) • Energy \(preMood.energyLevel)/5 • Confidence \(preMood.confidenceRating)/5")
                            .font(.lift(.body))
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
                                if let reps = set.actualReps ?? set.plannedReps {
                                    Text("\(reps) reps")
                                }
                                if let weight = set.actualWeight ?? set.plannedWeight {
                                    Text("\(weight.formatted(.number.precision(.fractionLength(0...1)))) lb")
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
        .background(Color.liftSurface.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct FlowTagView: View {
    let tags: [String]

    var body: some View {
        FlowLayout(tags: tags)
    }
}

private struct FlowLayout: View {
    let tags: [String]

    var body: some View {
        HStack {
            WrapView(items: tags) { tag in
                Text(tag)
                    .font(.lift(.footnote, weight: .semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.liftStrength.opacity(0.14), in: Capsule(style: .continuous))
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

#Preview {
    PreviewContainer {
        NavigationStack {
            JournalView(settings: AppSettings())
        }
    }
}
