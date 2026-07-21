//
//  ImportantDateListView.swift
//  Marco
//

import SwiftUI
import SwiftData

struct ImportantDateListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var importantDates: [ImportantDate]
    @State private var isPresentingNewDate = false
    @State private var isPresentingImport = false

    private var sortedDates: [ImportantDate] {
        importantDates.sorted {
            $0.daysUntilNextOccurrence() < $1.daysUntilNextOccurrence()
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if sortedDates.isEmpty {
                    ContentUnavailableView {
                        Label("Nenhuma data cadastrada", systemImage: "calendar.badge.plus")
                    } description: {
                        Text("Toque em + para adicionar uma data importante.")
                    } actions: {
                        Button("Importar…") {
                            isPresentingImport = true
                        }
                    }
                } else {
                    ForEach(sortedDates) { importantDate in
                        NavigationLink {
                            ImportantDateFormView(importantDate: importantDate)
                        } label: {
                            ImportantDateRow(importantDate: importantDate)
                        }
                    }
                    .onDelete(perform: delete)
                }
            }
            .navigationTitle("Datas importantes")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            isPresentingNewDate = true
                        } label: {
                            Label("Adicionar", systemImage: "plus")
                        }
                        Button {
                            isPresentingImport = true
                        } label: {
                            Label("Importar…", systemImage: "square.and.arrow.down")
                        }
                    } label: {
                        Label("Adicionar", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $isPresentingNewDate) {
                NavigationStack {
                    ImportantDateFormView(importantDate: nil)
                }
            }
            .sheet(isPresented: $isPresentingImport) {
                ImportCandidatesReviewView()
            }
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            let importantDate = sortedDates[index]
            NotificationService.cancel(importantDate)
            modelContext.delete(importantDate)
        }
    }
}

private struct ImportantDateRow: View {
    let importantDate: ImportantDate

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(importantDate.name)
                    .font(.headline)
                Text(importantDate.type.displayName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let ageLabel = ImportantDate.ageLabel(forAge: importantDate.age()) {
                    Text(ageLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(importantDate.daysRemainingLabel)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Rótulos em pt-BR

extension ImportantDate {
    /// Texto amigável de "quanto falta" até a próxima ocorrência.
    var daysRemainingLabel: String {
        switch daysUntilNextOccurrence() {
        case 0: return "Hoje"
        case 1: return "Amanhã"
        case let days: return "Faltam \(days) dias"
        }
    }

    /// Texto "faz N anos" a partir de uma idade já calculada (ver `age(on:calendar:)`);
    /// `nil` quando não há idade (sem `birthYear`), caso em que nada deve ser exibido.
    static func ageLabel(forAge age: Int?) -> String? {
        guard let age else { return nil }
        return "Faz \(age) anos"
    }
}

extension DateType {
    var displayName: String {
        switch self {
        case .birthday: return "Aniversário"
        case .commemorative: return "Comemorativa"
        case .memorial: return "Memorial"
        }
    }
}

extension Relationship {
    var displayName: String {
        switch self {
        case .partner: return "Cônjuge/Parceiro(a)"
        case .family: return "Família"
        case .friend: return "Amigo(a)"
        case .colleague: return "Colega"
        case .other: return "Outro"
        }
    }
}

#Preview {
    ImportantDateListView()
        .modelContainer(for: ImportantDate.self, inMemory: true)
}
