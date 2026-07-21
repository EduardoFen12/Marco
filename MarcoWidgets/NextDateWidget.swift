//
//  NextDateWidget.swift
//  MarcoWidgets
//

import WidgetKit
import SwiftUI
import SwiftData

/// Uma entrada da timeline: a data importante mais próxima num dado dia de referência, com a
/// contagem regressiva já calculada (`daysUntilNextOccurrence`). Uma entrada por dia — o próprio
/// avanço do relógio do sistema entre `date`s consecutivos é o que faz a contagem "andar".
struct NextDateEntry: TimelineEntry {
    let date: Date
    let name: String?
    let type: DateType?
    let daysUntil: Int
}

struct NextDateProvider: TimelineProvider {
    /// Quantos dias de entries pré-calcular antes de pedir uma timeline nova ao sistema.
    private static let daysAhead = 7

    func placeholder(in context: Context) -> NextDateEntry {
        NextDateEntry(date: .now, name: "Aniversário da Mari", type: .birthday, daysUntil: 3)
    }

    func getSnapshot(in context: Context, completion: @escaping (NextDateEntry) -> Void) {
        completion(NextDateEntry(date: .now, name: "Aniversário da Mari", type: .birthday, daysUntil: 3))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NextDateEntry>) -> Void) {
        let calendar = Calendar.current
        let modelContext = ModelContext(Persistence.container)
        let allDates = (try? modelContext.fetch(FetchDescriptor<ImportantDate>())) ?? []

        let today = calendar.startOfDay(for: .now)
        var entries: [NextDateEntry] = []

        for offset in 0..<Self.daysAhead {
            guard let referenceDate = calendar.date(byAdding: .day, value: offset, to: today) else { continue }
            let closest = allDates
                .map { ($0, $0.daysUntilNextOccurrence(from: referenceDate, calendar: calendar)) }
                .min { $0.1 < $1.1 }
            entries.append(
                NextDateEntry(
                    date: referenceDate,
                    name: closest?.0.name,
                    type: closest?.0.type,
                    daysUntil: closest?.1 ?? 0
                )
            )
        }

        if entries.isEmpty {
            entries = [NextDateEntry(date: today, name: nil, type: nil, daysUntil: 0)]
        }

        let refreshDate = calendar.date(byAdding: .day, value: Self.daysAhead, to: today) ?? today
        completion(Timeline(entries: entries, policy: .after(refreshDate)))
    }
}

private extension DateType {
    var symbolName: String {
        switch self {
        case .birthday: "birthday.cake"
        case .commemorative: "star"
        case .memorial: "flame"
        }
    }
}

struct NextDateWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: NextDateEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            circular
        case .accessoryRectangular:
            rectangular
        case .accessoryInline:
            inline
        default:
            homeScreen
        }
    }

    private var daysLabel: String {
        guard entry.name != nil else { return "" }
        switch entry.daysUntil {
        case 0: return "É hoje!"
        case 1: return "Falta 1 dia"
        default: return "Faltam \(entry.daysUntil) dias"
        }
    }

    private var homeScreen: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let type = entry.type {
                Image(systemName: type.symbolName)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let name = entry.name {
                Text(name)
                    .font(.headline)
                    .lineLimit(2)
                Text(daysLabel)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text("Nenhuma data próxima")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var circular: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 0) {
                Text("\(entry.daysUntil)")
                    .font(.title2.bold())
                Text("dias")
                    .font(.caption2)
            }
        }
        .containerBackground(.clear, for: .widget)
    }

    private var rectangular: some View {
        HStack {
            if let type = entry.type {
                Image(systemName: type.symbolName)
            }
            VStack(alignment: .leading) {
                Text(entry.name ?? "Nenhuma data")
                    .font(.headline)
                    .lineLimit(1)
                Text(daysLabel.isEmpty ? "—" : daysLabel)
                    .font(.caption)
            }
        }
        .containerBackground(.clear, for: .widget)
    }

    private var inline: some View {
        Text(entry.name.map { "\($0): \(daysLabel)" } ?? "Nenhuma data próxima")
            .containerBackground(.clear, for: .widget)
    }
}

struct NextDateWidget: Widget {
    let kind = "NextDateWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NextDateProvider()) { entry in
            NextDateWidgetView(entry: entry)
        }
        .configurationDisplayName("Próxima data")
        .description("Contagem regressiva para a próxima data importante.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

#Preview(as: .systemSmall) {
    NextDateWidget()
} timeline: {
    NextDateEntry(date: .now, name: "Aniversário da Mari", type: .birthday, daysUntil: 3)
}
