//
//  ImportCandidate.swift
//  Marco
//

import Foundation

/// De onde veio um `ImportCandidate` — usado para agrupar a tela de revisão por fonte (T18).
enum ImportSource: String {
    case contacts
    case calendar
}

/// Candidato a `ImportantDate` vindo de uma fonte externa (Contatos, EventKit). Dado transiente
/// de revisão — só vira `ImportantDate` de fato quando o usuário confirma a importação (T18).
struct ImportCandidate: Identifiable, Equatable {
    let id: UUID
    let name: String
    /// Dia/mês contra o ano bissexto fixo 2000, mesma convenção de `ImportantDate.date`.
    let date: Date
    let type: DateType
    let birthYear: Int?
    let source: ImportSource

    init(
        id: UUID = UUID(),
        name: String,
        date: Date,
        type: DateType,
        birthYear: Int? = nil,
        source: ImportSource
    ) {
        self.id = id
        self.name = name
        self.date = date
        self.type = type
        self.birthYear = birthYear
        self.source = source
    }
}
