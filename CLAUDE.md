# Marco

App iOS de datas importantes (aniversários, comemorativas, memoriais) com notificações em camadas, App Intents/Siri e sugestões de IA on-device via Foundation Models. Projeto de aprendizado de App Intents, Shortcuts e Foundation Models framework.

**`SPEC.md` é a fonte da verdade** — requisitos, modelo de dados, decisões técnicas e a lista de tasks (seção 6). Leia-a antes de qualquer trabalho.

## Plataforma e stack

- iOS 26+ (mínimo para Foundation Models e App Intents atuais)
- SwiftUI + SwiftData + UserNotifications + AppIntents + FoundationModels
- Testes: Swift Testing no target `MarcoTests` (unitários). Testes de UI (`MarcoUITests`) estão **fora de escopo** — verificação de fluxos de UI fica a cargo do `sim-verifier`.
- Strings de UI em pt-BR

## Build e testes

```sh
xcodebuild -project Marco.xcodeproj -scheme Marco -destination 'platform=iOS Simulator,name=iPhone 17' build
xcodebuild -project Marco.xcodeproj -scheme Marco -destination 'platform=iOS Simulator,name=iPhone 17' test -only-testing:MarcoTests
```

Se o simulador não existir, escolha um disponível via `xcrun simctl list devices available`.

## Estrutura

- `Marco/Models/` — `ImportantDate` (@Model) e enums (`DateType`, `Relationship`)
- `Marco/Views/` — telas SwiftUI
- `Marco/Services/` — `NotificationService`, `AISuggestionService`
- `Marco/Intents/` — App Intents, `AppEntity`, `AppShortcutsProvider`
- `docs/` — documentação de apoio ao projeto

## Fluxo de trabalho (SDD)

- O agente principal **apenas orquestra** — nunca edita código do app diretamente. Cada task da SPEC.md é delegada aos sub-agentes de `.claude/agents/` no pipeline: `api-scout` (verificar APIs no SDK, quando aplicável) → `swift-implementer` (implementar) → `spec-reviewer` (veredicto contra os critérios de aceite) → `sim-verifier` (evidência em runtime, quando o critério exigir).
- Tasks executam **uma por vez**, na ordem de dependência da seção 6 da SPEC.md.
- Os checkboxes da SPEC.md são marcados **somente pelo orquestrador**, após revisão aprovada.
- Todos os sub-agentes usam `model: sonnet`.
- Descobertas que contradigam a spec (API inexistente, decisão forçada) devem ser registradas na SPEC.md (seção 7 ou nota na task), não contornadas em silêncio.

## Commits

- Mensagens de commit **sem trailer de coautoria** — nunca incluir `Co-Authored-By` nem qualquer assinatura/comentário de IA. Apenas a mensagem descritiva.
