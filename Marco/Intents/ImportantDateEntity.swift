//
//  ImportantDateEntity.swift
//  Marco
//

import AppIntents
import Foundation
import SwiftData

/// Representação Sendable de uma `ImportantDate` para uso em App Intents. `ImportantDate` é um
/// `@Model` (não Sendable), então não conforma diretamente a `AppEntity` — este struct guarda só
/// os campos simples necessários para exibição/resolução.
struct ImportantDateEntity: AppEntity, Identifiable {
    let id: UUID
    let name: String
    let daysUntilNextOccurrence: Int

    init(model: ImportantDate) {
        id = model.id
        name = model.name
        daysUntilNextOccurrence = model.daysUntilNextOccurrence()
    }

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Data Importante"

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", subtitle: subtitleText)
    }

    /// Tipado como `LocalizedStringResource` (não `String`) para que cada caso vire sua própria
    /// chave de localização — embrulhar um `String` numa interpolação (`"\(texto)"`) geraria a
    /// chave genérica "%@" e quebraria a comparação por igualdade usada nos testes.
    private var subtitleText: LocalizedStringResource {
        switch daysUntilNextOccurrence {
        case 0: return "Hoje"
        case 1: return "Amanhã"
        case let days: return "Faltam \(days) dias"
        }
    }

    static var defaultQuery = ImportantDateEntityQuery()
}

/// Busca `ImportantDateEntity` no `ModelContainer` compartilhado (`Persistence.container`).
struct ImportantDateEntityQuery: EntityQuery, EntityStringQuery {
    @MainActor
    func entities(for identifiers: [UUID]) async throws -> [ImportantDateEntity] {
        let context = ModelContext(Persistence.container)
        let descriptor = FetchDescriptor<ImportantDate>(
            predicate: #Predicate { identifiers.contains($0.id) }
        )
        return try context.fetch(descriptor).map(ImportantDateEntity.init(model:))
    }

    @MainActor
    func suggestedEntities() async throws -> [ImportantDateEntity] {
        try await allSortedByProximity()
    }

    @MainActor
    func entities(matching string: String) async throws -> [ImportantDateEntity] {
        try await allSortedByProximity().filter {
            $0.name.localizedStandardContains(string)
        }
    }

    @MainActor
    private func allSortedByProximity() async throws -> [ImportantDateEntity] {
        let context = ModelContext(Persistence.container)
        let descriptor = FetchDescriptor<ImportantDate>()
        return try context.fetch(descriptor)
            .sorted { $0.daysUntilNextOccurrence() < $1.daysUntilNextOccurrence() }
            .map(ImportantDateEntity.init(model:))
    }
}
