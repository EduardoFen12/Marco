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

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Tipo de data"

    static var caseDisplayRepresentations: [DateType: DisplayRepresentation] = [
        .birthday: "Aniversário",
        .commemorative: "Comemorativa",
        .memorial: "Memorial",
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
        }
    }

    /// SF Symbol da categoria (T40, mock `24:159`, linha do tipo no header do Detalhe): `heart`
    /// para aniversário, `star` para comemorativa, `leaf` para memorial. Movido para `Shared/` na
    /// T42 para ser o mapeamento único usado por app e widget (encerra a divergência com o
    /// `birthday.cake`/`star`/`flame` que `MarcoWidgets/NextDateWidget.swift` tinha desde a T20).
    var symbolName: String {
        switch self {
        case .birthday: return "heart"
        case .commemorative: return "star"
        case .memorial: return "leaf"
        }
    }
}
