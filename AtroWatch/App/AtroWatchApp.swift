import SwiftUI

@main
struct AtroWatchApp: App {
    @State private var appModel = WatchAppModel()

    var body: some Scene {
        WindowGroup {
            WatchHomeView(appModel: appModel)
        }
    }
}
