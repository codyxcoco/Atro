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
        self.defaultCalendarDurationMinutes = defaultCalendarDurationMinutes
        self.preferredCalendarIdentifier = preferredCalendarIdentifier
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    func touch() {
        updatedAt = .now
    }
}
