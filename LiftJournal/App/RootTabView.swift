import SwiftData
import SwiftUI

struct RootTabView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.modelContext) private var modelContext
    @Query private var settings: [AppSettings]
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
        .background(Color.liftSurface.ignoresSafeArea())
        .fullScreenCover(isPresented: $showsOnboarding) {
            OnboardingView(settings: currentSettings) {
                showsOnboarding = false
            }
        }
        .task(id: currentSettings.id) {
            showsOnboarding = !currentSettings.hasCompletedOnboarding
            await appModel.refreshIntegrations(using: currentSettings)
        }
        .overlay(alignment: .top) {
            if let banner = appModel.pendingBanner {
                TextBanner(message: banner)
                    .padding(.top, 10)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .task {
                        try? await Task.sleep(for: .seconds(2))
                        if appModel.pendingBanner?.id == banner.id {
                            withAnimation(.snappy) {
                                appModel.pendingBanner = nil
                            }
                        }
                    }
            }
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
