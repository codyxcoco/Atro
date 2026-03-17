import SwiftData
import SwiftUI

struct TodayView: View {
    let settings: AppSettings

    @Environment(AppModel.self) private var appModel
    @Query(sort: \WorkoutTemplate.updatedAt, order: .reverse) private var templates: [WorkoutTemplate]
    @Query(sort: \PlannedWorkout.scheduledFor) private var plannedWorkouts: [PlannedWorkout]
    @Query(sort: \MealEntry.loggedAt, order: .reverse) private var meals: [MealEntry]
    @State private var showsTemplatePicker = false
    @State private var showsTemplateEditor = false
    @State private var showsScheduleSheet = false
    @State private var showsMealSheet = false
    @State private var activeSession: SessionStart?
    @State private var shareItem: ShareURLItem?

    private var todaysWorkout: PlannedWorkout? {
        let calendar = Calendar.current
        return plannedWorkouts.first { calendar.isDateInToday($0.scheduledFor) }
    }

    private var nextWorkout: PlannedWorkout? {
        plannedWorkouts.first { $0.scheduledFor >= .now && !Calendar.current.isDateInToday($0.scheduledFor) }
    }

    private var activeTemplates: [WorkoutTemplate] {
        templates.filter { !$0.isArchived }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let todaysWorkout {
                    TodayWorkoutCard(
                        plannedWorkout: todaysWorkout,
                        caption: "Today",
                        onQuickStart: { startSession(from: todaysWorkout) },
                        onPlan: { showsScheduleSheet = true }
                    )
                } else if let nextWorkout {
                    TodayWorkoutCard(
                        plannedWorkout: nextWorkout,
                        caption: "Next up",
                        onQuickStart: { startSession(from: nextWorkout) },
                        onPlan: { showsScheduleSheet = true }
                    )
                } else {
                    TodayEmptyStateCard(
                        onCreateTemplate: { showsTemplateEditor = true },
                        onPlanWorkout: { showsScheduleSheet = true }
                    )
                }

                if settings.healthIntegrationEnabled {
                    HealthSummaryCard(summary: appModel.healthService.todaySummary)
                }

                if settings.feelingCheckInsEnabled {
                    FeelingPromptCard()
                }

                if settings.mealsEnabled {
                    MealsPreviewCard(meals: Array(meals.prefix(3)), onAddMeal: { showsMealSheet = true })
                }
            }
            .padding()
        }
        .background(Color.liftSurface.ignoresSafeArea())
        .navigationTitle("Today")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Quick Start", systemImage: "play.circle.fill") {
                        if let todaysWorkout {
                            startSession(from: todaysWorkout)
                        } else {
                            showsTemplatePicker = true
                        }
                    }

                    Button("Plan Workout", systemImage: "calendar.badge.plus") {
                        showsScheduleSheet = true
                    }

                    Button("Create Template", systemImage: "square.and.pencil") {
                        showsTemplateEditor = true
                    }

                    if settings.mealsEnabled {
                        Button("Add Meal", systemImage: "fork.knife") {
                            showsMealSheet = true
                        }
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
            }
        }
        .sheet(isPresented: $showsTemplatePicker) {
            NavigationStack {
                List(activeTemplates) { template in
                    Button {
                        activeSession = SessionStart(
                            draft: WorkoutDraftFactory.session(from: template),
                            plannedWorkout: nil
                        )
                        showsTemplatePicker = false
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(template.name)
                                .font(.lift(.body, weight: .semibold))
                            Text(template.summaryLine)
                                .font(.lift(.footnote))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .navigationTitle("Start from Template")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Close") {
                            showsTemplatePicker = false
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showsTemplateEditor) {
            TemplateEditorView()
        }
        .sheet(isPresented: $showsScheduleSheet) {
            ScheduleWorkoutSheet(
                settings: settings,
                templates: activeTemplates,
                defaultDate: .now
            ) { _, manualShareURL in
                if let manualShareURL {
                    shareItem = ShareURLItem(url: manualShareURL)
                }
            }
        }
        .sheet(item: $shareItem) { shareItem in
            ShareSheet(items: [shareItem.url])
        }
        .sheet(isPresented: $showsMealSheet) {
            MealEditorSheet()
        }
        .fullScreenCover(item: $activeSession) { session in
            WorkoutSessionView(
                draft: session.draft,
                settings: settings,
                plannedWorkout: session.plannedWorkout
            ) {
                activeSession = nil
            }
        }
    }

    private func startSession(from plannedWorkout: PlannedWorkout) {
        activeSession = SessionStart(
            draft: WorkoutDraftFactory.session(from: plannedWorkout),
            plannedWorkout: plannedWorkout
        )
    }
}

private struct TodayWorkoutCard: View {
    let plannedWorkout: PlannedWorkout
    let caption: String
    let onQuickStart: () -> Void
    let onPlan: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(caption.uppercased())
                .font(.lift(.caption, weight: .semibold))
                .foregroundStyle(.secondary)

            Text(plannedWorkout.displayName)
                .font(.lift(.title2, weight: .bold))

            HStack(spacing: 12) {
                Label(plannedWorkout.scheduledFor.formatted(date: .omitted, time: .shortened), systemImage: "clock")
                Label("\(plannedWorkout.durationMinutes) min", systemImage: "timer")
                Label(plannedWorkout.isCalendarSynced ? "Synced" : "Not synced", systemImage: plannedWorkout.isCalendarSynced ? "checkmark.icloud" : "calendar.badge.plus")
            }
            .font(.lift(.footnote, weight: .medium))
            .foregroundStyle(.secondary)

            if let snapshot = plannedWorkout.snapshot {
                Text(snapshot.summaryLine)
                    .font(.lift(.subheadline))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                Button("Quick Start", action: onQuickStart)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                Button("Plan", action: onPlan)
                    .buttonStyle(.bordered)
                    .controlSize(.large)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .liftCardStyle()
    }
}

private struct HealthSummaryCard: View {
    let summary: HealthTodaySummary

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Health", systemImage: "heart.text.square")
                .font(.lift(.headline, weight: .semibold))

            HStack {
                StatBlock(value: "\(Int(summary.exerciseMinutes))", caption: "exercise min")
                StatBlock(value: "\(Int(summary.activeEnergyKilocalories))", caption: "active kcal")
                StatBlock(value: "\(summary.workoutCount)", caption: "workouts")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .liftCardStyle()
    }
}

private struct FeelingPromptCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Feeling check-in", systemImage: "sparkles")
                .font(.lift(.headline, weight: .semibold))

            Text("A light touch is enough. Capture how you feel before or after a session whenever it helps.")
                .font(.lift(.body))
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                ForEach(1...5, id: \.self) { value in
                    Circle()
                        .fill(value == 3 ? Color.liftStrength : Color.secondary.opacity(0.18))
                        .frame(width: 24, height: 24)
                        .accessibilityLabel("Feeling level \(value)")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .liftCardStyle()
    }
}

private struct MealsPreviewCard: View {
    let meals: [MealEntry]
    let onAddMeal: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Meals", systemImage: "fork.knife")
                    .font(.lift(.headline, weight: .semibold))

                Spacer()

                Button("Add", action: onAddMeal)
                    .font(.lift(.subheadline, weight: .semibold))
            }

            if meals.isEmpty {
                Text("Meal logging is enabled, but you haven’t added anything yet.")
                    .font(.lift(.body))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(meals) { meal in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(meal.mealName)
                                .font(.lift(.body, weight: .semibold))
                            Text(meal.loggedAt.formatted(date: .omitted, time: .shortened))
                                .font(.lift(.footnote))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .liftCardStyle()
    }
}

private struct TodayEmptyStateCard: View {
    let onCreateTemplate: () -> Void
    let onPlanWorkout: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            EmptyStateCard(
                symbol: "dumbbell",
                title: "Nothing scheduled",
                message: "Keep it simple. Create a template or drop a workout onto the calendar when you’re ready."
            )

            HStack(spacing: 12) {
                Button("Create Template", action: onCreateTemplate)
                    .buttonStyle(.bordered)
                    .controlSize(.large)

                Button("Plan Workout", action: onPlanWorkout)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            }
        }
    }
}

private struct StatBlock: View {
    let value: String
    let caption: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.lift(.title3, weight: .bold))
            Text(caption)
                .font(.lift(.caption))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SessionStart: Identifiable {
    let id = UUID()
    let draft: WorkoutSessionDraft
    let plannedWorkout: PlannedWorkout?
}

#Preview {
    PreviewContainer {
        NavigationStack {
            TodayView(settings: AppSettings())
        }
    }
}
