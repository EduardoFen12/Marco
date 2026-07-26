//
//  FormSectionCard.swift
//  Marco
//

import SwiftUI

/// Card de seção com label estática acima do card (T37, conferido contra o mock Figma `24:61`):
/// título pequeno e discreto em *sentence case*, fora do container com fundo/clip. Não é floating
/// label animado estilo Material.
///
/// Promovido de `ImportantDateFormView` (T40, mock `24:159`) para ser reaproveitado também por
/// `ImportantDateDetailView` — usado por todas as seções do form ("Identificação", "Quando",
/// "Lembretes", "Categoria", "Relacionamento", "Anotações") e pelas seções do Detalhe
/// ("Anotações", "Sugestões de IA", "Lembretes").
struct FormSectionCard<Content: View>: View {
    let label: LocalizedStringResource
    /// Ícone opcional à esquerda do label (T40): só "Sugestões de IA" usa `sparkles`; o form e as
    /// demais seções do Detalhe preservam o visual sem ícone (default `nil`).
    var systemImage: String? = nil
    var isProminent: Bool = false
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: label, systemImage: systemImage, isProminent: isProminent)
            content
                // Card ocupa a largura toda mesmo com conteúdo curto (ex: uma anotação de duas
                // palavras no Detalhe), em vez de encolher e centralizar em volta do texto.
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(Color("MarcoCardFill"))
                .clipShape(RoundedRectangle(cornerRadius: 20))
        }
    }
}

/// Label de seção, à parte do card porque o Detalhe tem uma seção sem card (os botões de IA ficam
/// soltos sobre o fundo, mock `24:159`) e precisa do mesmo cabeçalho. Dois tamanhos: discreto no
/// form (`caption` secundário, mock `24:61`) e prominente no Detalhe (`title3` na cor do texto).
struct SectionLabel: View {
    let text: LocalizedStringResource
    var systemImage: String? = nil
    var isProminent: Bool = false

    var body: some View {
        HStack(spacing: 6) {
            if let systemImage {
                Image(systemName: systemImage)
            }
            Text(text)
        }
        .font(isProminent ? .title3.bold() : .caption.bold())
        .foregroundStyle(Color(isProminent ? "MarcoLabel" : "MarcoLabelSecondary"))
    }
}
