import AppIntents
import Foundation

struct AtroCounterEntity: AppEntity, Identifiable {
    var id: String
    var title: String
    var subtitle: String
    var symbolName: String

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Streak")
    static let defaultQuery = AtroCounterEntityQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(title)",
            subtitle: subtitle.isEmpty ? nil : "\(subtitle)",
            image: .init(systemName: symbolName)
        )
    }

    init(snapshot: StreakWidgetSnapshot) {
        id = snapshot.counterId.uuidString
        title = snapshot.title
        subtitle = snapshot.subtitle
        symbolName = snapshot.symbolName
    }

    init(id: String, title: String, subtitle: String = "", symbolName: String = "number.circle") {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.symbolName = symbolName
    }
}

struct AtroCounterEntityQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [AtroCounterEntity] {
        StreakWidgetSnapshotStore.loadSnapshots()
            .filter { identifiers.contains($0.counterId.uuidString) }
            .map(AtroCounterEntity.init(snapshot:))
    }

    func suggestedEntities() async throws -> [AtroCounterEntity] {
        StreakWidgetSnapshotStore.loadSnapshots()
            .sorted { lhs, rhs in
                if lhs.isPinned != rhs.isPinned { return lhs.isPinned && !rhs.isPinned }
                return lhs.updatedAt > rhs.updatedAt
            }
            .map(AtroCounterEntity.init(snapshot:))
    }

    func defaultResult() async -> AtroCounterEntity? {
        try? await suggestedEntities().first
    }
}

struct AtroCounterSelectionIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Streak"
    static let description = IntentDescription("Choose the Atro streak to show.")

    @Parameter(title: "Streak")
    var counter: AtroCounterEntity?
}
