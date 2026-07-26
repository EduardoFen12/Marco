//
//  DateType.swift
//  Marco
//

import AppIntents
import Foundation
import SwiftUI

/// Tipo de uma `ImportantDate`. Conforma a `Codable` para persistência via SwiftData e a
/// `AppEnum` para uso em App Intents (T7).
enum DateType: String, Codable, CaseIterable, AppEnum {
    case birthday
    case commemorative
    case memorial
    case appointment

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Tipo de data"

    static var caseDisplayRepresentations: [DateType: DisplayRepresentation] = [
        .birthday: "Aniversário",
        .commemorative: "Comemorativa",
        .memorial: "Memorial",
        .appointment: "Compromisso",
    ]

    /// Cor da stripe de categoria à esquerda da célula (T33) e do número de dias no card (T39) —
    /// usa apenas color sets do design system (T29), sem hex hardcoded. Ajustada na T39 para bater
    /// com o mock `13:5`: memorial cinza, aniversário teal, comemorativa verde escuro (T33 tinha
    /// posto `MarcoMint`, um mint claro, na comemorativa — sem referência de mock à época).
    var stripeColor: Color {
        switch self {
        case .birthday: return Color("MarcosGreen")
        case .commemorative: return Color("MarcoDarkGreen")
        case .memorial: return Color("MarcoGray")
        case .appointment: return Color("MarcoDeepGreen")
        }
    }

    /// SF Symbol da categoria — mapeamento único usado por app, widget iOS, Watch e complications
    /// (T42). Símbolos literais do que cada tipo representa (bolo/festa/folha/agenda) em vez dos
    /// genéricos `heart`/`star`/`leaf` da T40: nas glanceable surfaces (widget, complication) o
    /// símbolo é a única pista da categoria, então precisa se explicar sozinho.
    var symbolName: String {
        switch self {
        case .birthday: return "birthday.cake.fill"
        case .commemorative: return "party.popper.fill"
        case .memorial: return "leaf.fill"
        case .appointment: return "calendar.badge.clock"
        }
    }
}
