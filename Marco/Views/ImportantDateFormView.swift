//
//  ImportantDateFormView.swift
//  Marco
//

import SwiftUI
import SwiftData
import UIKit
import FoundationModels

/// Tela de criação/edição de uma `ImportantDate`. Passe `importantDate: nil` para criar
/// uma nova data ou a instância existente para editá-la.
struct ImportantDateFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var aiService = AISuggestionService()

    private let importantDate: ImportantDate?

    @State private var name: String
    @State private var date: Date
    @State private var type: DateType
    @State private var relationship: Relationship?
    @State private var notes: String

    @State private var isSuggestingGift = false
    @State private var giftResult: Result<GiftSuggestion, AISuggestionError>?
    @State private var isGeneratingMessage = false
    @State private var messageResult: Result<String, AISuggestionError>?

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

    /// Regra de visibilidade do botão "Sugerir presente": exige modelo disponível e `notes`
    /// preenchidas (senão a sugestão fica genérica demais — ver SPEC 3.4).
    static func showsGiftSuggestion(notes: String, isModelAvailable: Bool) -> Bool {
        isModelAvailable && !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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

            Section("Sugestões de IA") {
                if aiService.isAvailable {
                    if Self.showsGiftSuggestion(notes: notes, isModelAvailable: aiService.isAvailable) {
                        Button {
                            Task { await suggestGift() }
                        } label: {
                            if isSuggestingGift {
                                ProgressView()
                            } else {
                                Label("Sugerir presente", systemImage: "gift")
                            }
                        }
                        .disabled(isSuggestingGift)

                        aiResultView(for: giftResult) { "\($0.title)\n\n\($0.rationale)" }
                    }

                    Button {
                        Task { await generateMessage() }
                    } label: {
                        if isGeneratingMessage {
                            ProgressView()
                        } else {
                            Label("Gerar mensagem", systemImage: "text.bubble")
                        }
                    }
                    .disabled(isGeneratingMessage)

                    aiResultView(for: messageResult) { $0 }
                } else {
                    Text(unavailableExplanation)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
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

    // MARK: - Sugestões de IA

    private var unavailableExplanation: String {
        if case .unavailable(let reason) = aiService.availability {
            return AISuggestionError.unavailable(reason).errorDescription ?? "Sugestões de IA indisponíveis neste momento."
        }
        return "Sugestões de IA indisponíveis neste momento."
    }

    private func suggestGift() async {
        isSuggestingGift = true
        giftResult = await aiService.suggestGift(notes: notes, relationship: relationship)
        isSuggestingGift = false
    }

    private func generateMessage() async {
        isGeneratingMessage = true
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        messageResult = await aiService.personalizedMessage(
            name: name,
            type: type,
            relationship: relationship,
            notes: trimmedNotes.isEmpty ? nil : trimmedNotes
        )
        isGeneratingMessage = false
    }

    @ViewBuilder
    private func aiResultView<T>(for result: Result<T, AISuggestionError>?, text: (T) -> String) -> some View {
        switch result {
        case .success(let value):
            AIResultCard(text: text(value))
        case .failure(let error):
            Text(error.errorDescription ?? "Não foi possível gerar o conteúdo.")
                .font(.footnote)
                .foregroundStyle(.red)
        case .none:
            EmptyView()
        }
    }
}

/// Exibe o texto gerado pela IA com opção de copiar para a área de transferência.
private struct AIResultCard: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(text)
                .font(.callout)
            Button {
                UIPasteboard.general.string = text
            } label: {
                Label("Copiar", systemImage: "doc.on.doc")
            }
            .font(.footnote)
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 4)
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
