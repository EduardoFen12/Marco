//
//  AISuggestionService.swift
//  Marco
//

import Foundation
import FoundationModels

/// Sugestão de presente estruturada, gerada pelo modelo a partir de `notes` + `relationship`.
@Generable
struct GiftSuggestion: Equatable {
    @Guide(description: "Título curto da sugestão de presente")
    var title: String

    @Guide(description: "Justificativa baseada nas notas e no relacionamento")
    var rationale: String
}

/// Erro de domínio devolvido pelo `AISuggestionService` — nunca deixa `GenerationError`
/// nem a indisponibilidade do modelo escaparem como exceção não tratada.
enum AISuggestionError: Error, LocalizedError, Equatable {
    case unavailable(SystemLanguageModel.Availability.UnavailableReason)
    case generationFailed(String)

    var errorDescription: String? {
        switch self {
        case .unavailable(.deviceNotEligible):
            return "Este aparelho não é compatível com os recursos de IA do Marco."
        case .unavailable(.appleIntelligenceNotEnabled):
            return "Ative a Apple Intelligence nos Ajustes para usar as sugestões de IA."
        case .unavailable(.modelNotReady):
            return "O modelo de IA ainda está sendo preparado. Tente novamente em instantes."
        case .unavailable:
            return "Sugestões de IA indisponíveis neste momento."
        case .generationFailed(let motivo):
            return "Não foi possível gerar a sugestão (\(motivo))."
        }
    }
}

// Necessário porque `SystemLanguageModel.Availability.UnavailableReason` não conforma a `Equatable`
// de forma pública utilizável em todos os casos de comparação de teste — reduz ao rawValue de nome.
extension AISuggestionError {
    static func == (lhs: AISuggestionError, rhs: AISuggestionError) -> Bool {
        switch (lhs, rhs) {
        case (.unavailable(let a), .unavailable(let b)):
            return a == b
        case (.generationFailed(let a), .generationFailed(let b)):
            return a == b
        default:
            return false
        }
    }
}

/// Gera sugestões de presente e mensagens personalizadas on-device via Foundation Models.
/// Uma única `LanguageModelSession` é reaproveitada entre chamadas; como `instructions` da
/// sessão é fixado no `init`, a variação por `type`/`relationship` acontece no `prompt` de
/// cada `respond` (mesma sessão, instrução embutida no prompt de cada operação).
@MainActor
final class AISuggestionService {
    private let model: SystemLanguageModel
    private lazy var session = LanguageModelSession(model: model)

    init(model: SystemLanguageModel = .default) {
        self.model = model
    }

    /// Disponibilidade do modelo — exposta para a UI (T11) decidir se esconde/desabilita botões.
    var availability: SystemLanguageModel.Availability { model.availability }
    var isAvailable: Bool { model.isAvailable }

    /// Sugestão de presente. Só faz sentido chamar com `notes` preenchido (a UI, na T11,
    /// só oferece o botão quando `notes` não é vazio) — aqui apenas montamos o prompt com o texto dado.
    func suggestGift(notes: String, relationship: Relationship?) async -> Result<GiftSuggestion, AISuggestionError> {
        if case .unavailable(let reason) = availability {
            return .failure(.unavailable(reason))
        }
        do {
            let response = try await session.respond(
                to: Self.giftPrompt(notes: notes, relationship: relationship),
                generating: GiftSuggestion.self
            )
            return .success(response.content)
        } catch {
            return .failure(Self.domainError(from: error))
        }
    }

    /// Mensagem curta personalizada. Tom carinhoso/engraçado/formal (conforme `relationship`)
    /// para datas normais; tom reflexivo para `type == .memorial`.
    func personalizedMessage(
        name: String,
        type: DateType,
        relationship: Relationship?,
        notes: String? = nil
    ) async -> Result<String, AISuggestionError> {
        if case .unavailable(let reason) = availability {
            return .failure(.unavailable(reason))
        }
        do {
            let response = try await session.respond(
                to: Self.messagePrompt(name: name, type: type, relationship: relationship, notes: notes)
            )
            return .success(response.content)
        } catch {
            return .failure(Self.domainError(from: error))
        }
    }

    // MARK: - Prompts
    // `nonisolated` porque são funções puras (sem tocar a sessão) — permite chamar/testar
    // sem precisar estar na main actor, inclusive de contexto síncrono nos testes.

    /// Prompt puro (sem I/O) — testável sem rodar o modelo de fato.
    nonisolated static func giftPrompt(notes: String, relationship: Relationship?) -> String {
        """
        Sugira um presente para alguém com quem tenho a seguinte relação: \(relationshipLabel(relationship)).
        Contexto sobre a pessoa (gostos, interesses): \(notes)
        Responda em português, com um título curto e uma justificativa baseada nesse contexto.
        """
    }

    /// Instrução varia por `type`: reflexiva para `.memorial`, tom leve conforme `relationship`
    /// para os demais tipos. Prompt puro — testável sem rodar o modelo de fato.
    nonisolated static func messagePrompt(name: String, type: DateType, relationship: Relationship?, notes: String?) -> String {
        let contexto = notes.map { "Contexto adicional: \($0)." } ?? ""
        switch type {
        case .memorial:
            return """
            Escreva uma mensagem curta, em português, de tom reflexivo e respeitoso em memória de \(name).
            Relação com essa pessoa: \(relationshipLabel(relationship)). \(contexto)
            Evite clichês, foque em acolhimento.
            """
        case .birthday, .commemorative:
            return """
            Escreva uma mensagem curta, em português, para \(name) na ocasião: \(type == .birthday ? "aniversário" : "data comemorativa").
            Relação com essa pessoa: \(relationshipLabel(relationship)). Use tom \(tone(for: relationship)). \(contexto)
            """
        }
    }

    private nonisolated static func relationshipLabel(_ relationship: Relationship?) -> String {
        switch relationship {
        case .partner: return "parceiro(a)"
        case .family: return "familiar"
        case .friend: return "amigo(a)"
        case .colleague: return "colega"
        case .other, .none: return "conhecido(a)"
        }
    }

    /// Tom da mensagem conforme o relacionamento: carinhoso, engraçado ou formal.
    private nonisolated static func tone(for relationship: Relationship?) -> String {
        switch relationship {
        case .partner, .family: return "carinhoso"
        case .friend: return "engraçado e descontraído"
        case .colleague, .other, .none: return "formal"
        }
    }

    /// Converte qualquer erro de geração num `AISuggestionError` de domínio — nenhum caso
    /// de `GenerationError` escapa sem tratamento.
    private static func domainError(from error: Error) -> AISuggestionError {
        guard let generationError = error as? LanguageModelSession.GenerationError else {
            return .generationFailed(error.localizedDescription)
        }
        switch generationError {
        case .exceededContextWindowSize:
            return .generationFailed("contexto muito longo")
        case .assetsUnavailable:
            return .generationFailed("recursos do modelo indisponíveis")
        case .guardrailViolation:
            return .generationFailed("conteúdo bloqueado por segurança")
        case .unsupportedGuide:
            return .generationFailed("formato de resposta não suportado")
        case .unsupportedLanguageOrLocale:
            return .generationFailed("idioma não suportado")
        case .decodingFailure:
            return .generationFailed("falha ao interpretar a resposta")
        case .rateLimited:
            return .generationFailed("muitas solicitações, tente novamente")
        case .concurrentRequests:
            return .generationFailed("já existe uma geração em andamento")
        case .refusal:
            return .generationFailed("o modelo recusou a solicitação")
        @unknown default:
            return .generationFailed("erro desconhecido")
        }
    }
}
