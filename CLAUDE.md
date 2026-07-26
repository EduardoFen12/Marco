# Marco

App iOS de datas importantes (aniversários, comemorativas, memoriais) com notificações em camadas, App Intents/Siri e sugestões de IA on-device via Foundation Models. Projeto de aprendizado de App Intents, Shortcuts e Foundation Models framework.

**`SPEC.md` é a fonte da verdade** — requisitos, modelo de dados, decisões técnicas e a lista de tasks (seção 6). Leia-a antes de qualquer trabalho.

## Plataforma e stack

- iOS 26+ (mínimo para Foundation Models e App Intents atuais)
- SwiftUI + SwiftData + UserNotifications + AppIntents + FoundationModels + PhotosUI (foto por data, Fase 3)
- Testes: **fora de escopo.** Não escrever testes unitários (`MarcoTests`) nem testes de UI (`MarcoUITests`) — nenhum dos dois faz parte do fluxo. A verificação de uma task é: compilar sem erro + evidência em runtime do `sim-verifier` quando o critério de aceite exigir comportamento observável.
- Dynamic Type em tamanhos de acessibilidade (`accessibility-medium` … `accessibility-extra-extra-extra-large`): **fora de escopo.** Não implementar ajustes de layout para essas categorias nem verificá-las (`simctl ui … content_size`). Os tamanhos padrão de Dynamic Type seguem funcionando por herança dos estilos nativos de fonte. Nenhum critério de aceite deve exigir suporte a fontes de acessibilidade. Ver a decisão registrada na seção 7 da SPEC.md.
- Strings de UI em pt-BR

## Build

```sh
xcodebuild -project Marco.xcodeproj -scheme Marco -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Se o simulador não existir, escolha um disponível via `xcrun simctl list devices available`.

## Estrutura

- `Shared/` — `ImportantDate` (@Model), enums (`DateType`, `Relationship`) e `Persistence` (App Group, T19/T20). Grupo sincronizado com os targets `Marco` **e** `MarcoWidgets`. É onde vive o que app e widget compartilham: `DateType.symbolName`/`.stripeColor` e `ImportantDate.dateLabel` moram aqui (T42), não nas Views.
- `Marco/Views/` — telas SwiftUI
- `Marco/Services/` — `NotificationService`, `AISuggestionService`
- `Marco/Intents/` — App Intents, `AppEntity`, `AppShortcutsProvider`
- `DesignSystem/Assets.xcassets` — color sets da paleta do redesign (T29). Grupo sincronizado dos **quatro** alvos (T42), único lugar da paleta no repo. `Marco/Assets.xcassets` guarda só `AppIcon`/`AccentColor`; `MarcoWatch/Assets.xcassets`, só `AppIcon`. ⚠️ **Os slots de aparência estão invertidos de propósito** — o slot sem tag ("Any") é o tom **escuro**, porque o watchOS descarta a entrada tagueada `luminosity` no build (ver achado da T41 na seção 7 da SPEC.md). Cor nova criada no editor do Xcode do jeito padrão sai errada no Watch.
- `MarcoWidgets/` — widget iOS (T20); `MarcoWatch/` + `MarcoWatchWidgets/` — app do Watch e complications (T21)
- `WatchShared/` — `WatchDateSnapshot`/`WatchSnapshotStore`, sincronizados via `WatchConnectivity`. Grupo compartilhado por `Marco`, `MarcoWatch` e `MarcoWatchWidgets`
- `docs/` — documentação de apoio ao projeto

Alvos usam `PBXFileSystemSynchronizedRootGroup` (Xcode 16+): arquivo novo dentro de um grupo já sincronizado entra no target sozinho, sem editar `project.pbxproj`. Mudar **membership** (um catálogo/arquivo passar a pertencer a outro target) continua exigindo mexer no `.pbxproj`.

## Fluxo de trabalho (SDD)

- O agente principal **apenas orquestra** — nunca edita código do app diretamente. Cada task da SPEC.md é delegada aos sub-agentes de `.claude/agents/` no pipeline: `api-scout` (verificar APIs no SDK, quando aplicável) → `swift-implementer` (implementar) → `spec-reviewer` (veredicto contra os critérios de aceite) → `sim-verifier` (evidência em runtime, quando o critério exigir).
- Tasks sem dependência entre si podem rodar em paralelo, cada uma em worktree isolado (`git worktree` / `isolation: worktree` do Agent tool); tasks com dependência seguem a ordem da seção 6 da SPEC.md. A integração de volta à `main` é sempre sequencial — uma branch de cada vez, nunca merge simultâneo. Mudanças que tocam `project.pbxproj` (novo arquivo, novo target, capability) são o ponto de atrito: o merge desse arquivo raramente é automático, então resolva o conflito manualmente antes de reportar a task concluída.
- Os checkboxes da SPEC.md são marcados **somente pelo orquestrador**, após revisão aprovada.
- Todos os sub-agentes usam `model: sonnet`.
- Descobertas que contradigam a spec (API inexistente, decisão forçada) devem ser registradas na SPEC.md (seção 7 ou nota na task), não contornadas em silêncio.

## Commits

- Mensagens de commit **sem trailer de coautoria** — nunca incluir `Co-Authored-By` nem qualquer assinatura/comentário de IA. Apenas a mensagem descritiva.
