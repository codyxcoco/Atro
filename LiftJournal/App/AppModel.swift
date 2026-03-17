import SwiftUI

@MainActor
@Observable
final class AppModel {
    var selectedTab: AppTab = .today
    var pendingBanner: BannerMessage?

    let calendarService = CalendarService()
    let healthService = HealthKitService()
    let haptics = HapticClient()

    func refreshIntegrations(using settings: AppSettings) async {
        if settings.healthIntegrationEnabled {
            await healthService.refreshTodaySummaryIfNeeded(enabled: true)
        } else {
            healthService.todaySummary = .empty
        }
    }

    func showBanner(_ title: String, systemImage: String = "checkmark.circle.fill") {
        pendingBanner = BannerMessage(title: title, systemImage: systemImage)
    }
}

enum AppTab: Hashable {
    case today
    case plan
    case journal
    case settings
}

struct BannerMessage: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let systemImage: String
}
