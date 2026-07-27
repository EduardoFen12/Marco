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
///
/// Redesenho T40 (mock Figma "Detalhe da Data (IA)" `24:159`): `ScrollView` + `VStack` de cards
/// (`FormSectionCard`, promovido do form na T37) sobre `MarcoCream`, no mesmo vocabulário visual
/// de T37–T39.
struct ImportantDateDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var aiService = AISuggestionService()

    let importantDate: ImportantDate

    @State private var isSuggestingGift = false
    @State private var giftResult: Result<GiftSuggestion, AISuggestionError>?
    @State private var isGeneratingMessage = false
    @State private var messageResult: Result<String, AISuggestionError>?

    /// "31 de Maio • Faz 24 anos" — data + idade numa única linha (T40), no mesmo padrão que
    /// `ImportantDateRow.subtitle` usa (`ImportantDateListView`), sem a hora do evento (que já
    /// tem sua própria linha no card "Lembretes" abaixo).
    private var dateAgeLine: Text {
        var text = Text(importantDate.dateLabel)
        if let ageLabel = ImportantDate.ageLabel(forAge: importantDate.age()) {
            text = Text("\(text) • \(ageLabel)")
        }
        return text
    }

    private var showsGiftSuggestion: Bool {
        AISuggestionService.showsGiftSuggestion(
            notes: importantDate.notes ?? "",
            type: importantDate.type,
            isModelAvailable: aiService.isAvailable
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                header

                if let notes = importantDate.notes, !notes.isEmpty {
                    FormSectionCard(label: "Anotações", isProminent: true) {
                        // Altura mínima de 3 linhas, crescendo com o texto — mesmo tratamento do
                        // campo de notas no form (`lineLimit(4...8)`).
                        Text(notes)
                            .lineLimit(3...)
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                }

                aiSuggestionsSection

                remindersCard
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .background(Color("MarcoCream").ignoresSafeArea())
        .navigationTitle(importantDate.name)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .fontWeight(.semibold)
                        .foregroundStyle(Color("MarcoLabel"))
                }
                .accessibilityLabel(Text("Voltar"))
            }
            ToolbarItem(placement: .confirmationAction) {
                NavigationLink {
                    ImportantDateFormView(importantDate: importantDate)
                } label: {
                    Image(systemName: "pencil")
                        .fontWeight(.semibold)
                        .foregroundStyle(.marcosGreen)
                }
                .accentColor(.marcosGreen)
                .accessibilityLabel(Text("Editar"))
            }
        }
        // Empurrada a partir da Home (T36, mock Figma): esconde a tab bar, já que esta tela
        // não faz parte da navegação por abas.
        .toolbar(.hidden, for: .tabBar)
    }

    private var header: some View {
        VStack(spacing: 28) {
            CountdownRingView(
                daysRemaining: importantDate.daysUntilNextOccurrence(),
                isPast: importantDate.isPast,
                accessibilityLabel: importantDate.daysRemainingLabel
            )
            VStack(spacing: 8) {
                Text(importantDate.name)
                    .font(.largeTitle.bold())
                    .foregroundStyle(Color("MarcoLabel"))
                Label {
                    Text(importantDate.type.displayName)
                } icon: {
                    Image(systemName: importantDate.type.symbolName)
                }
                .font(.subheadline)
                .foregroundStyle(Color("MarcoLabelSecondary"))
                dateAgeLine
                    .font(.subheadline)
                    .foregroundStyle(Color("MarcoLabelSecondary"))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private static func timeLabel(hour: Int, minute: Int) -> String {
        String(format: "%02d:%02d", hour, minute)
    }

    private var remindersCard: some View {
        FormSectionCard(label: "Lembretes", isProminent: true) {
            VStack(alignment: .leading, spacing: 12) {
                LabeledContent("Hora do lembrete", value: Self.timeLabel(
                    hour: importantDate.notificationHour,
                    minute: importantDate.notificationMinute
                ))
                if let eventHour = importantDate.eventHour, let eventMinute = importantDate.eventMinute {
                    LabeledContent("Hora do evento", value: Self.timeLabel(hour: eventHour, minute: eventMinute))
                }
            }
        }
    }

    // MARK: - Sugestões de IA (reaproveita AISuggestionService, T10/T11/T23)

    /// Diferente das demais seções, esta não é um `FormSectionCard`: no mock `24:159` os dois
    /// botões ficam soltos sobre o fundo e cada resultado gerado é o seu próprio card, em vez de
    /// tudo dentro de um container só.
    private var aiSuggestionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionLabel(text: "Sugestões de IA", systemImage: "sparkles", isProminent: true)
            if aiService.isAvailable {
                aiActionButtons
                if showsGiftSuggestion {
                    aiResultView(for: giftResult, title: "Sugestão de presente") { "\($0.title)\n\n\($0.rationale)" }
                }
                aiResultView(for: messageResult, title: "Mensagem sugerida") { $0 }
            } else {
                Text(unavailableExplanation)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Os dois botões de IA como cards lado a lado, ícone em cima e rótulo em caps embaixo
    /// (T40). Quando "Sugerir presente" está escondido (`.memorial`), "Gerar mensagem" ocupa a
    /// largura toda.
    private var aiActionButtons: some View {
        HStack(spacing: 12) {
            if showsGiftSuggestion {
                AIActionButton(
                    systemImage: "gift",
                    title: "SUGERIR\nPRESENTE",
                    background: Color("MarcosGreen"),
                    foreground: .white,
                    isLoading: isSuggestingGift
                ) {
                    Task { await suggestGift() }
                }
            }
            AIActionButton(
                systemImage: "text.bubble",
                title: "GERAR\nMENSAGEM",
                background: Color("MarcoMint"),
                foreground: Color("MarcoDarkGreen"),
                isLoading: isGeneratingMessage
            ) {
                Task { await generateMessage() }
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
    private func aiResultView<T>(
        for result: Result<T, AISuggestionError>?,
        title: LocalizedStringResource,
        text: (T) -> String
    ) -> some View {
        switch result {
        case .success(let value):
            AIResultView(title: title, text: text(value))
        case .failure(let error):
            Text(error.errorDescription ?? String(localized: "Não foi possível gerar o conteúdo."))
                .font(.footnote)
                .foregroundStyle(.red)
        case .none:
            EmptyView()
        }
    }
}

/// Anel de contagem regressiva com os dias até a próxima ocorrência (T32/T40, mock Figma
/// "Detalhe da Data (IA)" `24:159`) — maior e mais grosso que o original, em `MarcoDarkGreen`.
/// Progresso ilustrativo (preenche conforme a data se aproxima ao longo de um ano) — não é uma
/// medida de precisão, só uma pista visual.
private struct CountdownRingView: View {
    let daysRemaining: Int
    /// Evento único vencido (T43, `ImportantDate.isPast`) — caminho raro (a data já teria saído
    /// da Home/busca antes de chegar aqui), mas o anel não deve renderizar número negativo: mostra
    /// "Passou" no lugar do número + "DIAS".
    let isPast: Bool
    /// Rótulo anunciado pelo VoiceOver ("Faltam 21 dias"/"Hoje"/"Amanhã"/"Passou") — o texto visual
    /// do anel mostra só o número + "DIAS" (T40 fix, mesmo padrão de `ImportantDateRow`), então o
    /// anel precisa desse rótulo à parte para não soar "21, DIAS" solto.
    let accessibilityLabel: LocalizedStringResource

    private var progress: Double {
        let clamped = min(max(daysRemaining, 0), 365)
        return 1 - Double(clamped) / 365
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color("MarcoGray").opacity(0.4), lineWidth: 18)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color("MarcoDarkGreen"), style: StrokeStyle(lineWidth: 18, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 4) {
                if isPast {
                    Text("Passou")
                        .font(.title2.bold())
                        .foregroundStyle(Color("MarcoDarkGreen"))
                } else {
                    Text(daysRemaining, format: .number)
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(Color("MarcoDarkGreen"))
                    Text("DIAS")
                        .font(.caption.bold())
                        .tracking(1)
                        .foregroundStyle(Color("MarcoDarkGreen"))
                }
            }
        }
        .frame(width: 200, height: 200)
        .animation(.default, value: progress)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(accessibilityLabel))
    }
}

/// Card de ação de IA (T40): ícone em cima, rótulo em caps embaixo (quebrado em duas linhas pelo
/// `\n` do próprio título, como no mock `24:159`), largura flexível para os dois botões (ou só um,
/// quando "Sugerir presente" está escondido) dividirem o espaço disponível.
private struct AIActionButton: View {
    let systemImage: String
    let title: LocalizedStringResource
    let background: Color
    let foreground: Color
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .tint(foreground)
                } else {
                    Image(systemName: systemImage)
                        .font(.title2)
                }
                Text(title)
                    .font(.caption.bold())
                    .tracking(0.5)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .background(background)
            .foregroundStyle(foreground)
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
    }
}

/// Exibe o texto gerado pela IA com opção de copiar para a área de transferência — mesmo
/// comportamento do form (T11). Card `MarcoCardFill` com ícone de lâmpada em círculo à esquerda
/// do título e botão de copiar (só ícone) no canto superior direito (T40, mock `24:159`) —
/// **sem imagem de produto** (decisão da seção 3.9, deliberadamente ignorada aqui).
private struct AIResultView: View {
    let title: LocalizedStringResource
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                ZStack {
                    Circle().fill(Color("MarcoMint"))
                    Image(systemName: "lightbulb.fill")
                        .foregroundStyle(Color("MarcoDarkGreen"))
                }
                .frame(width: 36, height: 36)

                Text(title)
                    .font(.headline)
                    .foregroundStyle(Color("MarcoLabel"))

                Spacer()

                Button {
                    UIPasteboard.general.string = text
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color("MarcoLabelSecondary"))
                .accessibilityLabel(Text("Copiar"))
            }
            Text(text)
                .font(.callout)
                .foregroundStyle(Color("MarcoLabel"))
        }
        .padding(16)
        .background(Color("MarcoCardFill"))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
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
