import Foundation
import SwiftData

@Model
final class AppSettings {
    @Attribute(.unique) var id: String
    var hasCompletedOnboarding: Bool
    var calendarSyncEnabled: Bool
    var healthIntegrationEnabled: Bool
    var healthWorkoutWriteEnabled: Bool
    var healthMoodWriteEnabled: Bool
    var feelingCheckInsEnabled: Bool
    var mealsEnabled: Bool
    var workoutBuddyEnabled: Bool
    var workoutBuddyWeekdayRawValue: Int
    var defaultCalendarDurationMinutes: Int
    var preferredCalendarIdentifier: String
    var createdAt: Date
    var updatedAt: Date

    init(
        id: String = "app-settings",
        hasCompletedOnboarding: Bool = false,
        calendarSyncEnabled: Bool = false,
        healthIntegrationEnabled: Bool = false,
        healthWorkoutWriteEnabled: Bool = false,
        healthMoodWriteEnabled: Bool = false,
        feelingCheckInsEnabled: Bool = true,
        mealsEnabled: Bool = false,
        workoutBuddyEnabled: Bool = false,
        workoutBuddyWeekdayRawValue: Int = WorkoutBuddyWeekday.monday.rawValue,
        defaultCalendarDurationMinutes: Int = 60,
        preferredCalendarIdentifier: String = "",
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.calendarSyncEnabled = calendarSyncEnabled
        self.healthIntegrationEnabled = healthIntegrationEnabled
        self.healthWorkoutWriteEnabled = healthWorkoutWriteEnabled
        self.healthMoodWriteEnabled = healthMoodWriteEnabled
        self.feelingCheckInsEnabled = feelingCheckInsEnabled
        self.mealsEnabled = mealsEnabled
        self.workoutBuddyEnabled = workoutBuddyEnabled
        self.workoutBuddyWeekdayRawValue = workoutBuddyWeekdayRawValue
        self.defaultCalendarDurationMinutes = defaultCalendarDurationMinutes
        self.preferredCalendarIdentifier = preferredCalendarIdentifier
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var workoutBuddyWeekday: WorkoutBuddyWeekday {
        get { WorkoutBuddyWeekday(rawValue: workoutBuddyWeekdayRawValue) ?? .monday }
        set { workoutBuddyWeekdayRawValue = newValue.rawValue }
    }

    func touch() {
        updatedAt = .now
    }

    func resetForFreshStart(preserveOnboarding: Bool = true) {
        let onboardingCompleted = hasCompletedOnboarding

        hasCompletedOnboarding = preserveOnboarding ? onboardingCompleted : false
        calendarSyncEnabled = false
        healthIntegrationEnabled = false
        healthWorkoutWriteEnabled = false
        healthMoodWriteEnabled = false
        feelingCheckInsEnabled = true
        mealsEnabled = false
        workoutBuddyEnabled = false
        workoutBuddyWeekdayRawValue = WorkoutBuddyWeekday.monday.rawValue
        defaultCalendarDurationMinutes = 60
        preferredCalendarIdentifier = ""
        createdAt = .now
        updatedAt = .now
    }
}
