//
//  DateType.swift
//  Marco
//

import Foundation

/// Tipo de uma `ImportantDate`. Conforma a `Codable` para persistência via SwiftData;
/// conformará a `AppEnum` quando exposta em App Intents (T5+).
enum DateType: String, Codable, CaseIterable {
    case birthday
    case commemorative
    case memorial
}
