//
//  ImportCandidatesReviewView.swift
//  Marco
//

import SwiftUI
import SwiftData

/// Sheet de revisão dos candidatos de importação (Contatos + EventKit, T16/T17). Busca os
/// candidatos das duas fontes em paralelo, remove os que já existem no store e deixa o usuário
/// escolher (pré-marcados) o que importar de fato — nada entra sem confirmação explícita (T18).
struct ImportCandidatesReviewView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var importantDates: [ImportantDate]

    @State private var isLoading = true
    @State private var newCandidates: [ImportCandidate] = []
    @State private var selectedIDs: Set<UUID> = []

    private var groupedBySource: [(source: ImportSource, candidates: [ImportCandidate])] {
        [
            (.contacts, newCandidates.filter { $0.source == .contacts }),
            (.calendar, newCandidates.filter { $0.source == .calendar }),
        ].filter { !$0.candidates.isEmpty }
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Buscando datas…")
                } else if newCandidates.isEmpty {
                    ContentUnavailableView(
                        "Nada novo para importar",
                        systemImage: "checkmark.circle",
                        description: Text("Não encontramos datas novas nos Contatos ou no Calendário.")
                    )
                } else {
                    List {
                        ForEach(groupedBySource, id: \.source) { group in
                            Section(group.source.displayName) {
                                ForEach(group.candidates) { candidate in
                                    candidateRow(candidate)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Importar datas")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Importar") { importSelected() }
                        .disabled(isLoading || selectedIDs.isEmpty)
                }
            }
            .task {
                await loadCandidates()
            }
        }
    }

    private func candidateRow(_ candidate: ImportCandidate) -> some View {
        Button {
            toggle(candidate)
        } label: {
            HStack {
                Image(systemName: selectedIDs.contains(candidate.id) ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selectedIDs.contains(candidate.id) ? Color.accentColor : Color.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(candidate.name)
                    dateLabel(for: candidate)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
    }

    /// `Text` (não `String`/`LocalizedStringResource`) construído diretamente na chamada — só
    /// assim o literal "de" entre a data formatada e o ano é reconhecido e extraído pelo Xcode
    /// (uma `LocalizedStringResource` composta por duas interpolações arriscaria colidir com
    /// outra chave genérica de mesmo formato "%@ ... %lld").
    @ViewBuilder
    private func dateLabel(for candidate: ImportCandidate) -> some View {
        let formatted = candidate.date.formatted(.dateTime.day().month(.wide))
        if let birthYear = candidate.birthYear {
            Text("\(formatted) de \(birthYear)")
        } else {
            Text(formatted)
        }
    }

    private func toggle(_ candidate: ImportCandidate) {
        if selectedIDs.contains(candidate.id) {
            selectedIDs.remove(candidate.id)
        } else {
            selectedIDs.insert(candidate.id)
        }
    }

    private func loadCandidates() async {
        async let contacts = ContactsImportService.fetchCandidates()
        async let calendarEvents = EventKitImportService.fetchCandidates()
        let all = await contacts + calendarEvents

        newCandidates = Self.deduplicate(all, against: importantDates)
        selectedIDs = Set(newCandidates.map(\.id))
        isLoading = false
    }

    private func importSelected() {
        for candidate in newCandidates where selectedIDs.contains(candidate.id) {
            let importantDate = ImportantDate(
                name: candidate.name,
                date: candidate.date,
                type: candidate.type,
                birthYear: candidate.birthYear
            )
            modelContext.insert(importantDate)
            Task {
                await NotificationService.schedule(importantDate)
            }
        }
        dismiss()
    }

    /// Remove candidatos que já têm uma `ImportantDate` correspondente (mesmo nome, comparado
    /// sem espaços/maiúsculas, e mesmo dia/mês). Lógica pura — testável sem SwiftData/Contacts.
    static func deduplicate(
        _ candidates: [ImportCandidate],
        against existing: [ImportantDate],
        calendar: Calendar = .current
    ) -> [ImportCandidate] {
        candidates.filter { candidate in
            !existing.contains { isMatch($0, candidate, calendar: calendar) }
        }
    }

    private static func isMatch(_ importantDate: ImportantDate, _ candidate: ImportCandidate, calendar: Calendar) -> Bool {
        guard normalizedName(importantDate.name) == normalizedName(candidate.name) else { return false }
        let existingComponents = calendar.dateComponents([.month, .day], from: importantDate.date)
        let candidateComponents = calendar.dateComponents([.month, .day], from: candidate.date)
        return existingComponents.month == candidateComponents.month && existingComponents.day == candidateComponents.day
    }

    private static func normalizedName(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

private extension ImportSource {
    var displayName: LocalizedStringResource {
        switch self {
        case .contacts: return "Contatos"
        case .calendar: return "Calendário"
        }
    }
}

#Preview {
    ImportCandidatesReviewView()
        .modelContainer(for: ImportantDate.self, inMemory: true)
}
