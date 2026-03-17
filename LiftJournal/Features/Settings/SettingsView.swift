import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.modelContext) private var modelContext
    @Bindable var settings: AppSettings

    var body: some View {
        Form {
            Section("Modules") {
                Toggle("Calendar sync", isOn: $settings.calendarSyncEnabled)
                Toggle("Health integration", isOn: $settings.healthIntegrationEnabled)
                Toggle("Feeling check-ins", isOn: $settings.feelingCheckInsEnabled)
                Toggle("Meal logging", isOn: $settings.mealsEnabled)
            }

            if settings.calendarSyncEnabled {
                Section("Calendar") {
                    Stepper(value: $settings.defaultCalendarDurationMinutes, in: 15...180, step: 15) {
                        Text("Default event length: \(settings.defaultCalendarDurationMinutes) min")
                    }
                }
            }

            if settings.healthIntegrationEnabled {
                Section("Health") {
                    Toggle("Write completed workouts", isOn: $settings.healthWorkoutWriteEnabled)
                    Toggle("Write mood check-ins", isOn: $settings.healthMoodWriteEnabled)
                    Text("Health remains optional. If you decline access, Lift Journal still works normally.")
                        .font(.lift(.footnote))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.liftSurface.ignoresSafeArea())
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .task(id: settings.healthIntegrationEnabled) {
            if settings.healthIntegrationEnabled {
                _ = await appModel.healthService.requestAuthorization(settings: settings)
                await appModel.refreshIntegrations(using: settings)
            }
        }
        .onChange(of: settings.calendarSyncEnabled) { _, isEnabled in
            if isEnabled {
                Task {
                    _ = await appModel.calendarService.requestWriteOnlyAccess()
                }
            }
            persist()
        }
        .onChange(of: settings.healthIntegrationEnabled) { _, _ in persist() }
        .onChange(of: settings.healthWorkoutWriteEnabled) { _, _ in persist() }
        .onChange(of: settings.healthMoodWriteEnabled) { _, _ in persist() }
        .onChange(of: settings.feelingCheckInsEnabled) { _, _ in persist() }
        .onChange(of: settings.mealsEnabled) { _, _ in persist() }
        .onChange(of: settings.defaultCalendarDurationMinutes) { _, _ in persist() }
    }

    private func persist() {
        settings.touch()
        try? modelContext.save()
    }
}

#Preview {
    PreviewContainer {
        NavigationStack {
            SettingsView(settings: AppSettings())
        }
    }
}
