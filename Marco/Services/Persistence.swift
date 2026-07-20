//
//  Persistence.swift
//  Marco
//

import SwiftData

/// Ponto único do `ModelContainer`, compartilhado entre a UI (`MarcoApp`) e os App Intents,
/// que rodam no mesmo processo. Precisa ser o mesmo objeto nos dois lados: um `ModelContainer`
/// próprio no intent apontaria pro mesmo arquivo em disco, mas não refletiria mudanças feitas
/// pela UI ainda em memória (e vice-versa) até um save/refetch cruzado.
enum Persistence {
    static let container: ModelContainer = {
        let schema = Schema([ImportantDate.self])
        let configuration = ModelConfiguration(schema: schema)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Não foi possível criar o ModelContainer: \(error)")
        }
    }()
}
