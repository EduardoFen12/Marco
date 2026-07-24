//
//  ImportantDateDetailView.swift
//  Marco
//

import SwiftUI
import SwiftData
import UIKit
import FoundationModels

/// Tela de detalhe read-only de uma `ImportantDate` (T32) — destino padrão ao tocar numa data
/// (lista, destaque, busca). Edição só acontece via botão `pencil` da toolbar, que empurra
/// `ImportantDateFormView`. As sugestões de IA (T11/T23) são reaproveitadas aqui a partir do
/// mesmo `AISuggestionService`, sem duplicar a lógica de disponibilidade/erro do serviço.
struct ImportantDateDetailView: View {
    @State private var aiService = AISuggestionService()

    let importantDate: ImportantDate

    @State private var isSuggestingGift = false
    @State private var giftResult: Result<GiftSuggestion, AISuggestionError>?
    @State private var isGeneratingMessage = false
    @State private var messageResult: Result<String, AISuggestionError>?

    private var dateLabel: String {
        importantDate.date.formatted(.dateTime.day().month(.wide))
    }

    var body: some View {
        List {
            Section {
                header
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)

            if let notes = importantDate.notes, !notes.isEmpty {
                Section("Anotações") {
                    Text(notes)
                }
            }

            aiSuggestionsSection

            Section("Lembretes") {
                LabeledContent("Hora do lembrete", value: Self.timeLabel(
                    hour: importantDate.notificationHour,
                    minute: importantDate.notificationMinute
                ))
                if let eventHour = importantDate.eventHour, let eventMinute = importantDate.eventMinute {
                    LabeledContent("Hora do evento", value: Self.timeLabel(hour: eventHour, minute: eventMinute))
                }
            }
        }
        .navigationTitle(importantDate.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                NavigationLink {
                    ImportantDateFormView(importantDate: importantDate)
                } label: {
                    Label("Editar", systemImage: "pencil")
                }
            }
        }
        // Empurrada a partir da Home (T36, mock Figma): esconde a tab bar, já que esta tela
        // não faz parte da navegação por abas.
        .toolbar(.hidden, for: .tabBar)
    }

    private var header: some View {
        VStack(spacing: 16) {
            CountdownRingView(
                daysRemaining: importantDate.daysUntilNextOccurrence(),
                daysLabel: importantDate.daysRemainingLabel
            )
            VStack(spacing: 4) {
                Text(importantDate.name)
                    .font(.title2.bold())
                Text(importantDate.type.displayName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(dateLabel)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let ageLabel = ImportantDate.ageLabel(forAge: importantDate.age()) {
                    Text(ageLabel)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private static func timeLabel(hour: Int, minute: Int) -> String {
        String(format: "%02d:%02d", hour, minute)
    }

    // MARK: - Sugestões de IA (reaproveita AISuggestionService, T10/T11/T23)

    @ViewBuilder
    private var aiSuggestionsSection: some View {
        Section("Sugestões de IA") {
            if aiService.isAvailable {
                if AISuggestionService.showsGiftSuggestion(
                    notes: importantDate.notes ?? "",
                    type: importantDate.type,
                    isModelAvailable: aiService.isAvailable
                ) {
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

    private var unavailableExplanation: String {
        if case .unavailable(let reason) = aiService.availability {
            return AISuggestionError.unavailable(reason).errorDescription
                ?? String(localized: "Sugestões de IA indisponíveis neste momento.")
        }
        return String(localized: "Sugestões de IA indisponíveis neste momento.")
    }

    private func suggestGift() async {
        isSuggestingGift = true
        giftResult = await aiService.suggestGift(notes: importantDate.notes ?? "", relationship: importantDate.relationship)
        isSuggestingGift = false
    }

    private func generateMessage() async {
        isGeneratingMessage = true
        messageResult = await aiService.personalizedMessage(
            name: importantDate.name,
            type: importantDate.type,
            relationship: importantDate.relationship,
            notes: importantDate.notes
        )
        isGeneratingMessage = false
    }

    @ViewBuilder
    private func aiResultView<T>(for result: Result<T, AISuggestionError>?, text: (T) -> String) -> some View {
        switch result {
        case .success(let value):
            AIResultView(text: text(value))
        case .failure(let error):
            Text(error.errorDescription ?? String(localized: "Não foi possível gerar o conteúdo."))
                .font(.footnote)
                .foregroundStyle(.red)
        case .none:
            EmptyView()
        }
    }
}

/// Anel de contagem regressiva com os dias até a próxima ocorrência (T32/mock Figma
/// "Detalhe da Data (IA)"). Progresso ilustrativo (preenche conforme a data se aproxima ao
/// longo de um ano) — não é uma medida de precisão, só uma pista visual.
private struct CountdownRingView: View {
    let daysRemaining: Int
    let daysLabel: LocalizedStringResource

    private var progress: Double {
        let clamped = min(max(daysRemaining, 0), 365)
        return 1 - Double(clamped) / 365
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color("MarcoGray").opacity(0.4), lineWidth: 10)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color("MarcoDarkGreen"), style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 4) {
                Text("\(daysRemaining)")
                    .font(.system(.largeTitle, design: .rounded).bold())
                Text(daysLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 140, height: 140)
        .animation(.default, value: progress)
    }
}

/// Exibe o texto gerado pela IA com opção de copiar para a área de transferência — mesmo
/// comportamento do form (T11), reaproveitado aqui porque o componente lá é `private`.
private struct AIResultView: View {
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

#Preview {
    NavigationStack {
        ImportantDateDetailView(importantDate: ImportantDate(
            name: "Mari",
            date: .now,
            type: .birthday,
            relationship: .partner,
            notes: "Gosta de plantas",
            birthYear: 1990
        ))
    }
    .modelContainer(for: ImportantDate.self, inMemory: true)
}
