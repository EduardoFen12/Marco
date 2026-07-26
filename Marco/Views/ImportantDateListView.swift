//
//  ImportantDateListView.swift
//  Marco
//

import SwiftUI
import SwiftData
import UIKit

struct ImportantDateListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(NotificationNavigationCoordinator.self) private var notificationCoordinator
    @Query private var importantDates: [ImportantDate]
    @State private var isPresentingNewDate = false
    @State private var isPresentingImport = false
    @State private var path = NavigationPath()

    /// Lista abaixo do card de destaque (T33, mock Figma): exclui a data em destaque, que já
    /// aparece no card — quando nenhuma data está destacada, `featuredDate` é `nil` e nada é
    /// filtrado. `ForEach`/`onDelete` abaixo iteram sobre esta mesma coleção, então os índices
    /// do `IndexSet` batem certinho com o item exibido.
    ///
    /// A ordenação precisa ser total e determinística: `sorted(by:)` não é estável, então em
    /// caso de empate em `daysUntilNextOccurrence()` (ex.: duas datas "hoje") duas avaliações
    /// da mesma `sortedDates` podiam produzir permutações diferentes — o `ForEach` renderiza uma
    /// ordem e `delete(at:)` reavalia `sortedDates` e indexa outra, apagando o item errado.
    /// Desempatando por `name` e, por fim, por `id` (único e estável), a ordem passa a ser
    /// sempre a mesma para os mesmos dados, então `ForEach` e `delete(at:)` sempre concordam.
    private var sortedDates: [ImportantDate] {
        importantDates
            .filter { $0.id != featuredDate?.id }
            .sorted {
                if $0.daysUntilNextOccurrence() != $1.daysUntilNextOccurrence() {
                    return $0.daysUntilNextOccurrence() < $1.daysUntilNextOccurrence()
                }
                if $0.name != $1.name {
                    return $0.name < $1.name
                }
                return $0.id.uuidString < $1.id.uuidString
            }
    }

    /// Data em destaque (T30) mostrada no card do topo; `nil` quando nenhuma data está marcada
    /// (ex: recém-excluída) — nesse caso o card simplesmente não aparece.
    private var featuredDate: ImportantDate? {
        importantDates.first(where: \.isFeatured)
    }

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if importantDates.isEmpty {
                    EmptyDatesView(
                        onAddDate: { isPresentingNewDate = true },
                        onImport: { isPresentingImport = true }
                    )
                } else {
                    List {
                        if let featuredDate {
                            Button {
                                path.append(featuredDate.id)
                            } label: {
                                FeaturedDateCard(importantDate: featuredDate)
                            }
                            .buttonStyle(.plain)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .contextMenu {
                                Button(role: .destructive) {
                                    delete(featuredDate)
                                } label: {
                                    Label("Excluir", systemImage: "trash")
                                }
                            }
                        }

                        ForEach(sortedDates) { importantDate in
                            Button {
                                path.append(importantDate.id)
                            } label: {
                                ImportantDateRow(importantDate: importantDate)
                            }
                            .buttonStyle(.plain)
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .contextMenu {
                                markAsFeaturedButton(for: importantDate)
                            }
                        }
                        .onDelete(perform: delete)
                    }
                    .scrollContentBackground(.hidden)
                    .background(Color("MarcoCream"))
                }
            }
            .navigationDestination(for: UUID.self) { id in
                if let importantDate = importantDates.first(where: { $0.id == id }) {
                    ImportantDateDetailView(importantDate: importantDate)
                }
            }
            .navigationTitle("Marco")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            isPresentingNewDate = true
                        } label: {
                            Label("Adicionar data", systemImage: "plus")
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

    /// Ação de long press (T33): marca `importantDate` como destaque, desmarcando a anterior —
    /// reusa o ponto único de escrita da exclusividade (`ImportantDate.markAsFeatured(in:)`, T30).
    @ViewBuilder
    private func markAsFeaturedButton(for importantDate: ImportantDate) -> some View {
        Button {
            importantDate.markAsFeatured(in: modelContext)
        } label: {
            Label("Marcar como destaque", systemImage: "star.fill")
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            delete(sortedDates[index])
        }
    }

    /// Ponto único de exclusão (T33): usado pelo swipe da lista (`delete(at:)`) e pela ação
    /// "Excluir" do `contextMenu` do card de destaque, que não tinha nenhuma affordance de
    /// exclusão desde que passou a ficar fora de `sortedDates`.
    private func delete(_ importantDate: ImportantDate) {
        // Deleta primeiro: `cancel` dispara `syncWatch`, que refaz o fetch de todas as
        // `ImportantDate` pro widget/Watch — precisa que o item já esteja fora do contexto
        // nesse fetch, senão widget/Watch mostram a data recém-excluída até o próximo CRUD.
        modelContext.delete(importantDate)
        NotificationService.cancel(importantDate)
        // Se a data excluída era a destacada, nenhuma outra assume o lugar automaticamente
        // (comportamento explícito de T30/T33) — `featuredDate` volta a ser `nil` sozinho, já
        // que ele é derivado de `importantDates` via `@Query`.
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

/// Empty state dedicado (T34, mock Figma "Empty State"): substitui a `List` inteira quando não
/// há nenhuma `ImportantDate` — a toolbar Compact/Large + `Menu` do `+` (T33) permanece intacta,
/// só o conteúdo abaixo dela muda. Os dois botões reaproveitam exatamente os mesmos closures que
/// o `Menu` já dispara (nenhum caminho novo de apresentação).
private struct EmptyDatesView: View {
    let onAddDate: () -> Void
    let onImport: () -> Void

    var body: some View {
        ContentUnavailableView {
            EmptyDatesIllustration()
        } description: {
            VStack(spacing: 8) {
                Text("Nenhuma data cadastrada")
                    .font(.title2.bold())
                    .foregroundStyle(Color("MarcoLabel"))
                Text("Toque em + para adicionar uma data importante")
                    .font(.subheadline)
                    .foregroundStyle(Color("MarcoLabelSecondary"))
                    .multilineTextAlignment(.center)
            }
        } actions: {
            VStack(spacing: 12) {
                Button("Adicionar Marco", action: onAddDate)
                    .buttonStyle(.borderedProminent)
                    .tint(Color("MarcosGreen"))

                Button("Importar…", action: onImport)
                    .buttonStyle(.bordered)
                    .tint(Color("MarcoDeepGreen"))
            }
            .controlSize(.large)
        }
    }
}

/// Ilustração custom do empty state (T34): calendário + sino + coração compostos com SF Symbols
/// sobre os color sets do design system (T29) — sem asset de imagem novo.
private struct EmptyDatesIllustration: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color("MarcoMint").opacity(0.35))
                .frame(width: 148, height: 148)

            Image(systemName: "calendar")
                .font(.system(size: 64))
                .foregroundStyle(Color("MarcoDeepGreen"))

            badge(systemImage: "bell.fill", tint: Color("MarcoDarkGreen"))
                .offset(x: 46, y: -50)

            badge(systemImage: "heart.fill", tint: Color("MarcosGreen"))
                .offset(x: -50, y: 46)
        }
        .frame(width: 148, height: 148)
        .padding(.bottom, 8)
    }

    private func badge(systemImage: String, tint: Color) -> some View {
        Image(systemName: systemImage)
            .font(.system(size: 20))
            .foregroundStyle(tint)
            .padding(10)
            .background(Circle().fill(Color("MarcoCream")))
            .overlay(Circle().stroke(Color("MarcoBeige"), lineWidth: 1))
    }
}

/// Card de destaque no topo da Home (T33, mock Figma "Minhas Datas (Home)"): foto de fundo
/// (ou um preenchimento + ícone do tipo, quando `photoData` está vazio) com pill "DESTAQUE",
/// nome/tipo/data e dias restantes sobrepostos.
private struct FeaturedDateCard: View {
    let importantDate: ImportantDate

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            background
            LinearGradient(
                colors: [Color.black.opacity(0.65), Color.black.opacity(0)],
                startPoint: .bottom,
                endPoint: .top
            )
            info
        }
        .overlay(alignment: .topLeading) { pill }
        .frame(height: 220)
        .clipShape(RoundedRectangle(cornerRadius: 32))
    }

    @ViewBuilder
    private var background: some View {
        if let photoData = importantDate.photoData, let uiImage = UIImage(data: photoData) {
            Color.clear
                .overlay {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                }
                .clipped()
        } else {
            ZStack {
                Color("MarcoDarkGreen")
                Image(systemName: importantDate.type.symbolName)
                    .font(.system(size: 96))
                    .foregroundStyle(Color("MarcoMint").opacity(0.35))
            }
        }
    }

    private var pill: some View {
        Text("DESTAQUE")
            .font(.caption.bold())
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Capsule().fill(Color("MarcoMint")))
            .foregroundStyle(Color("MarcoDeepGreen"))
            .padding(16)
    }

    private var info: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(importantDate.name)
                .font(.title.bold())
                .foregroundStyle(.white)
            (Text(importantDate.type.displayName) + Text(" · ") + Text(importantDate.dateLabel))
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.85))
            Text(importantDate.daysRemainingLabel)
                .font(.subheadline.bold())
                .foregroundStyle(Color("MarcoMint"))
        }
        .padding(20)
    }
}

/// Card flutuante de cada data na lista (T39, mock Figma "Minhas Datas (Home)" `13:5`): tipo em
/// cima (discreto), nome em destaque, subtítulo com a data (+ idade/hora do evento quando houver)
/// e o número de dias grande à direita, colorido pela mesma cor da stripe de categoria. Não-
/// `private` para ser reaproveitada também por `SearchDatesView` (T27).
struct ImportantDateRow: View {
    let importantDate: ImportantDate

    /// "15 de Junho" / "02 de Julho • 10 anos" / "15 de Junho • às 19:00" (T26) — a idade e a hora
    /// do evento entram como sufixos opcionais quando existem, sem inventar um texto relativo tipo
    /// "Próximo sábado" (o mock `13:5` mostra esse formato num card, mas o modelo hoje só guarda
    /// dia/mês + hora do evento, não "dia da semana relativo"; ver nota no report da T39).
    private var subtitle: Text {
        var text = Text(importantDate.dateLabel)
        if let ageLabel = ImportantDate.ageLabel(forAge: importantDate.age()) {
            text = text + Text(" • ") + Text(ageLabel)
        }
        if let eventTimeLabel = importantDate.eventTimeLabel {
            text = text + Text(" • ") + Text(eventTimeLabel)
        }
        return text
    }

    var body: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(importantDate.type.stripeColor)
                .frame(width: 5)

            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(importantDate.type.displayName)
                        .font(.caption)
                        .foregroundStyle(Color("MarcoLabelSecondary"))
                    Text(importantDate.name)
                        .font(.title3.bold())
                        .foregroundStyle(Color("MarcoLabel"))
                    subtitle
                        .font(.subheadline)
                        .foregroundStyle(Color("MarcoLabelSecondary"))
                }

                Spacer(minLength: 12)

                VStack(spacing: 0) {
                    Text(importantDate.daysUntilNextOccurrence(), format: .number)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(importantDate.type.stripeColor)
                    Text("DIAS")
                        .font(.caption2.bold())
                        .tracking(1)
                        .foregroundStyle(Color("MarcoLabelSecondary"))
                }
            }
            .padding(16)
        }
        .background(Color("MarcoCardFill"))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
    }
}

// MARK: - Rótulos em pt-BR

extension ImportantDate {
    /// Texto amigável de "quanto falta" até a próxima ocorrência. Tipado como
    /// `LocalizedStringResource` (não `String`) para que cada caso vire sua própria chave de
    /// localização — ver mesmo padrão/justificativa em `ImportantDateEntity.subtitleText`.
    var daysRemainingLabel: LocalizedStringResource {
        switch daysUntilNextOccurrence() {
        case 0: return "Hoje"
        case 1: return "Amanhã"
        case let days: return "Faltam \(days) dias"
        }
    }

    /// Texto "faz N anos" a partir de uma idade já calculada (ver `age(on:calendar:)`);
    /// `nil` quando não há idade (sem `birthYear`), caso em que nada deve ser exibido.
    static func ageLabel(forAge age: Int?) -> LocalizedStringResource? {
        guard let age else { return nil }
        return "Faz \(age) anos"
    }

    /// Texto "às HH:mm" a partir de `eventHour`/`eventMinute`; `nil` quando o evento não tem
    /// hora definida (comportamento atual preservado, ver T26).
    var eventTimeLabel: LocalizedStringResource? {
        guard let eventHour, let eventMinute else { return nil }
        let formattedTime = String(format: "%02d:%02d", eventHour, eventMinute)
        return "às \(formattedTime)"
    }
}

extension DateType {
    var displayName: LocalizedStringResource {
        switch self {
        case .birthday: return "Aniversário"
        case .commemorative: return "Comemorativa"
        case .memorial: return "Memorial"
        case .appointment: return "Compromisso"
        }
    }
}

extension Relationship {
    var displayName: LocalizedStringResource {
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
