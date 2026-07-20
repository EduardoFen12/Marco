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
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(Persistence.container)
    }
}
