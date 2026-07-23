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
    @State private var birthdayMonth: Int
    @State private var birthdayDay: Int
    @State private var type: DateType
    @State private var relationship: Relationship?
    @State private var notes: String
    @State private var birthYearText: String
    @State private var notificationTime: Date
    @State private var hasEventTime: Bool
    @State private var eventTime: Date

    @State private var isSuggestingGift = false
    @State private var giftResult: Result<GiftSuggestion, AISuggestionError>?
    @State private var isGeneratingMessage = false
    @State private var messageResult: Result<String, AISuggestionError>?

    init(importantDate: ImportantDate?) {
        self.importantDate = importantDate
        _name = State(initialValue: importantDate?.name ?? "")
        _date = State(initialValue: importantDate?.date ?? .now)
        let referenceDate = importantDate?.date ?? .now
        let components = Calendar.current.dateComponents([.month, .day], from: referenceDate)
        _birthdayMonth = State(initialValue: components.month ?? 1)
        _birthdayDay = State(initialValue: components.day ?? 1)
        _type = State(initialValue: importantDate?.type ?? .birthday)
        _relationship = State(initialValue: importantDate?.relationship)
        _notes = State(initialValue: importantDate?.notes ?? "")
        _birthYearText = State(initialValue: importantDate?.birthYear.map(String.init) ?? "")
        _notificationTime = State(initialValue: Self.time(
            hour: importantDate?.notificationHour ?? 9,
            minute: importantDate?.notificationMinute ?? 0
        ))
        let eventHour = importantDate?.eventHour
        let eventMinute = importantDate?.eventMinute
        _hasEventTime = State(initialValue: eventHour != nil && eventMinute != nil)
        _eventTime = State(initialValue: Self.time(hour: eventHour ?? 12, minute: eventMinute ?? 0))
    }

    private var isNameValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Regra de visibilidade do botão "Sugerir presente": exige modelo disponível e `notes`
    /// preenchidas (senão a sugestão fica genérica demais — ver SPEC 3.4). Nunca aparece para
    /// `type == .memorial` — não faz sentido sugerir presente para uma data de falecimento/homenagem.
    static func showsGiftSuggestion(notes: String, type: DateType, isModelAvailable: Bool) -> Bool {
        guard type != .memorial else { return false }
        return isModelAvailable && !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Componentes de hora/minuto extraídos de `time`, prontos para gravar em
    /// `notificationHour`/`notificationMinute`.
    static func timeComponents(from time: Date, calendar: Calendar = .current) -> (hour: Int, minute: Int) {
        let components = calendar.dateComponents([.hour, .minute], from: time)
        return (components.hour ?? 9, components.minute ?? 0)
    }

    /// Monta um `Date` de referência com a hora/minuto informados — usado para inicializar
    /// o `DatePicker` de hora a partir dos valores salvos em `notificationHour`/`notificationMinute`.
    static func time(hour: Int, minute: Int, calendar: Calendar = .current, referenceDate: Date = .now) -> Date {
        calendar.date(bySettingHour: hour, minute: minute, second: 0, of: referenceDate) ?? referenceDate
    }

    /// Compõe a data de um aniversário a partir de mês/dia escolhidos nos `Picker`s, contra o
    /// ano bissexto fixo 2000 (mesma convenção do model — ver `ImportantDate.swift`), para 29/02
    /// ser sempre selecionável independente do ano de nascimento.
    static func birthdayDate(month: Int, day: Int, calendar: Calendar = .current) -> Date {
        calendar.date(from: DateComponents(year: 2000, month: month, day: day)) ?? .now
    }

    /// Dias válidos do mês informado, contra o ano fixo 2000 (bissexto — fevereiro sempre tem 29).
    static func daysInBirthdayMonth(_ month: Int, calendar: Calendar = .current) -> [Int] {
        let reference = calendar.date(from: DateComponents(year: 2000, month: month, day: 1)) ?? .now
        let range = calendar.range(of: .day, in: .month, for: reference) ?? 1..<32
        return Array(range)
    }

    /// Parseia o campo opcional "Ano de nascimento" para `Int?` — `nil` se vazio ou inválido.
    static func parseBirthYear(_ text: String) -> Int? {
        Int(text.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    var body: some View {
        Form {
            Section("Informações") {
                if let ageLabel = ImportantDate.ageLabel(forAge: importantDate?.age()) {
                    Text(ageLabel)
                        .foregroundStyle(.secondary)
                }
                TextField("Nome", text: $name)
                if type == .birthday {
                    HStack {
                        Picker("Mês", selection: $birthdayMonth) {
                            ForEach(Array(Calendar.current.monthSymbols.enumerated()), id: \.offset) { index, symbol in
                                Text(symbol.capitalized).tag(index + 1)
                            }
                        }
                        Picker("Dia", selection: $birthdayDay) {
                            ForEach(Self.daysInBirthdayMonth(birthdayMonth), id: \.self) { day in
                                Text("\(day)").tag(day)
                            }
                        }
                    }
                    .onChange(of: birthdayMonth) {
                        let validDays = Self.daysInBirthdayMonth(birthdayMonth)
                        if !validDays.contains(birthdayDay) {
                            birthdayDay = validDays.last ?? 1
                        }
                    }
                    TextField("Ano de nascimento (opcional)", text: $birthYearText)
                        .keyboardType(.numberPad)
                } else {
                    DatePicker("Data", selection: $date, displayedComponents: .date)
                }
                Picker("Tipo", selection: $type) {
                    ForEach(DateType.allCases, id: \.self) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                DatePicker("Hora do lembrete", selection: $notificationTime, displayedComponents: .hourAndMinute)
                Toggle("Definir hora do evento", isOn: $hasEventTime)
                if hasEventTime {
                    DatePicker("Hora do evento", selection: $eventTime, displayedComponents: .hourAndMinute)
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
                    if Self.showsGiftSuggestion(notes: notes, type: type, isModelAvailable: aiService.isAvailable) {
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
        let finalDate = type == .birthday ? Self.birthdayDate(month: birthdayMonth, day: birthdayDay) : date
        let finalBirthYear = type == .birthday ? Self.parseBirthYear(birthYearText) : nil
        let (hour, minute) = Self.timeComponents(from: notificationTime)
        let (eventHour, eventMinute): (Int?, Int?) = hasEventTime
            ? { let (h, m) = Self.timeComponents(from: eventTime); return (h, m) }()
            : (nil, nil)

        let savedDate: ImportantDate
        if let importantDate {
            importantDate.name = trimmedName
            importantDate.date = finalDate
            importantDate.type = type
            importantDate.relationship = relationship
            importantDate.notes = trimmedNotes.isEmpty ? nil : trimmedNotes
            importantDate.birthYear = finalBirthYear
            importantDate.notificationHour = hour
            importantDate.notificationMinute = minute
            importantDate.eventHour = eventHour
            importantDate.eventMinute = eventMinute
            savedDate = importantDate
        } else {
            let newDate = ImportantDate(
                name: trimmedName,
                date: finalDate,
                type: type,
                relationship: relationship,
                notes: trimmedNotes.isEmpty ? nil : trimmedNotes,
                birthYear: finalBirthYear,
                notificationHour: hour,
                notificationMinute: minute,
                eventHour: eventHour,
                eventMinute: eventMinute
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
            return AISuggestionError.unavailable(reason).errorDescription
                ?? String(localized: "Sugestões de IA indisponíveis neste momento.")
        }
        return String(localized: "Sugestões de IA indisponíveis neste momento.")
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
            Text(error.errorDescription ?? String(localized: "Não foi possível gerar o conteúdo."))
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
