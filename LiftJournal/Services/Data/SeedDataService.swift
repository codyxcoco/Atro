import Foundation
import SwiftData

enum SeedDataService {
    @MainActor
    static func ensureSeedData(in context: ModelContext) {
        do {
            let existingSettings = try context.fetch(FetchDescriptor<AppSettings>())
            if existingSettings.isEmpty {
                context.insert(AppSettings())
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

            context.insert(upperTemplate)
            context.insert(lowerTemplate)
            context.insert(todayWorkout)
            context.insert(laterWorkout)
            context.insert(restDay)
            context.insert(loggedWorkout)
            context.insert(mealEntry)

            try context.save()
        } catch {
            assertionFailure("Failed to seed data: \(error)")
        }
    }
}
