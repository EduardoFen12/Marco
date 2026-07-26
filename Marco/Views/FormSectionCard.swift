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
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(label)
            }
            .font(.caption.bold())
            .foregroundStyle(Color("MarcoLabelSecondary"))
            content
                .padding(16)
                .background(Color("MarcoCardFill"))
                .clipShape(RoundedRectangle(cornerRadius: 20))
        }
    }
}
