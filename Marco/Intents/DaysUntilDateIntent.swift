//
//  DaysUntilDateIntent.swift
//  Marco
//

import AppIntents
import Foundation

/// Query com parâmetro: quantos dias faltam para uma data importante específica, escolhida
/// por nome ("Quanto falta pro aniversário da Mari?"). A resolução por nome vem de graça via
/// `ImportantDateEntityQuery` (já conforma `EntityStringQuery`).
struct DaysUntilDateIntent: AppIntent {
    static let title: LocalizedStringResource = "Quanto falta para uma data"

    @Parameter(title: "Data")
    var date: ImportantDateEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Quanto falta para \(\.$date)")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<Int> & ProvidesDialog {
        let days = date.daysUntilNextOccurrence
        let dialog: IntentDialog
        switch days {
        case 0: dialog = "É hoje: \(date.name)!"
        case 1: dialog = "É amanhã: \(date.name)!"
        default: dialog = "Faltam \(days) dias para \(date.name)."
        }
        return .result(value: days, dialog: dialog)
    }
}
