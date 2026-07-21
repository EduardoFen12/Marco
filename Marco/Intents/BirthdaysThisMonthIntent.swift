//
//  BirthdaysThisMonthIntent.swift
//  Marco
//

import AppIntents
import Foundation
import SwiftData

/// Query por período: aniversários (`type == .birthday`) do mês corrente, ordenados por
/// proximidade dentro do mês. Falável pela Siri e encadeável no Shortcuts.
struct BirthdaysThisMonthIntent: AppIntent {
    static let title: LocalizedStringResource = "Aniversários do mês"

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<[ImportantDateEntity]> & ProvidesDialog {
        let context = ModelContext(Persistence.container)
        let currentMonth = Calendar.current.component(.month, from: .now)
        let descriptor = FetchDescriptor<ImportantDate>()
        let birthdays = try context.fetch(descriptor)
            .filter { $0.type == .birthday && Calendar.current.component(.month, from: $0.date) == currentMonth }
            .sorted { $0.daysUntilNextOccurrence() < $1.daysUntilNextOccurrence() }
            .map(ImportantDateEntity.init(model:))

        let dialog: IntentDialog
        switch birthdays.count {
        case 0: dialog = "Nenhum aniversário este mês."
        case 1: dialog = "1 aniversário este mês."
        default: dialog = "\(birthdays.count) aniversários este mês."
        }

        return .result(value: birthdays, dialog: dialog)
    }
}
