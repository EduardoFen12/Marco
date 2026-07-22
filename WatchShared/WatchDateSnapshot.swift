//
//  WatchDateSnapshot.swift
//  WatchShared
//

import Foundation

/// Versão mínima de `DateType`, sem dependência de `AppIntents`/SwiftData — só o necessário pra
/// escolher um símbolo e exibir no Watch (T21). Mantém os mesmos raw values de `DateType` pra
/// codificar/decodificar sem mapeamento especial.
enum WatchDateKind: String, Codable {
    case birthday
    case commemorative
    case memorial

    var symbolName: String {
        switch self {
        case .birthday: "birthday.cake"
        case .commemorative: "star"
        case .memorial: "flame"
        }
    }
}

/// Snapshot leve de uma `ImportantDate`, enviado do iPhone ao Watch via
/// `WCSession.updateApplicationContext(_:)` — App Group não é compartilhado entre iOS e watchOS
/// (dispositivos físicos separados, ver SPEC seção 7), então essa struct (não o `ImportantDate`
/// completo/SwiftData) é o que atravessa a sincronização.
///
/// Guarda a próxima ocorrência (não os "dias restantes" já calculados na hora do envio) para que
/// a contagem regressiva no Watch continue avançando dia a dia sem depender do iPhone
/// ressincronizar todo santo dia.
struct WatchDateSnapshot: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var kind: WatchDateKind
    /// Meia-noite (calendário local de quem enviou) do dia da próxima ocorrência.
    var nextOccurrence: Date

    /// Dias restantes até `nextOccurrence`, calculados no momento da exibição (não no envio).
    func daysUntil(from referenceDate: Date = .now, calendar: Calendar = .current) -> Int {
        let startOfToday = calendar.startOfDay(for: referenceDate)
        let startOfOccurrence = calendar.startOfDay(for: nextOccurrence)
        return calendar.dateComponents([.day], from: startOfToday, to: startOfOccurrence).day ?? 0
    }

    /// Texto "Faltam N dias" em pt-BR, reaproveitado pela lista e pela complication.
    func daysUntilLabel(from referenceDate: Date = .now, calendar: Calendar = .current) -> String {
        switch daysUntil(from: referenceDate, calendar: calendar) {
        case 0: return "Hoje"
        case 1: return "Amanhã"
        case let days: return "Faltam \(days) dias"
        }
    }
}
