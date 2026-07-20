//
//  DateType.swift
//  Marco
//

import AppIntents
import Foundation

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
}
