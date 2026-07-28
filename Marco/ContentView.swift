//
//  ContentView.swift
//  Marco
//
//  Created by Eduardo Garcia Fensterseifer on 16/07/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        TabView {
            Tab("Datas", systemImage: "calendar.badge") {
                ImportantDateListView()
            }
            Tab("Buscar", systemImage: "magnifyingglass", role: .search) {
                SearchDatesView()
            }
        }
        .tint(Color("MarcosGreen"))
    }
}

#Preview {
    ContentView()
        .modelContainer(for: ImportantDate.self, inMemory: true)
        .environment(NotificationNavigationCoordinator())
}
