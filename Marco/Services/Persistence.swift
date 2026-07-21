//
//  Persistence.swift
//  Marco
//

import Foundation
import SwiftData

/// Ponto único do `ModelContainer`, compartilhado entre a UI (`MarcoApp`) e os App Intents,
/// que rodam no mesmo processo. Precisa ser o mesmo objeto nos dois lados: um `ModelContainer`
/// próprio no intent apontaria pro mesmo arquivo em disco, mas não refletiria mudanças feitas
/// pela UI ainda em memória (e vice-versa) até um save/refetch cruzado.
///
/// O store vive no container do App Group (`group.Eduardo.Marco`), não no container padrão do
/// app, para que o widget (T20) e o app do Watch (T21) possam ler os mesmos dados (ver SPEC 3.8).
enum Persistence {
    /// Identificador do App Group compartilhado com widget e watch. Convenção `group.<bundle-id>`.
    static let appGroupID = "group.Eduardo.Marco"

    static let container: ModelContainer = {
        guard let appGroupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
            fatalError("App Group '\(appGroupID)' não configurado — verifique a entitlement 'com.apple.security.application-groups' do target.")
        }
        let storeURL = appGroupURL.appendingPathComponent("Marco.sqlite")
        let schema = Schema([ImportantDate.self])
        let configuration = ModelConfiguration(schema: schema, url: storeURL)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Não foi possível criar o ModelContainer: \(error)")
        }
    }()
}
