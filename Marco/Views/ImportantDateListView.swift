//
//  ImportantDateListView.swift
//  Marco
//

import SwiftUI
import SwiftData

struct ImportantDateListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(NotificationNavigationCoordinator.self) private var notificationCoordinator
    @Query private var importantDates: [ImportantDate]
    @State private var isPresentingNewDate = false
    @State private var isPresentingImport = false
    @State private var path = NavigationPath()

    private var sortedDates: [ImportantDate] {
        importantDates.sorted {
            $0.daysUntilNextOccurrence() < $1.daysUntilNextOccurrence()
        }
    }

    var body: some View {
        NavigationStack(path: $path) {
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
                        NavigationLink(value: importantDate.id) {
                            ImportantDateRow(importantDate: importantDate)
                        }
                    }
                    .onDelete(perform: delete)
                }
            }
            .navigationDestination(for: UUID.self) { id in
                if let importantDate = importantDates.first(where: { $0.id == id }) {
                    ImportantDateFormView(importantDate: importantDate)
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
        .onAppear(perform: navigateToPendingImportantDateIfNeeded)
        .onChange(of: notificationCoordinator.pendingImportantDateID) {
            navigateToPendingImportantDateIfNeeded()
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            let importantDate = sortedDates[index]
            NotificationService.cancel(importantDate)
            modelContext.delete(importantDate)
        }
    }

    /// Deep-link da ação "Abrir para mensagem"/toque na notificação (T22): navega até o detalhe
    /// da `ImportantDate` sinalizada pelo `NotificationDelegate`, se ela ainda existir.
    private func navigateToPendingImportantDateIfNeeded() {
        guard let id = notificationCoordinator.pendingImportantDateID,
              importantDates.contains(where: { $0.id == id }) else { return }
        path.append(id)
        notificationCoordinator.pendingImportantDateID = nil
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
        .environment(NotificationNavigationCoordinator())
}
