//
//  Relationship.swift
//  Marco
//

import Foundation

/// Relação da pessoa com o usuário, usada como contexto para as sugestões de IA (T10+).
/// Conforma a `Codable` para persistência via SwiftData; conformará a `AppEnum` quando
/// exposta em App Intents (T5+).
enum Relationship: String, Codable, CaseIterable {
    case partner
    case family
    case friend
    case colleague
    case other
}
