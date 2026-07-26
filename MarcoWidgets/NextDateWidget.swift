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
    /// "15 de Junho" (`ImportantDate.dateLabel`) — já formatada pelo provider (T42), para a
    /// `.systemMedium` mostrar a data por extenso sem recalcular formatação de data na view.
    let dateLabel: String?
}

struct NextDateProvider: TimelineProvider {
    /// Quantos dias de entries pré-calcular antes de pedir uma timeline nova ao sistema.
    private static let daysAhead = 7

    func placeholder(in context: Context) -> NextDateEntry {
        NextDateEntry(date: .now, name: String(localized: "Aniversário da Mari"), type: .birthday, daysUntil: 3, dateLabel: "15 de Junho")
    }

    func getSnapshot(in context: Context, completion: @escaping (NextDateEntry) -> Void) {
        completion(
            NextDateEntry(date: .now, name: String(localized: "Aniversário da Mari"), type: .birthday, daysUntil: 3, dateLabel: "15 de Junho")
        )
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
                    daysUntil: closest?.1 ?? 0,
                    dateLabel: closest?.0.dateLabel
                )
            )
        }

        if entries.isEmpty {
            entries = [NextDateEntry(date: today, name: nil, type: nil, daysUntil: 0, dateLabel: nil)]
        }

        let refreshDate = calendar.date(byAdding: .day, value: Self.daysAhead, to: today) ?? today
        completion(Timeline(entries: entries, policy: .after(refreshDate)))
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
        case .systemMedium:
            mediumScreen
        default:
            smallScreen
        }
    }

    /// `nil` quando não há data próxima (`entry.name == nil`) — tipado como
    /// `LocalizedStringResource` (não `String`) para que cada caso vire sua própria chave de
    /// localização, mesmo padrão de `ImportantDateEntity.subtitleText`.
    private var daysLabel: LocalizedStringResource? {
        guard entry.name != nil else { return nil }
        switch entry.daysUntil {
        case 0: return "É hoje!"
        case 1: return "Falta 1 dia"
        default: return "Faltam \(entry.daysUntil) dias"
        }
    }

    /// Cor da categoria (`DateType.stripeColor`) para o número/símbolo; `MarcoLabel` como
    /// fallback quando não há data próxima (`entry.type == nil`).
    private var categoryColor: Color {
        entry.type?.stripeColor ?? Color("MarcoLabel")
    }

    private var emptyState: some View {
        Text("Nenhuma data próxima")
            .font(.subheadline)
            .foregroundStyle(Color("MarcoLabelSecondary"))
    }

    /// Prioriza o bloco número + "DIAS" (T39/T40) e o nome; sem espaço pra data por extenso.
    private var smallScreen: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let type = entry.type {
                Image(systemName: type.symbolName)
                    .foregroundStyle(categoryColor)
            }
            Spacer()
            if let name = entry.name {
                Text(entry.daysUntil, format: .number)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(categoryColor)
                Text("DIAS")
                    .font(.caption2.bold())
                    .tracking(1)
                    .foregroundStyle(Color("MarcoLabelSecondary"))
                Text(name)
                    .font(.subheadline.bold())
                    .foregroundStyle(Color("MarcoLabel"))
                    .lineLimit(2)
            } else {
                emptyState
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(Color("MarcoCream"), for: .widget)
    }

    /// Espaço extra em relação à `.systemSmall` para a data por extenso (`entry.dateLabel`) junto
    /// do nome, mesmo bloco número + "DIAS" de `ImportantDateRow` (T39) à direita.
    private var mediumScreen: some View {
        HStack(alignment: .center, spacing: 12) {
            if let name = entry.name {
                VStack(alignment: .leading, spacing: 4) {
                    if let type = entry.type {
                        Image(systemName: type.symbolName)
                            .foregroundStyle(categoryColor)
                    }
                    Text(name)
                        .font(.title3.bold())
                        .foregroundStyle(Color("MarcoLabel"))
                        .lineLimit(2)
                    if let dateLabel = entry.dateLabel {
                        Text(dateLabel)
                            .font(.subheadline)
                            .foregroundStyle(Color("MarcoLabelSecondary"))
                    }
                }

                Spacer(minLength: 12)

                VStack(spacing: 0) {
                    Text(entry.daysUntil, format: .number)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(categoryColor)
                    Text("DIAS")
                        .font(.caption2.bold())
                        .tracking(1)
                        .foregroundStyle(Color("MarcoLabelSecondary"))
                }
            } else {
                emptyState
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(Color("MarcoCream"), for: .widget)
    }

    private var circular: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 0) {
                Text("\(entry.daysUntil)")
                    .font(.title2.bold())
                Text("DIAS")
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
                Text(daysLabel ?? "—")
                    .font(.caption)
            }
        }
        .containerBackground(.clear, for: .widget)
    }

    /// Concatena `Text`s (nome + rótulo) em vez de compor um `String` — o nome não deve ser
    /// localizado, mas o rótulo de dias sim; `Text + Text` mantém ambos os pedaços corretos.
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
    NextDateEntry(date: .now, name: "Aniversário da Mari", type: .birthday, daysUntil: 3, dateLabel: "15 de Junho")
}
