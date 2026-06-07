import SwiftData
import SwiftUI

struct RootTabView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query private var settings: [AppSettings]
    @Query(sort: \PlannedWorkout.scheduledFor) private var plannedWorkouts: [PlannedWorkout]
    @State private var showsOnboarding = false

    private var currentSettings: AppSettings {
        if let existing = settings.first {
            return existing
        }

        let newSettings = AppSettings()
        modelContext.insert(newSettings)
        try? modelContext.save()
        return newSettings
    }

    var body: some View {
        @Bindable var appModel = appModel

        TabView(selection: $appModel.selectedTab) {
            NavigationStack {
                TodayView(settings: currentSettings)
            }
            .tag(AppTab.today)
            .tabItem {
                Label("Today", systemImage: "sun.max")
            }

            NavigationStack {
                StreaksView()
            }
            .tag(AppTab.streaks)
            .tabItem {
                Label("Streaks", systemImage: "number.circle")
            }

            NavigationStack {
                PlanView(settings: currentSettings)
            }
            .tag(AppTab.plan)
            .tabItem {
                Label("Plan", systemImage: "calendar")
            }

            NavigationStack {
                JournalView(settings: currentSettings)
            }
            .tag(AppTab.journal)
            .tabItem {
                Label("Journal", systemImage: "book.closed")
            }

            NavigationStack {
                SettingsView(settings: currentSettings)
            }
            .tag(AppTab.settings)
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
        }
        .fontDesign(.rounded)
        .liftScreenBackground()
        .fullScreenCover(isPresented: $showsOnboarding) {
            OnboardingView(settings: currentSettings) {
                showsOnboarding = false
            }
        }
        .task(id: currentSettings.id) {
            showsOnboarding = !currentSettings.hasCompletedOnboarding
            await appModel.refreshIntegrations(using: currentSettings, modelContext: modelContext)
        }
        .task {
            appModel.activateWatchSync()
            appModel.pushWatchSnapshot(using: modelContext)
        }
        .task(id: watchSyncSignature) {
            appModel.pushWatchSnapshot(using: modelContext)
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }

            Task {
                await appModel.refreshIntegrations(using: currentSettings, modelContext: modelContext)
                appModel.pushWatchSnapshot(using: modelContext)
            }
        }
        .overlay(alignment: .top) {
            if let banner = appModel.pendingBanner {
                TextBanner(message: banner)
                    .padding(.top, 10)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(1)
            }
        }
        .animation(LiftMotion.banner(reduceMotion), value: appModel.pendingBanner?.id)
    }

    private var watchSyncSignature: [String] {
        plannedWorkouts.map { workout in
            [
                workout.id.uuidString,
                workout.templateName,
                workout.scheduledFor.ISO8601Format(),
                workout.updatedAt.ISO8601Format(),
                workout.completedLoggedWorkoutID
            ].joined(separator: "|")
        }
    }
}

private struct TextBanner: View {
    let message: BannerMessage

    var body: some View {
        Label(message.title, systemImage: message.systemImage)
            .font(.lift(.subheadline, weight: .semibold))
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.regularMaterial, in: Capsule(style: .continuous))
            .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
    }
}

#Preview {
    PreviewContainer {
        RootTabView()
    }
}
