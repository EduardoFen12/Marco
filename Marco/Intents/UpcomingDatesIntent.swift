//
//  UpcomingDatesIntent.swift
//  Marco
//

import AppIntents
import Foundation
import SwiftData

/// Query read-only: retorna as próximas datas importantes cadastradas, ordenadas por
/// proximidade. Falável pela Siri e encadeável no Shortcuts (retorna `[ImportantDateEntity]`).
struct UpcomingDatesIntent: AppIntent {
    static let title: LocalizedStringResource = "Datas chegando"

    /// ponytail: limite fixo de 5 — trocar por parâmetro configurável se um dia fizer sentido
    /// pedir "as próximas N datas" por voz.
    private static let limit = 5

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<[ImportantDateEntity]> & ProvidesDialog {
        let context = ModelContext(Persistence.container)
        let descriptor = FetchDescriptor<ImportantDate>()
        let upcoming = try context.fetch(descriptor)
            .sorted { $0.daysUntilNextOccurrence() < $1.daysUntilNextOccurrence() }
            .prefix(Self.limit)
            .map(ImportantDateEntity.init(model:))

        let dialog: IntentDialog
        switch upcoming.count {
        case 0: dialog = "Nenhuma data cadastrada."
        case 1: dialog = "Você tem 1 data chegando."
        default: dialog = "Você tem \(upcoming.count) datas chegando."
        }

        return .result(value: Array(upcoming), dialog: dialog)
    }
}
