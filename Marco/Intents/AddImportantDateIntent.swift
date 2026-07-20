//
//  AddImportantDateIntent.swift
//  Marco
//

import AppIntents
import Foundation
import SwiftData

/// Intent de escrita: cria uma `ImportantDate` a partir de nome, data e tipo, persiste no
/// `ModelContainer` compartilhado e agenda as notificações (reuso do `NotificationService`).
struct AddImportantDateIntent: AppIntent {
    static let title: LocalizedStringResource = "Adicionar data importante"

    @Parameter(title: "Nome", requestValueDialog: "Qual o nome da data?")
    var name: String

    @Parameter(title: "Data", kind: .date, requestValueDialog: "Quando é a data?")
    var date: Date

    @Parameter(title: "Tipo", requestValueDialog: "Que tipo de data é essa?")
    var type: DateType

    static var parameterSummary: some ParameterSummary {
        Summary("Adicionar \(\.$name) (\(\.$type)) em \(\.$date)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<ImportantDateEntity> & ProvidesDialog {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw $name.needsValueError("Qual o nome da data?")
        }

        let importantDate = ImportantDate(name: trimmedName, date: date, type: type)
        let context = ModelContext(Persistence.container)
        context.insert(importantDate)
        try context.save()

        await NotificationService.schedule(importantDate)

        return .result(
            value: ImportantDateEntity(model: importantDate),
            dialog: "Adicionei \(trimmedName)."
        )
    }
}
