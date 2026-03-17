import Foundation
import SwiftData

@Model
final class PlannedWorkout {
    @Attribute(.unique) var id: UUID
    var sourceTemplateID: String
    var templateName: String
    var notes: String
    var scheduledFor: Date
    var durationMinutes: Int
    var isRestDay: Bool
    var completedLoggedWorkoutID: String
    var createdAt: Date
    var updatedAt: Date
    var calendarEventIdentifier: String
    var calendarIdentifier: String
    var calendarLastSyncedAt: Date?
    @Attribute(.externalStorage) var templateSnapshotData: Data?

    init(
        id: UUID = UUID(),
        sourceTemplateID: String = "",
        templateName: String,
        notes: String = "",
        scheduledFor: Date,
        durationMinutes: Int = 60,
        isRestDay: Bool = false,
        completedLoggedWorkoutID: String = "",
        createdAt: Date = .now,
        updatedAt: Date = .now,
        calendarEventIdentifier: String = "",
        calendarIdentifier: String = "",
        templateSnapshotData: Data? = nil
    ) {
        self.id = id
        self.sourceTemplateID = sourceTemplateID
        self.templateName = templateName
        self.notes = notes
        self.scheduledFor = scheduledFor
        self.durationMinutes = durationMinutes
        self.isRestDay = isRestDay
        self.completedLoggedWorkoutID = completedLoggedWorkoutID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.calendarEventIdentifier = calendarEventIdentifier
        self.calendarIdentifier = calendarIdentifier
        self.calendarLastSyncedAt = nil
        self.templateSnapshotData = templateSnapshotData
    }

    var displayName: String {
        isRestDay ? "Rest Day" : templateName
    }

    var isCalendarSynced: Bool {
        !calendarEventIdentifier.isEmpty
    }

    var snapshot: TemplateSnapshot? {
        guard let templateSnapshotData else {
            return nil
        }

        return try? JSONDecoder().decode(TemplateSnapshot.self, from: templateSnapshotData)
    }

    func applySnapshot(_ snapshot: TemplateSnapshot) {
        sourceTemplateID = snapshot.sourceTemplateID
        templateName = snapshot.name
        notes = snapshot.notes
        durationMinutes = snapshot.durationMinutes
        templateSnapshotData = try? JSONEncoder().encode(snapshot)
        updatedAt = .now
    }
}
