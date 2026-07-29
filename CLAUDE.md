# Markstone

App iOS de datas importantes (aniversários, comemorativas, memoriais) com notificações em camadas, App Intents/Siri e sugestões de IA on-device via Foundation Models. Projeto de aprendizado de App Intents, Shortcuts e Foundation Models framework.

⚠️ **O produto se chama "Markstone"; o código continua "Marco".** O nome "Marco" já existia na App Store, então a marca virou "Markstone" (ficha da loja: "Markstone: Dates & Reminders"). Só o que o usuário vê mudou — `CFBundleDisplayName`, título da tela, usage descriptions e docs. **Nada de identificador técnico foi renomeado**: bundle ID `Eduardo.Marco`, App Groups `group.Eduardo.Marco`/`.watch`, `Marco.sqlite`, targets, schemes, diretórios, `Marco.xcodeproj`, color sets `Marco*` e `Marco.icon` seguem como estão — trocar bundle ID ou App Group renomeia o container e apaga os dados do app instalado. Ao ler "Marco" no repo, presuma identificador, não marca.

**O projeto segue o [GitHub Spec Kit](https://github.com/github/spec-kit) (v0.14.4).** A fonte da verdade está em:

- `.specify/memory/constitution.md` — princípios não-negociáveis (pipeline de sub-agentes, testes fora de escopo, identificadores imutáveis). Leia antes de qualquer trabalho.
- `specs/<NNN>-<feature>/` — uma pasta por feature, com `spec.md` (requisitos), `plan.md` (arquitetura), `data-model.md`, `research.md` (decisões/achados) e `tasks.md` (checkboxes).
- `specs/001-markstone/` é a feature retroativa: descreve o app que já existe (T1–T43). Trabalho novo entra como `002-…` em diante, via `/speckit-specify` → `/speckit-plan` → `/speckit-tasks` → `/speckit-implement`.
- A feature ativa fica em `.specify/feature.json`; `SPEC.md` na raiz é só um mapa de para-onde-foi-o-quê.

## Plataforma e stack

- iOS 26+ (mínimo para Foundation Models e App Intents atuais)
- SwiftUI + SwiftData + UserNotifications + AppIntents + FoundationModels + PhotosUI (foto por data, Fase 3)
- Testes: **fora de escopo.** Não escrever testes unitários (`MarcoTests`) nem testes de UI (`MarcoUITests`) — nenhum dos dois faz parte do fluxo. A verificação de uma task é: compilar sem erro + evidência em runtime do `sim-verifier` quando o critério de aceite exigir comportamento observável.
- Dynamic Type em tamanhos de acessibilidade (`accessibility-medium` … `accessibility-extra-extra-extra-large`): **fora de escopo.** Não implementar ajustes de layout para essas categorias nem verificá-las (`simctl ui … content_size`). Os tamanhos padrão de Dynamic Type seguem funcionando por herança dos estilos nativos de fonte. Nenhum critério de aceite deve exigir suporte a fontes de acessibilidade. Ver a decisão registrada em `specs/001-markstone/research.md`.
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
- `DesignSystem/Assets.xcassets` — color sets da paleta do redesign (T29). Grupo sincronizado dos **quatro** alvos (T42), único lugar da paleta no repo. `Marco/Assets.xcassets` guarda só `AppIcon`/`AccentColor`; `MarcoWatch/Assets.xcassets`, só `AppIcon`. ⚠️ **Os slots de aparência estão invertidos de propósito** — o slot sem tag ("Any") é o tom **escuro**, porque o watchOS descarta a entrada tagueada `luminosity` no build (ver achado da T41 em `specs/001-markstone/research.md`). Cor nova criada no editor do Xcode do jeito padrão sai errada no Watch.
- `MarcoWidgets/` — widget iOS (T20); `MarcoWatch/` + `MarcoWatchWidgets/` — app do Watch e complications (T21)
- `WatchShared/` — `WatchDateSnapshot`/`WatchSnapshotStore`, sincronizados via `WatchConnectivity`. Grupo compartilhado por `Marco`, `MarcoWatch` e `MarcoWatchWidgets`
- `docs/` — documentação de apoio ao projeto

Alvos usam `PBXFileSystemSynchronizedRootGroup` (Xcode 16+): arquivo novo dentro de um grupo já sincronizado entra no target sozinho, sem editar `project.pbxproj`. Mudar **membership** (um catálogo/arquivo passar a pertencer a outro target) continua exigindo mexer no `.pbxproj`.

## Fluxo de trabalho (SDD)

- O agente principal **apenas orquestra** — nunca edita código do app diretamente. Cada task de `tasks.md` é delegada aos sub-agentes de `.claude/agents/` no pipeline: `api-scout` (verificar APIs no SDK, quando aplicável) → `swift-implementer` (implementar) → `spec-reviewer` (veredicto contra os critérios de aceite) → `sim-verifier` (evidência em runtime, quando o critério exigir).
- Tasks sem dependência entre si podem rodar em paralelo, cada uma em worktree isolado (`git worktree` / `isolation: worktree` do Agent tool); tasks com dependência seguem a ordem de `tasks.md`. A integração de volta à `main` é sempre sequencial — uma branch de cada vez, nunca merge simultâneo. Mudanças que tocam `project.pbxproj` (novo arquivo, novo target, capability) são o ponto de atrito: o merge desse arquivo raramente é automático, então resolva o conflito manualmente antes de reportar a task concluída.
- Os checkboxes de `tasks.md` são marcados **somente pelo orquestrador**, após revisão aprovada.
- Todos os sub-agentes usam `model: sonnet`.
- Descobertas que contradigam a spec (API inexistente, decisão forçada) devem ser registradas em `research.md` da feature (ou como nota na task), não contornadas em silêncio.

## Commits

- Mensagens de commit **sem trailer de coautoria** — nunca incluir `Co-Authored-By` nem qualquer assinatura/comentário de IA. Apenas a mensagem descritiva.
