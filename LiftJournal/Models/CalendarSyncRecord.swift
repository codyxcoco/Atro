import Foundation
import SwiftData

@Model
final class CalendarSyncRecord {
    @Attribute(.unique) var id: UUID
    var plannedWorkoutID: String
    var eventIdentifier: String
    var calendarIdentifier: String
    var titleSnapshot: String
    var notesSnapshot: String
    var syncedAt: Date

    init(
        id: UUID = UUID(),
        plannedWorkoutID: String,
        eventIdentifier: String,
        calendarIdentifier: String,
        titleSnapshot: String,
        notesSnapshot: String,
        syncedAt: Date = .now
    ) {
        self.id = id
        self.plannedWorkoutID = plannedWorkoutID
        self.eventIdentifier = eventIdentifier
        self.calendarIdentifier = calendarIdentifier
        self.titleSnapshot = titleSnapshot
        self.notesSnapshot = notesSnapshot
        self.syncedAt = syncedAt
    }
}
