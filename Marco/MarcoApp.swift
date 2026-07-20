//
//  MarcoApp.swift
//  Marco
//
//  Created by Eduardo Garcia Fensterseifer on 16/07/26.
//

import SwiftUI
import SwiftData

@main
struct MarcoApp: App {
    // ponytail: schema vazio até T2 adicionar os @Model; incluir os tipos aqui quando existirem.
    let modelContainer: ModelContainer = {
        let schema = Schema([])
        let configuration = ModelConfiguration(schema: schema)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Não foi possível criar o ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(modelContainer)
    }
}
