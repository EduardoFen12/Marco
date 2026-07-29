# Implementation Plan: Markstone — Lembretes de Datas Importantes

**Branch**: `001-markstone` | **Date**: 2026-07-29 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/001-markstone/spec.md`

> **Nota de migração:** plano retroativo — descreve a arquitetura que já está
> implementada (T1–T43), consolidada a partir do `SPEC.md` monolítico.

## Summary

App iOS pessoal de datas importantes com notificações em camadas, App
Intents/Siri, sugestões de IA on-device (Foundation Models), widget e Apple
Watch. Uma única entidade SwiftData (`ImportantDate`) num store em App Group
alimenta todas as superfícies; toda a lógica derivada (próxima ocorrência, dias
restantes, rótulos, símbolo e cor por categoria) mora em `Shared/` para não
divergir entre app, widget e Watch. O Watch não abre o store — recebe um
snapshot `Codable` por `WatchConnectivity`.

## Technical Context

**Language/Version**: Swift 6 / Xcode 26

**Primary Dependencies**: SwiftUI, SwiftData, UserNotifications, AppIntents,
FoundationModels, PhotosUI, Contacts, EventKit, WidgetKit, WatchConnectivity —
**nenhuma dependência de terceiros**

**Storage**: SwiftData (SQLite `Marco.sqlite`) em App Group
`group.Eduardo.Marco`; foto via `@Attribute(.externalStorage)`. Watch usa App
Group próprio (`group.Eduardo.Marco.watch`) só para o snapshot recebido.

**Testing**: Fora de escopo (constitution, princípio III). Verificação =
`xcodebuild build` limpo + evidência de runtime do `sim-verifier`.

**Target Platform**: iOS 26+ e watchOS correspondente

**Project Type**: Mobile app (iOS) + extensão de widget + app watchOS +
extensão de complications — 4 alvos no mesmo `Marco.xcodeproj`

**Performance Goals**: N/A (app pessoal, dezenas de registros). Widget gera 7
entries diárias com `policy: .after(7 dias)`.

**Constraints**: 100% on-device e offline — nenhuma chamada de rede, nenhuma
sincronização em nuvem. Geração de IA acontece localmente e precisa degradar
sem crash quando o modelo não está disponível.

**Scale/Scope**: ~10 telas SwiftUI, 4 App Intents, 1 widget (5 famílias), 1 app
watchOS + 1 complication, 43 tasks entregues em 5 fases.

## Constitution Check

*GATE: verificado contra `.specify/memory/constitution.md` v1.0.0.*

| Princípio | Status | Nota |
|---|---|---|
| I. Especificação antes de código | ✅ | Cada task tem critérios de aceite; divergências registradas em `research.md` |
| II. Orquestração por sub-agentes | ✅ | `api-scout` → `swift-implementer` → `spec-reviewer` → `sim-verifier` em todas as fases |
| III. Verificação = build + runtime | ✅ | Testes retirados de escopo em 24/07/2026; `MarcoTests`/`MarcoUITests` congelados |
| IV. Identificadores técnicos imutáveis | ✅ | Marca virou "Markstone" sem tocar bundle ID, App Groups, targets ou color sets |
| V. Uma fonte por comportamento compartilhado | ⚠️ | Cumprido a partir de T41/T42 (`DesignSystem/` + `Shared/`); antes disso houve duplicação de `DateType.symbolName` entre alvos — corrigida, achado registrado |

Nenhuma violação em aberto exige justificativa em Complexity Tracking.

## Project Structure

### Documentation (this feature)

```text
specs/001-markstone/
├── spec.md          # O quê e por quê (user stories, FRs, critérios de sucesso)
├── plan.md          # Este arquivo — stack, estrutura e decisões de arquitetura
├── data-model.md    # Entidade central, campos e regras derivadas
├── research.md      # Decisões, achados e limitações acumuladas em T1–T43
└── tasks.md         # As 43 tasks entregues + pendências promovíveis
```

### Source Code (repository root)

```text
Shared/                     # App + widget: ImportantDate (@Model), DateType,
                            # Relationship, Persistence (App Group),
                            # dateLabel/symbolName/stripeColor
WatchShared/                # App + watch + complications: WatchDateSnapshot,
                            # WatchSnapshotStore
DesignSystem/
└── Assets.xcassets         # Paleta do redesign — único lugar de cor do repo,
                            # sincronizado nos QUATRO alvos
Marco/                      # App iOS
├── Views/                  # Telas SwiftUI (lista, detalhe, form, busca,
│                           # importação)
├── Services/               # NotificationService, AISuggestionService,
│                           # WatchConnectivityService, importação
├── Intents/                # App Intents, AppEntity, AppShortcutsProvider
└── Assets.xcassets         # Só AppIcon/AccentColor
MarcoWidgets/               # Extensão de widget iOS (home + lock screen)
MarcoWatch/                 # App watchOS (lista das próximas datas)
MarcoWatchWidgets/          # Complications do Watch
docs/                       # Documentação de apoio (checklist manual, privacy)
```

**Structure Decision**: um projeto Xcode com quatro alvos e três grupos
compartilhados (`Shared/`, `WatchShared/`, `DesignSystem/`). Os grupos usam
`PBXFileSystemSynchronizedRootGroup` (Xcode 16+): arquivo novo dentro de um
grupo já sincronizado entra no target sozinho; mudar **membership** ainda exige
editar `project.pbxproj` — o ponto de atrito de merge entre branches paralelas.

## Decisões de arquitetura

1. **Ponto único de CRUD.** `NotificationService.cancel(_:center:)` é o único
   lugar que dispara `WidgetCenter.reloadAllTimelines()` e
   `WatchConnectivityService.sync(_:)`. Widget e Watch nunca observam o store
   por conta própria.
2. **Store compartilhado só no mesmo dispositivo.** App Group vale entre app e
   widget; o par iPhone↔Watch usa `WCSession.updateApplicationContext`, porque
   containers de App Group não atravessam dispositivos (achado do `api-scout`
   na T21).
3. **IA sem `throws`.** `AISuggestionService` mantém **uma** `LanguageModelSession`
   (`lazy var` sobre um `SystemLanguageModel` injetável) e retorna
   `Result<T, AISuggestionError>`; a construção de prompt fica em funções
   `nonisolated static` puras, testáveis sem `@MainActor` nem modelo real.
4. **App Intents "clássicos".** App Schemas foram avaliados na T5 e descartados
   — nenhum domínio de `AppIntents.AssistantSchemas` cobre datas importantes.
5. **Detalhe e edição são telas separadas** desde a Fase 3: o toque numa data
   abre a `ImportantDateDetailView` (read-only, com as sugestões de IA); a
   edição só a partir do botão `pencil`.
6. **Paleta em asset catalog, tipografia nativa.** As cores do mock Figma
   viraram color sets; a fonte do mock (Plus Jakarta Sans) foi descartada em
   favor de SF Pro/Dynamic Type.

## Complexity Tracking

> Sem violações da constitution em aberto.
