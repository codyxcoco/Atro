import Foundation
import SwiftData

enum SeedDataService {
    @MainActor
    static func ensureSeedData(in context: ModelContext) {
        do {
            let existingSettings = try context.fetch(FetchDescriptor<AppSettings>())
            let settings: AppSettings
            if existingSettings.isEmpty {
                settings = AppSettings(
                    hasCompletedOnboarding: true,
                    healthIntegrationEnabled: false,
                    feelingCheckInsEnabled: true,
                    mealsEnabled: true
                )
                context.insert(settings)
            } else if let currentSettings = existingSettings.first {
                settings = currentSettings
                settings.hasCompletedOnboarding = true
                settings.feelingCheckInsEnabled = true
                settings.mealsEnabled = true
                settings.touch()
            } else {
                settings = AppSettings()
            }

            let existingTemplates = try context.fetch(FetchDescriptor<WorkoutTemplate>())
            guard existingTemplates.isEmpty else {
                try context.save()
                return
            }

            let upperTemplate = WorkoutTemplate(
                name: "Upper Body",
                notes: "Keep it calm and consistent.",
                defaultDurationMinutes: 55,
                exercises: [
                    ExerciseTemplate(orderIndex: 0, name: "Bench Press", category: "Push", defaultSets: 4, defaultReps: 6, defaultWeight: 135, defaultRestSeconds: 120),
                    ExerciseTemplate(orderIndex: 1, name: "Seated Row", category: "Pull", defaultSets: 3, defaultReps: 10, defaultWeight: 90, defaultRestSeconds: 90),
                    ExerciseTemplate(orderIndex: 2, name: "Shoulder Press", category: "Shoulders", defaultSets: 3, defaultReps: 8, defaultWeight: 65, defaultRestSeconds: 90)
                ]
            )

            let lowerTemplate = WorkoutTemplate(
                name: "Lower Body",
                notes: "Move smoothly, then finish with a walk.",
                defaultDurationMinutes: 60,
                exercises: [
                    ExerciseTemplate(orderIndex: 0, name: "Back Squat", category: "Legs", defaultSets: 4, defaultReps: 5, defaultWeight: 185, defaultRestSeconds: 150),
                    ExerciseTemplate(orderIndex: 1, name: "Romanian Deadlift", category: "Posterior Chain", defaultSets: 3, defaultReps: 8, defaultWeight: 155, defaultRestSeconds: 120),
                    ExerciseTemplate(orderIndex: 2, name: "Bike Finisher", category: "Conditioning", defaultSets: 1, defaultReps: nil, defaultWeight: nil, defaultDurationSeconds: 600, defaultRestSeconds: 0)
                ]
            )

            let upperSnapshot = upperTemplate.makeSnapshot()
            let lowerSnapshot = lowerTemplate.makeSnapshot()

            let todayWorkout = PlannedWorkout(
                sourceTemplateID: upperSnapshot.sourceTemplateID,
                templateName: upperSnapshot.name,
                notes: upperSnapshot.notes,
                scheduledFor: Calendar.current.date(bySettingHour: 18, minute: 0, second: 0, of: .now) ?? .now,
                durationMinutes: upperSnapshot.durationMinutes,
                templateSnapshotData: try? JSONEncoder().encode(upperSnapshot)
            )

            let lowerDate = Calendar.current.date(byAdding: .day, value: 2, to: .now) ?? .now
            let laterWorkout = PlannedWorkout(
                sourceTemplateID: lowerSnapshot.sourceTemplateID,
                templateName: lowerSnapshot.name,
                notes: lowerSnapshot.notes,
                scheduledFor: Calendar.current.date(bySettingHour: 17, minute: 30, second: 0, of: lowerDate) ?? lowerDate,
                durationMinutes: lowerSnapshot.durationMinutes,
                templateSnapshotData: try? JSONEncoder().encode(lowerSnapshot)
            )

            let restDate = Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now
            let restDay = PlannedWorkout(
                templateName: "Rest Day",
                scheduledFor: Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: restDate) ?? restDate,
                durationMinutes: 0,
                isRestDay: true
            )

            let yesterdayStart = Calendar.current.date(byAdding: .day, value: -1, to: .now) ?? .now
            let loggedWorkout = LoggedWorkout(
                sourceTemplateID: upperSnapshot.sourceTemplateID,
                sourceTemplateName: upperSnapshot.name,
                workoutName: upperSnapshot.name,
                startedAt: Calendar.current.date(bySettingHour: 18, minute: 10, second: 0, of: yesterdayStart) ?? yesterdayStart,
                endedAt: Calendar.current.date(bySettingHour: 19, minute: 2, second: 0, of: yesterdayStart) ?? yesterdayStart,
                notes: "Felt stronger in the second half. Keep elbows tucked on bench.",
                tagText: "push, evening",
                isFavorite: true,
                loggedExercises: [
                    LoggedExercise(
                        orderIndex: 0,
                        name: "Bench Press",
                        category: "Push",
                        loggedSets: [
                            LoggedSet(orderIndex: 0, isCompleted: true, plannedReps: 6, actualReps: 6, plannedWeight: 135, actualWeight: 135),
                            LoggedSet(orderIndex: 1, isCompleted: true, plannedReps: 6, actualReps: 6, plannedWeight: 135, actualWeight: 135),
                            LoggedSet(orderIndex: 2, isCompleted: true, plannedReps: 6, actualReps: 5, plannedWeight: 135, actualWeight: 145)
                        ]
                    ),
                    LoggedExercise(
                        orderIndex: 1,
                        name: "Seated Row",
                        category: "Pull",
                        loggedSets: [
                            LoggedSet(orderIndex: 0, isCompleted: true, plannedReps: 10, actualReps: 10, plannedWeight: 90, actualWeight: 90),
                            LoggedSet(orderIndex: 1, isCompleted: true, plannedReps: 10, actualReps: 10, plannedWeight: 90, actualWeight: 95)
                        ]
                    )
                ],
                moodCheckIns: [
                    MoodCheckIn(phase: .pre, moodLevel: 3, energyLevel: 3, sorenessLevel: 2, effortRating: 3, confidenceRating: 3, createdAt: Calendar.current.date(byAdding: .minute, value: -5, to: yesterdayStart) ?? yesterdayStart),
                    MoodCheckIn(phase: .post, moodLevel: 4, energyLevel: 4, sorenessLevel: 3, effortRating: 4, confidenceRating: 4, createdAt: Calendar.current.date(byAdding: .minute, value: 55, to: yesterdayStart) ?? yesterdayStart)
                ]
            )

            let mealEntry = MealEntry(
                mealName: "Post-lift dinner",
                note: "Chicken bowl and fruit.",
                loggedAt: Calendar.current.date(bySettingHour: 20, minute: 15, second: 0, of: yesterdayStart) ?? yesterdayStart
            )

            let historicalWorkouts = historicalWorkoutSamples(calendar: Calendar.current)
            let historicalMeals = historicalMealSamples(calendar: Calendar.current)
            let historicalCheckIns = historicalCheckInSamples(calendar: Calendar.current)
            let streakCounters = streakCounterSamples(calendar: Calendar.current)

            context.insert(upperTemplate)
            context.insert(lowerTemplate)
            context.insert(todayWorkout)
            context.insert(laterWorkout)
            context.insert(restDay)
            context.insert(loggedWorkout)
            context.insert(mealEntry)

            historicalWorkouts.forEach(context.insert)
            historicalMeals.forEach(context.insert)
            historicalCheckIns.forEach(context.insert)
            streakCounters.forEach(context.insert)

            try context.save()
        } catch {
            assertionFailure("Failed to seed data: \(error)")
        }
    }

    private static func streakCounterSamples(calendar: Calendar) -> [StreakCounter] {
        let today = calendar.startOfDay(for: .now)
        let trainingStart = calendar.date(byAdding: .day, value: -23, to: today) ?? today
        let burnoutStart = calendar.date(byAdding: .day, value: -11, to: today) ?? today
        let previousResetDate = calendar.date(byAdding: .day, value: -23, to: trainingStart) ?? trainingStart

        let trainingCounter = StreakCounter(
            title: "Training Streak",
            subtitle: "Steady training rhythm",
            phrase: "current streak",
            symbolName: "figure.strengthtraining.traditional",
            theme: .strength,
            lastIncidentDate: trainingStart,
            goalDays: 90,
            isPinned: true
        )
        trainingCounter.incidents = [
            StreakIncident(
                date: previousResetDate,
                note: "Reduced load for a week and rebuilt gradually.",
                previousStreakLength: 34
            )
        ]

        let burnoutCounter = StreakCounter(
            title: "Recovery Streak",
            subtitle: "Capacity and consistency",
            phrase: "current streak",
            symbolName: "brain.head.profile",
            theme: .focus,
            lastIncidentDate: burnoutStart,
            goalDays: 30
        )

        return [trainingCounter, burnoutCounter]
    }

    private static func historicalWorkoutSamples(calendar: Calendar) -> [LoggedWorkout] {
        let today = calendar.startOfDay(for: .now)

        return (1...8).flatMap { weekOffset -> [LoggedWorkout] in
            let weekAnchor = calendar.date(byAdding: .day, value: -(weekOffset * 7), to: today) ?? today
            let isSteadyWeek = weekOffset % 2 == 0
            let workoutDays = isSteadyWeek ? [1, 3, 5] : [2]

            return workoutDays.enumerated().map { index, dayOffset in
                let day = calendar.date(byAdding: .day, value: dayOffset, to: weekAnchor) ?? weekAnchor
                let start = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: day) ?? day
                let end = calendar.date(byAdding: .minute, value: isSteadyWeek ? 58 : 42, to: start) ?? start

                return LoggedWorkout(
                    sourceTemplateName: isSteadyWeek ? "Upper Body" : "Quick Session",
                    workoutName: isSteadyWeek ? (index % 2 == 0 ? "Upper Body" : "Lower Body") : "Quick Session",
                    startedAt: start,
                    endedAt: end,
                    notes: isSteadyWeek ? "Moved well and felt steady." : "Short on recovery and felt a little rushed.",
                    tagText: isSteadyWeek ? "steady, routine" : "busy, rushed",
                    loggedExercises: [
                        LoggedExercise(
                            orderIndex: 0,
                            name: isSteadyWeek ? "Bench Press" : "Goblet Squat",
                            category: "Main Lift",
                            loggedSets: [
                                LoggedSet(orderIndex: 0, isCompleted: true, actualReps: 8, actualWeight: isSteadyWeek ? 135 : 70, restSeconds: 90),
                                LoggedSet(orderIndex: 1, isCompleted: true, actualReps: 8, actualWeight: isSteadyWeek ? 135 : 70, restSeconds: 90),
                                LoggedSet(orderIndex: 2, isCompleted: true, actualReps: 8, actualWeight: isSteadyWeek ? 135 : 70, restSeconds: 90)
                            ]
                        ),
                        LoggedExercise(
                            orderIndex: 1,
                            name: isSteadyWeek ? "Seated Row" : "Bike",
                            category: isSteadyWeek ? "Pull" : "Conditioning",
                            loggedSets: [
                                LoggedSet(orderIndex: 0, isCompleted: true, actualReps: isSteadyWeek ? 10 : nil, actualWeight: isSteadyWeek ? 90 : nil, actualDurationSeconds: isSteadyWeek ? nil : 600, restSeconds: 60)
                            ]
                        )
                    ]
                )
            }
        }
    }

    private static func historicalMealSamples(calendar: Calendar) -> [MealEntry] {
        let today = calendar.startOfDay(for: .now)
        var entries: [MealEntry] = []

        for weekOffset in 1...8 {
            let weekAnchor = calendar.date(byAdding: .day, value: -(weekOffset * 7), to: today) ?? today
            let isSteadyWeek = weekOffset % 2 == 0

            for dayOffset in 0..<5 {
                let day = calendar.date(byAdding: .day, value: dayOffset, to: weekAnchor) ?? weekAnchor
                let lunch = calendar.date(bySettingHour: 12, minute: 30, second: 0, of: day) ?? day

                if isSteadyWeek || dayOffset < 2 {
                    entries.append(
                        MealEntry(
                            mealName: isSteadyWeek ? "Chicken bowl" : "Pizza",
                            note: isSteadyWeek ? "Chicken, rice, and fruit." : "Pizza night after a long day.",
                            loggedAt: lunch
                        )
                    )
                }
            }
        }

        return entries
    }

    private static func historicalCheckInSamples(calendar: Calendar) -> [MoodCheckIn] {
        let today = calendar.startOfDay(for: .now)
        var checkIns: [MoodCheckIn] = []

        for weekOffset in 1...8 {
            let weekAnchor = calendar.date(byAdding: .day, value: -(weekOffset * 7), to: today) ?? today
            let isSteadyWeek = weekOffset % 2 == 0

            for dayOffset in 0..<5 {
                let day = calendar.date(byAdding: .day, value: dayOffset, to: weekAnchor) ?? weekAnchor
                let createdAt = calendar.date(bySettingHour: 20, minute: 0, second: 0, of: day) ?? day

                let moodLevel: Int
                let tags: String

                if isSteadyWeek {
                    moodLevel = dayOffset == 4 ? 4 : 5
                    tags = dayOffset == 2 ? "Recovered, steady" : "Calm, good energy"
                } else {
                    moodLevel = dayOffset == 1 ? 2 : 3
                    tags = dayOffset == 1 ? "Stress, low energy" : "Heavy, sore"
                }

                checkIns.append(
                    MoodCheckIn(
                        phase: .checkIn,
                        moodLevel: moodLevel,
                        tagText: tags,
                        createdAt: createdAt
                    )
                )
            }
        }

        return checkIns
    }
}
