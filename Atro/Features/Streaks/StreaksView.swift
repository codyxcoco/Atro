import SwiftData
import SwiftUI

struct StreaksView: View {
    @Environment(AppModel.self) private var appModel
    @Query(sort: \StreakCounter.updatedAt, order: .reverse) private var counters: [StreakCounter]
    @State private var editorMode: StreakEditorMode?
    @State private var deepLinkedCounter: StreakCounter?

    private var sortedCounters: [StreakCounter] {
        counters.sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned { return lhs.isPinned && !rhs.isPinned }
            return lhs.updatedAt > rhs.updatedAt
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if sortedCounters.isEmpty {
                    EmptyStateCard(
                        symbol: "number.circle",
                        title: "Start with one marker.",
                        message: "Track the quiet wins: training, recovery, consistency, or anything else worth noticing.",
                        primaryTitle: "New Streak"
                    ) {
                        editorMode = .create
                    }
                    .padding(.top, 12)
                } else {
                    ForEach(sortedCounters) { counter in
                        NavigationLink {
                            StreakDetailView(counter: counter)
                        } label: {
                            StreakCounterCard(counter: counter)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding()
        }
        .liftScreenBackground()
        .navigationTitle("Streaks")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    editorMode = .create
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("New Streak")
            }
        }
        .sheet(item: $editorMode) { mode in
            NavigationStack {
                StreakEditorView(mode: mode)
            }
        }
        .sheet(item: $deepLinkedCounter) { counter in
            NavigationStack {
                StreakDetailView(counter: counter)
            }
        }
        .task(id: appModel.pendingStreakCounterID) {
            presentPendingDeepLinkIfPossible()
        }
        .onChange(of: counters.map(\.id)) { _, _ in
            presentPendingDeepLinkIfPossible()
        }
    }

    private func presentPendingDeepLinkIfPossible() {
        guard let pendingID = appModel.pendingStreakCounterID,
              let counter = counters.first(where: { $0.id == pendingID }) else {
            return
        }

        deepLinkedCounter = counter
        appModel.pendingStreakCounterID = nil
    }
}

private struct StreakDetailView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.modelContext) private var modelContext
    @State private var editorMode: StreakEditorMode?
    @State private var loggingCounter: StreakCounter?
    let counter: StreakCounter

    private var stats: [StreakStat] {
        [
            StreakStat(title: "Current", value: "\(counter.currentStreakDays)", caption: "days"),
            StreakStat(title: "Best", value: "\(counter.longestStreakDays)", caption: "days"),
            StreakStat(title: "Logged", value: "\(counter.totalIncidents)", caption: counter.totalIncidents == 1 ? "reset" : "resets"),
            StreakStat(title: "Average", value: averageText, caption: "days")
        ]
    }

    private var averageText: String {
        guard let average = counter.averageStreakDays else { return "N/A" }
        return average.formatted(.number.precision(.fractionLength(0...1)))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                StreakHeroCard(counter: counter)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(stats) { stat in
                        StreakStatCard(stat: stat, tint: counter.theme.color)
                    }
                }

                Button {
                    loggingCounter = counter
                } label: {
                    Label("Restart Streak", systemImage: "arrow.counterclockwise")
                        .font(.lift(.body, weight: .semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(counter.theme.color)

                IncidentHistoryCard(counter: counter)
            }
            .padding()
        }
        .liftScreenBackground()
        .navigationTitle(counter.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") {
                    editorMode = .edit(counter)
                }
            }
        }
        .sheet(item: $editorMode) { mode in
            NavigationStack {
                StreakEditorView(mode: mode)
            }
        }
        .sheet(item: $loggingCounter) { counter in
            LogStreakIncidentView(counter: counter)
        }
    }
}

private struct StreakEditorView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let mode: StreakEditorMode

    @State private var title: String
    @State private var subtitle: String
    @State private var phrase: String
    @State private var symbolName: String
    @State private var iconColor: StreakIconColor
    @State private var theme: StreakTheme
    @State private var lastIncidentDate: Date
    @State private var hasGoal: Bool
    @State private var goalDays: Int
    @State private var isPinned: Bool

    private let symbols = [
        "checkmark.seal",
        "figure.strengthtraining.traditional",
        "heart.text.square.fill",
        "bolt.heart",
        "lungs.fill",
        "brain.head.profile",
        "bed.double.fill",
        "flame.fill"
    ]

    init(mode: StreakEditorMode) {
        self.mode = mode

        switch mode {
        case .create:
            _title = State(initialValue: "")
            _subtitle = State(initialValue: "")
            _phrase = State(initialValue: "current streak")
            _symbolName = State(initialValue: "checkmark.seal")
            _iconColor = State(initialValue: .sage)
            _theme = State(initialValue: .recovery)
            _lastIncidentDate = State(initialValue: .now)
            _hasGoal = State(initialValue: false)
            _goalDays = State(initialValue: 30)
            _isPinned = State(initialValue: false)
        case .edit(let counter):
            _title = State(initialValue: counter.title)
            _subtitle = State(initialValue: counter.counterSubtitle)
            _phrase = State(initialValue: counter.phrase)
            _symbolName = State(initialValue: counter.symbolName)
            _iconColor = State(initialValue: counter.iconColor)
            _theme = State(initialValue: counter.theme)
            _lastIncidentDate = State(initialValue: counter.lastIncidentDate)
            _hasGoal = State(initialValue: counter.goalDays != nil)
            _goalDays = State(initialValue: counter.goalDays ?? 30)
            _isPinned = State(initialValue: counter.isPinned)
        }
    }

    private var navigationTitle: String {
        switch mode {
        case .create:
            "New Streak"
        case .edit:
            "Edit Streak"
        }
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                StreakPreviewCard(
                    title: trimmedTitle.isEmpty ? "Training Streak" : trimmedTitle,
                    subtitle: subtitle.trimmingCharacters(in: .whitespacesAndNewlines),
                    phrase: phrase.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "current streak" : phrase,
                    symbolName: symbolName,
                    iconColor: iconColor,
                    theme: theme,
                    lastIncidentDate: lastIncidentDate,
                    goalDays: hasGoal ? goalDays : nil
                )

                StreakEditorSection(title: "Identity", systemImage: "textformat") {
                    TextField("Title", text: $title)
                        .textInputAutocapitalization(.words)
                    StreakRowDivider()
                    TextField("Subtitle", text: $subtitle)
                        .textInputAutocapitalization(.sentences)
                    StreakRowDivider()
                    TextField("Phrase", text: $phrase)
                        .textInputAutocapitalization(.sentences)
                }

                StreakEditorSection(title: "Timing", systemImage: "calendar") {
                    DatePicker("Streak start or reset date", selection: $lastIncidentDate, in: ...Date(), displayedComponents: .date)
                    StreakRowDivider()
                    Toggle("Pin on Streaks", isOn: $isPinned)
                        .toggleStyle(.switch)
                }

                StreakEditorSection(title: "Goal", systemImage: "target") {
                    Toggle("Set a milestone", isOn: $hasGoal.animation(.smooth))
                        .toggleStyle(.switch)

                    if hasGoal {
                        StreakRowDivider()
                        Stepper(value: $goalDays, in: 1...10_000) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(goalDays) days")
                                    .font(.lift(.body, weight: .semibold))
                                Text("Optional milestone")
                                    .font(.lift(.footnote))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                StreakEditorSection(title: "Style", systemImage: "paintpalette.fill") {
                    Picker("Theme", selection: $theme) {
                        ForEach(StreakTheme.allCases) { theme in
                            Text(theme.title).tag(theme)
                        }
                    }
                    .pickerStyle(.menu)

                    StreakRowDivider()

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Icon Color")
                            .font(.lift(.footnote, weight: .semibold))
                            .foregroundStyle(.secondary)
                        StreakIconColorPicker(selection: $iconColor)
                    }

                    StreakRowDivider()

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                        ForEach(symbols, id: \.self) { symbol in
                            Button {
                                symbolName = symbol
                            } label: {
                                Image(systemName: symbol)
                                    .font(.system(size: 19, weight: .semibold))
                                    .frame(width: 46, height: 46)
                                    .background(symbolName == symbol ? iconColor.softColor.opacity(0.9) : Color.white.opacity(0.06), in: Circle())
                                    .foregroundStyle(symbolName == symbol ? iconColor.color : .secondary)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(symbol)
                        }
                    }
                }

                Button(action: save) {
                    Text(mode.saveTitle)
                        .font(.lift(.body, weight: .semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(trimmedTitle.isEmpty)
            }
            .padding()
        }
        .liftScreenBackground()
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
            }
        }
    }

    private func save() {
        let sanitizedPhrase = phrase.trimmingCharacters(in: .whitespacesAndNewlines)
        let goal = hasGoal ? goalDays : nil

        switch mode {
        case .create:
            let counter = StreakCounter(
                title: trimmedTitle,
                subtitle: subtitle.trimmingCharacters(in: .whitespacesAndNewlines),
                phrase: sanitizedPhrase.isEmpty ? "current streak" : sanitizedPhrase,
                symbolName: symbolName,
                iconColor: iconColor,
                theme: theme,
                lastIncidentDate: lastIncidentDate,
                goalDays: goal,
                isPinned: isPinned
            )
            modelContext.insert(counter)
            appModel.haptics.confirm()
            appModel.showBanner("Streak created", systemImage: "number.circle.fill")
        case .edit(let counter):
            counter.title = trimmedTitle
            counter.counterSubtitle = subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
            counter.phrase = sanitizedPhrase.isEmpty ? "current streak" : sanitizedPhrase
            counter.symbolName = symbolName
            counter.iconColor = iconColor
            counter.theme = theme
            counter.lastIncidentDate = lastIncidentDate
            counter.goalDays = goal
            counter.isPinned = isPinned
            counter.touch()
            appModel.haptics.softTap()
            appModel.showBanner("Streak updated", systemImage: "checkmark.circle.fill")
        }

        try? modelContext.save()
        StreakWidgetSyncService.sync(modelContext: modelContext)
        dismiss()
    }
}

private struct LogStreakIncidentView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let counter: StreakCounter

    @State private var incidentDate = Date()
    @State private var note = ""
    @State private var showsConfirmation = false

    private var previousStreakLength: Int {
        StreakCalculator.fullCalendarDays(from: counter.lastIncidentDate, to: incidentDate)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Restart this streak?", systemImage: "arrow.counterclockwise")
                            .font(.lift(.title3, weight: .bold))
                            .foregroundStyle(counter.theme.color)

                        Text("The current streak will be saved to history, and a new streak will begin from the selected date.")
                            .font(.lift(.body))
                            .foregroundStyle(.secondary)
                    }
                    .liftCardStyle()

                    StreakEditorSection(title: "Reset", systemImage: "calendar.badge.clock") {
                        DatePicker("Restart date", selection: $incidentDate, in: ...Date(), displayedComponents: .date)
                        StreakRowDivider()
                        TextField("Optional note", text: $note, axis: .vertical)
                            .lineLimit(3...5)
                    }

                    Button(role: .destructive) {
                        showsConfirmation = true
                    } label: {
                        Text("Save Reset")
                            .font(.lift(.body, weight: .semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(counter.theme.color)
                }
                .padding()
            }
            .liftScreenBackground()
            .navigationTitle("Restart Streak")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Restart this streak?", isPresented: $showsConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Save Reset", role: .destructive) {
                    saveIncident()
                }
            } message: {
                Text("This saves the previous \(previousStreakLength)-day streak to history and begins again from the selected date.")
            }
        }
    }

    private func saveIncident() {
        let incident = StreakIncident(
            date: incidentDate,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            previousStreakLength: previousStreakLength
        )

        incident.counter = counter
        counter.incidents.append(incident)
        counter.lastIncidentDate = incidentDate
        counter.touch()
        modelContext.insert(incident)

        try? modelContext.save()
        StreakWidgetSyncService.sync(modelContext: modelContext)
        appModel.haptics.confirm()
        appModel.showBanner("Streak reset saved", systemImage: "arrow.counterclockwise.circle.fill")
        dismiss()
    }
}

private struct StreakCounterCard: View {
    let counter: StreakCounter

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: counter.symbolName)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(counter.iconColor.color)
                    .frame(width: 34, height: 34)
                    .background(counter.iconColor.softColor.opacity(0.72), in: Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(counter.title)
                        .font(.lift(.headline, weight: .semibold))

                    if let subtitle = counter.subtitle {
                        Text(subtitle)
                            .font(.lift(.footnote))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if counter.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.caption)
                        .foregroundStyle(counter.iconColor.color)
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(counter.currentStreakDays)")
                    .font(.system(size: 58, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.72)

                Text("days")
                    .font(.lift(.title3, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            Text(counter.phrase)
                .font(.lift(.subheadline, weight: .medium))
                .foregroundStyle(.secondary)

            Text("Since \(counter.lastIncidentDate.formatted(date: .abbreviated, time: .omitted))")
                .font(.lift(.footnote))
                .foregroundStyle(.secondary)

            if let progress = counter.progressToGoal, let goalStatusText = counter.goalStatusText {
                StreakProgressView(progress: progress, text: goalStatusText, tint: counter.theme.color)
            }
        }
        .liftCardStyle()
    }
}

private struct StreakHeroCard: View {
    let counter: StreakCounter

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                Image(systemName: counter.symbolName)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(counter.iconColor.color)
                    .frame(width: 42, height: 42)
                    .background(counter.iconColor.softColor.opacity(0.75), in: Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(counter.title)
                        .font(.lift(.title3, weight: .bold))

                    if let subtitle = counter.subtitle {
                        Text(subtitle)
                            .font(.lift(.footnote))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("\(counter.currentStreakDays)")
                    .font(.system(size: 86, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.55)

                Text(counter.phrase)
                    .font(.lift(.title3, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            Text("Started \(counter.lastIncidentDate.formatted(date: .abbreviated, time: .omitted))")
                .font(.lift(.subheadline))
                .foregroundStyle(.secondary)

            if let progress = counter.progressToGoal, let goalStatusText = counter.goalStatusText {
                StreakProgressView(progress: progress, text: goalStatusText, tint: counter.theme.color)
            }
        }
        .liftCardStyle()
    }
}

private struct StreakPreviewCard: View {
    let title: String
    let subtitle: String
    let phrase: String
    let symbolName: String
    let iconColor: StreakIconColor
    let theme: StreakTheme
    let lastIncidentDate: Date
    let goalDays: Int?

    private var currentDays: Int {
        StreakCalculator.fullCalendarDays(from: lastIncidentDate)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: symbolName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(iconColor.color)
                    .frame(width: 34, height: 34)
                    .background(iconColor.softColor.opacity(0.72), in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.lift(.headline, weight: .semibold))
                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.lift(.caption))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(currentDays)")
                    .font(.system(size: 46, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text("days")
                    .font(.lift(.headline, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            Text(phrase)
                .font(.lift(.footnote, weight: .medium))
                .foregroundStyle(.secondary)

            if let progress = StreakCalculator.progress(currentStreak: currentDays, goalDays: goalDays),
               let goalDays {
                StreakProgressView(
                    progress: progress,
                    text: currentDays >= goalDays ? "Goal reached" : "\(currentDays) of \(goalDays) days",
                    tint: theme.color
                )
            }
        }
        .liftCardStyle()
    }
}

private struct StreakProgressView: View {
    let progress: Double
    let text: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(text)
                .font(.lift(.footnote, weight: .semibold))
                .foregroundStyle(tint)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(tint.opacity(0.16))

                    Capsule()
                        .fill(tint)
                        .frame(width: proxy.size.width * min(max(progress, 0), 1))
                }
            }
            .frame(height: 8)
        }
    }
}

private struct StreakIconColorPicker: View {
    @Binding var selection: StreakIconColor

    private let columns = [GridItem(.adaptive(minimum: 68), spacing: 10)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(StreakIconColor.allCases) { iconColor in
                Button {
                    selection = iconColor
                } label: {
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(iconColor.color)
                                .frame(width: 32, height: 32)

                            if selection == iconColor {
                                Image(systemName: "checkmark")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.white)
                            }
                        }

                        Text(iconColor.title)
                            .font(.lift(.caption2, weight: .semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(selection == iconColor ? iconColor.softColor.opacity(0.9) : Color.white.opacity(0.06))
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(selection == iconColor ? iconColor.color.opacity(0.55) : Color.white.opacity(0.08), lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(iconColor.title)
                .accessibilityAddTraits(selection == iconColor ? [.isSelected] : [])
            }
        }
    }
}

private struct StreakStat: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let caption: String
}

private struct StreakStatCard: View {
    let stat: StreakStat
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(stat.title.uppercased())
                .font(.lift(.caption, weight: .bold))
                .foregroundStyle(.secondary)

            Text(stat.value)
                .font(.lift(.title2, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(tint)

            Text(stat.caption)
                .font(.lift(.footnote))
                .foregroundStyle(.secondary)
        }
        .liftCardStyle()
    }
}

private struct IncidentHistoryCard: View {
    let counter: StreakCounter

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("History", systemImage: "clock.arrow.circlepath")
                .font(.lift(.caption, weight: .bold))
                .textCase(.uppercase)
                .foregroundStyle(counter.theme.color)

            if counter.sortedIncidents.isEmpty {
                Text("No resets logged yet.")
                    .font(.lift(.body))
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 0) {
                    ForEach(counter.sortedIncidents) { incident in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(incident.date.formatted(date: .abbreviated, time: .omitted))
                                    .font(.lift(.body, weight: .semibold))

                                Spacer()

                                Text("\(incident.previousStreakLength) days")
                                    .font(.lift(.footnote, weight: .semibold))
                                    .foregroundStyle(counter.theme.color)
                            }

                            if !incident.note.isEmpty {
                                Text(incident.note)
                                    .font(.lift(.footnote))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 12)

                        if incident.id != counter.sortedIncidents.last?.id {
                            Divider().overlay(.white.opacity(0.08))
                        }
                    }
                }
            }
        }
        .liftCardStyle()
    }
}

private struct StreakEditorSection<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label {
                Text(title)
                    .font(.lift(.caption, weight: .bold))
                    .textCase(.uppercase)
            } icon: {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 0) {
                content
            }
        }
        .liftCardStyle()
    }
}

private struct StreakRowDivider: View {
    var body: some View {
        Divider()
            .overlay(.white.opacity(0.08))
            .padding(.vertical, 10)
    }
}

enum StreakEditorMode: Identifiable {
    case create
    case edit(StreakCounter)

    var id: String {
        switch self {
        case .create:
            "create"
        case .edit(let counter):
            "edit-\(counter.id.uuidString)"
        }
    }

    var saveTitle: String {
        switch self {
        case .create:
            "Create Streak"
        case .edit:
            "Save Changes"
        }
    }
}

#Preview {
    PreviewContainer {
        NavigationStack {
            StreaksView()
        }
    }
}
