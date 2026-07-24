//
//  SearchDatesView.swift
//  Marco
//

import SwiftUI
import SwiftData

/// Aba "Buscar" (T27): busca por nome sobre as mesmas `ImportantDate` da lista principal
/// (`@Query`, sem entidade/store nova). Tocar um resultado abre o mesmo formulário de edição,
/// reaproveitando o padrão `navigationDestination(for: UUID.self)` de `ImportantDateListView`.
struct SearchDatesView: View {
    @Query private var importantDates: [ImportantDate]
    @State private var searchText = ""

    private var results: [ImportantDate] {
        guard !searchText.isEmpty else { return [] }
        return importantDates.filter { $0.name.localizedStandardContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            List(results) { importantDate in
                NavigationLink(value: importantDate.id) {
                    ImportantDateRow(importantDate: importantDate)
                }
            }
            .navigationDestination(for: UUID.self) { id in
                if let importantDate = importantDates.first(where: { $0.id == id }) {
                    ImportantDateFormView(importantDate: importantDate)
                }
            }
            .overlay {
                if searchText.isEmpty {
                    ContentUnavailableView("Buscar por nome", systemImage: "magnifyingglass", description: Text("Digite o nome de uma data para buscar."))
                } else if results.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                }
            }
            .navigationTitle("Buscar")
            .searchable(text: $searchText, prompt: "Nome")
        }
    }
}

#Preview {
    SearchDatesView()
        .modelContainer(for: ImportantDate.self, inMemory: true)
}
