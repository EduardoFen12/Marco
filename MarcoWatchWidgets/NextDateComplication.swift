//
//  NextDateComplication.swift
//  MarcoWatchWidgets
//

import WidgetKit
import SwiftUI

/// Uma entrada da timeline da complication: a data mais próxima do snapshot local
/// (`WatchSnapshotStore`) num dado dia de referência, com a contagem regressiva já calculada.
/// Mesmo padrão do `NextDateEntry` do widget iOS (T20), lendo o snapshot do Watch em vez do
/// `ModelContainer` compartilhado (não existe entre iOS e watchOS — ver SPEC seção 7).
struct NextDateComplicationEntry: TimelineEntry {
    let date: Date
    let name: String?
    let daysUntil: Int
}

struct NextDateComplicationProvider: TimelineProvider {
    /// Quantos dias de entries pré-calcular antes de pedir uma timeline nova ao sistema.
    private static let daysAhead = 7

    func placeholder(in context: Context) -> NextDateComplicationEntry {
        NextDateComplicationEntry(date: .now, name: String(localized: "Aniversário da Mari"), daysUntil: 3)
    }

    func getSnapshot(in context: Context, completion: @escaping (NextDateComplicationEntry) -> Void) {
        completion(
            NextDateComplicationEntry(date: .now, name: String(localized: "Aniversário da Mari"), daysUntil: 3)
        )
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NextDateComplicationEntry>) -> Void) {
        let calendar = Calendar.current
        let snapshots = WatchSnapshotStore.load()

        let today = calendar.startOfDay(for: .now)
        var entries: [NextDateComplicationEntry] = []

        for offset in 0..<Self.daysAhead {
            guard let referenceDate = calendar.date(byAdding: .day, value: offset, to: today) else { continue }
            let closest = snapshots
                .map { ($0, $0.daysUntil(from: referenceDate, calendar: calendar)) }
                .min { $0.1 < $1.1 }
            entries.append(
                NextDateComplicationEntry(date: referenceDate, name: closest?.0.name, daysUntil: closest?.1 ?? 0)
            )
        }

        if entries.isEmpty {
            entries = [NextDateComplicationEntry(date: today, name: nil, daysUntil: 0)]
        }

        let refreshDate = calendar.date(byAdding: .day, value: Self.daysAhead, to: today) ?? today
        completion(Timeline(entries: entries, policy: .after(refreshDate)))
    }
}

struct NextDateComplicationView: View {
    @Environment(\.widgetFamily) private var family
    let entry: NextDateComplicationEntry

    /// `nil` quando não há data próxima (`entry.name == nil`) — mesmo padrão de
    /// `NextDateWidgetView.daysLabel` (T20).
    private var daysLabel: LocalizedStringResource? {
        guard entry.name != nil else { return nil }
        switch entry.daysUntil {
        case 0: return "É hoje!"
        case 1: return "Falta 1 dia"
        default: return "Faltam \(entry.daysUntil) dias"
        }
    }

    var body: some View {
        switch family {
        case .accessoryRectangular:
            rectangular
        case .accessoryInline:
            inline
        case .accessoryCorner:
            corner
        default:
            circular
        }
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
        VStack(alignment: .leading) {
            Text(entry.name ?? "Nenhuma data")
                .font(.headline)
                .lineLimit(1)
            Text(daysLabel ?? "—")
                .font(.caption)
        }
        .containerBackground(.clear, for: .widget)
    }

    /// Concatena `Text`s (nome + rótulo) em vez de compor um `String` — mesmo racional de
    /// `NextDateWidgetView.inline` (T20).
    private var inline: some View {
        Group {
            if let name = entry.name, let daysLabel {
                Text(name) + Text(": ") + Text(daysLabel)
            } else {
                Text("Nenhuma data próxima")
            }
        }
        .containerBackground(.clear, for: .widget)
    }

    private var corner: some View {
        Text("\(entry.daysUntil)")
            .font(.title3.bold())
            .widgetLabel {
                Text(entry.name ?? "Nenhuma data")
            }
            .containerBackground(.clear, for: .widget)
    }
}

struct NextDateComplication: Widget {
    let kind = "NextDateComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NextDateComplicationProvider()) { entry in
            NextDateComplicationView(entry: entry)
        }
        .configurationDisplayName("Próxima data")
        .description("Contagem regressiva para a próxima data importante.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline, .accessoryCorner])
    }
}

#Preview(as: .accessoryCircular) {
    NextDateComplication()
} timeline: {
    NextDateComplicationEntry(date: .now, name: "Aniversário da Mari", daysUntil: 3)
}
