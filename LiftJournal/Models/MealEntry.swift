import Foundation
import SwiftData

@Model
final class MealEntry {
    @Attribute(.unique) var id: UUID
    var mealName: String
    var note: String
    var loggedAt: Date

    init(
        id: UUID = UUID(),
        mealName: String,
        note: String = "",
        loggedAt: Date = .now
    ) {
        self.id = id
        self.mealName = mealName
        self.note = note
        self.loggedAt = loggedAt
    }
}
