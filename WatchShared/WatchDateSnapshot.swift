//
//  WatchDateSnapshot.swift
//  WatchShared
//

import Foundation
import SwiftUI

/// Versão mínima de `DateType`, sem dependência de `AppIntents`/SwiftData — só o necessário pra
/// escolher um símbolo e exibir no Watch (T21). Mantém os mesmos raw values de `DateType` pra
/// codificar/decodificar sem mapeamento especial.
enum WatchDateKind: String, Codable {
    case birthday
    case commemorative
    case memorial

    /// Espelha `DateType.symbolName` (`Marco/Views/ImportantDateListView.swift`) — mesmo símbolo
    /// por categoria em iOS e watchOS (T41). Antes desta task, este enum usava um mapeamento
    /// próprio (`birthday.cake`/`star`/`flame`), divergente do app (achado registrado na SPEC
    /// seção 7).
    var symbolName: String {
        switch self {
        case .birthday: "heart"
        case .commemorative: "star"
        case .memorial: "leaf"
        }
    }

    /// Cor da categoria (T41) — mesmo mapeamento de `DateType.stripeColor`, usado no número de
    /// dias e no símbolo da lista do Watch (`WatchDateListView`). `import SwiftUI` foi adicionado
    /// a este arquivo (antes só `Foundation`) porque este é o único lugar visível aos três alvos
    /// (`Marco`, `MarcoWatch`, `MarcoWatchWidgets`) — SwiftUI já é dependência de todos eles, e
    /// centralizar aqui evita duplicar o mapeamento na view do Watch.
    var categoryColor: Color {
        switch self {
        case .birthday: Color("MarcosGreen")
        case .commemorative: Color("MarcoDarkGreen")
        case .memorial: Color("MarcoGray")
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

    /// Texto "Faltam N dias", reaproveitado pela lista do Watch. Tipado como
    /// `LocalizedStringResource` (não `String`) para que cada caso vire sua própria chave de
    /// localização — mesmo padrão de `ImportantDateEntity.subtitleText`.
    func daysUntilLabel(from referenceDate: Date = .now, calendar: Calendar = .current) -> LocalizedStringResource {
        switch daysUntil(from: referenceDate, calendar: calendar) {
        case 0: return "Hoje"
        case 1: return "Amanhã"
        case let days: return "Faltam \(days) dias"
        }
    }

    /// "15 de Junho" — mesmo formato de `ImportantDate.dateLabel` (`ImportantDateListView.swift`),
    /// usado como subtítulo do card na lista do Watch (T41): o número de dias já aparece no bloco
    /// grande ao lado, então o subtítulo mostra a data em vez de repetir "Faltam N dias".
    var dateLabel: String {
        nextOccurrence.formatted(.dateTime.day().month(.wide))
    }
}
