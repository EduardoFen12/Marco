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
        ImportantDateListView()
    }
}

#Preview {
    ContentView()
        .modelContainer(for: ImportantDate.self, inMemory: true)
        .environment(NotificationNavigationCoordinator())
}
