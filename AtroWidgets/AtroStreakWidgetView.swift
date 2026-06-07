import SwiftUI
import WidgetKit

struct AtroStreakWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var entry: AtroStreakWidgetEntry

    var body: some View {
        Group {
            if let snapshot = entry.snapshot {
                switch family {
                case .systemSmall:
                    SmallAtroStreakWidget(snapshot: snapshot)
                case .systemMedium:
                    MediumAtroStreakWidget(snapshot: snapshot)
                case .systemLarge:
                    LargeAtroStreakWidget(snapshot: snapshot)
                case .accessoryCircular:
                    AccessoryCircularAtroStreakWidget(snapshot: snapshot)
                case .accessoryRectangular:
                    AccessoryRectangularAtroStreakWidget(snapshot: snapshot)
                case .accessoryInline:
                    AccessoryInlineAtroStreakWidget(snapshot: snapshot)
                default:
                    SmallAtroStreakWidget(snapshot: snapshot)
                }
            } else {
                EmptyAtroStreakWidget()
            }
        }
        .widgetURL(entry.snapshot.flatMap { URL(string: "atro://streak/\($0.counterId.uuidString)") })
        .containerBackground(.background, for: .widget)
    }
}

private struct SmallAtroStreakWidget: View {
    var snapshot: StreakWidgetSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            WidgetHeader(snapshot: snapshot)

            Spacer(minLength: 4)

            Text("\(snapshot.currentStreakDays)")
                .font(.system(size: 54, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.7)

            Text("days")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .padding(2)
    }
}

private struct MediumAtroStreakWidget: View {
    var snapshot: StreakWidgetSnapshot

    var body: some View {
        HStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 10) {
                WidgetHeader(snapshot: snapshot)

                Spacer()

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(snapshot.currentStreakDays)")
                        .font(.system(size: 52, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .minimumScaleFactor(0.72)
                    Text("days")
                        .font(.title3.weight(.medium))
                        .foregroundStyle(.secondary)
                }

                Text("Since \(snapshot.lastIncidentDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let progress = snapshot.progress {
                ProgressRingView(progress: progress, tint: snapshot.tint, lineWidth: 7)
                    .frame(width: 58, height: 58)
            }
        }
        .padding(2)
    }
}

private struct LargeAtroStreakWidget: View {
    var snapshot: StreakWidgetSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            WidgetHeader(snapshot: snapshot)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(snapshot.currentStreakDays)")
                    .font(.system(size: 78, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.68)
                Text("days")
                    .font(.title2.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            Text("Since \(snapshot.lastIncidentDate.formatted(date: .abbreviated, time: .omitted))")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let goalText = snapshot.goalText, let progress = snapshot.progress {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(goalText)
                            .font(.headline)
                        Spacer()
                        Text("\(Int(progress * 100))%")
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }

                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule().fill(snapshot.tint.opacity(0.16))
                            Capsule()
                                .fill(snapshot.tint)
                                .frame(width: proxy.size.width * progress)
                        }
                    }
                    .frame(height: 8)
                }
                .padding(.top, 4)
            }

            Spacer(minLength: 0)
        }
        .padding(2)
    }
}

private struct AccessoryCircularAtroStreakWidget: View {
    var snapshot: StreakWidgetSnapshot

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 1) {
                Image(systemName: snapshot.symbolName)
                    .font(.caption2)
                Text("\(snapshot.currentStreakDays)")
                    .font(.system(.title3, design: .rounded).weight(.semibold))
                    .monospacedDigit()
            }
        }
    }
}

private struct AccessoryRectangularAtroStreakWidget: View {
    var snapshot: StreakWidgetSnapshot

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: snapshot.symbolName)
            VStack(alignment: .leading, spacing: 1) {
                Text(snapshot.title)
                    .font(.caption.weight(.semibold))
                Text("\(snapshot.currentStreakDays) days")
                    .font(.headline.monospacedDigit())
            }
        }
    }
}

private struct AccessoryInlineAtroStreakWidget: View {
    var snapshot: StreakWidgetSnapshot

    var body: some View {
        Text("\(Image(systemName: snapshot.symbolName)) \(snapshot.currentStreakDays) days \(snapshot.title)")
    }
}

private struct EmptyAtroStreakWidget: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "number.circle")
                .font(.title2)
            Text("Atro Streak")
                .font(.headline)
            Text("Open Atro and create a streak.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct WidgetHeader: View {
    var snapshot: StreakWidgetSnapshot

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: snapshot.symbolName)
                .font(.headline)
                .foregroundStyle(snapshot.tint)
                .frame(width: 28, height: 28)
                .background(snapshot.tint.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(snapshot.title)
                    .font(.headline)
                    .lineLimit(2)
                if !snapshot.subtitle.isEmpty {
                    Text(snapshot.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
    }
}

private struct ProgressRingView: View {
    var progress: Double
    var tint: Color
    var lineWidth: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .stroke(tint.opacity(0.16), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))

            Circle()
                .trim(from: 0, to: max(0, min(progress, 1)))
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .accessibilityLabel("Goal progress")
        .accessibilityValue("\(Int(progress * 100)) percent")
    }
}

private extension StreakWidgetSnapshot {
    var tint: Color {
        Color(hex: colorHex) ?? .accentColor
    }

    var progress: Double? {
        StreakWidgetDateCalculator.progress(currentStreak: currentStreakDays, goalDays: goalDays)
    }

    var goalText: String? {
        guard let goalDays else { return nil }
        if currentStreakDays >= goalDays {
            let beyond = currentStreakDays - goalDays
            return beyond == 0 ? "Goal reached" : "+\(beyond) days beyond goal"
        }
        return "\(currentStreakDays) of \(goalDays) days"
    }
}

private extension Color {
    init?(hex: String) {
        var value = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("#") {
            value.removeFirst()
        }

        guard value.count == 6, let integer = UInt64(value, radix: 16) else {
            return nil
        }

        let red = Double((integer >> 16) & 0xFF) / 255.0
        let green = Double((integer >> 8) & 0xFF) / 255.0
        let blue = Double(integer & 0xFF) / 255.0
        self.init(red: red, green: green, blue: blue)
    }
}
