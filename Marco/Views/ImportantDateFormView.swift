//
//  ImportantDateFormView.swift
//  Marco
//

import SwiftUI
import SwiftData

/// Tela de criação/edição de uma `ImportantDate`. Passe `importantDate: nil` para criar
/// uma nova data ou a instância existente para editá-la.
struct ImportantDateFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    private let importantDate: ImportantDate?

    @State private var name: String
    @State private var date: Date
    @State private var type: DateType
    @State private var relationship: Relationship?
    @State private var notes: String

    init(importantDate: ImportantDate?) {
        self.importantDate = importantDate
        _name = State(initialValue: importantDate?.name ?? "")
        _date = State(initialValue: importantDate?.date ?? .now)
        _type = State(initialValue: importantDate?.type ?? .birthday)
        _relationship = State(initialValue: importantDate?.relationship)
        _notes = State(initialValue: importantDate?.notes ?? "")
    }

    private var isNameValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        Form {
            Section("Informações") {
                TextField("Nome", text: $name)
                DatePicker("Data", selection: $date, displayedComponents: .date)
                Picker("Tipo", selection: $type) {
                    ForEach(DateType.allCases, id: \.self) { type in
                        Text(type.displayName).tag(type)
                    }
                }
            }

            Section("Relacionamento") {
                Picker("Relacionamento", selection: $relationship) {
                    Text("Nenhum").tag(Relationship?.none)
                    ForEach(Relationship.allCases, id: \.self) { relationship in
                        Text(relationship.displayName).tag(Relationship?.some(relationship))
                    }
                }
            }

            Section("Notas") {
                TextField("Notas (opcional)", text: $notes, axis: .vertical)
                    .lineLimit(3...6)
            }
        }
        .navigationTitle(importantDate == nil ? "Nova data" : "Editar data")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if importantDate == nil {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Salvar") { save() }
                    .disabled(!isNameValid)
            }
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)

        let savedDate: ImportantDate
        if let importantDate {
            importantDate.name = trimmedName
            importantDate.date = date
            importantDate.type = type
            importantDate.relationship = relationship
            importantDate.notes = trimmedNotes.isEmpty ? nil : trimmedNotes
            savedDate = importantDate
        } else {
            let newDate = ImportantDate(
                name: trimmedName,
                date: date,
                type: type,
                relationship: relationship,
                notes: trimmedNotes.isEmpty ? nil : trimmedNotes
            )
            modelContext.insert(newDate)
            savedDate = newDate
        }
        Task { await NotificationService.schedule(savedDate) }
        dismiss()
    }
}

#Preview("Criar") {
    NavigationStack {
        ImportantDateFormView(importantDate: nil)
    }
    .modelContainer(for: ImportantDate.self, inMemory: true)
}

#Preview("Editar") {
    NavigationStack {
        ImportantDateFormView(importantDate: ImportantDate(
            name: "Mari",
            date: .now,
            type: .birthday,
            relationship: .partner,
            notes: "Gosta de plantas"
        ))
    }
    .modelContainer(for: ImportantDate.self, inMemory: true)
}
