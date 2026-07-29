# Markstone Constitution

Princípios não-negociáveis do projeto Markstone (código: `Marco`). Derivada do
`CLAUDE.md` e das decisões registradas ao longo de T1–T43 (ver
`specs/001-markstone/research.md`).

## Core Principles

### I. Especificação antes de código

Nenhuma implementação começa sem uma spec com critérios de aceite verificáveis.
Os arquivos em `specs/<NNN>-<feature>/` (`spec.md`, `plan.md`, `tasks.md`) são a
fonte da verdade do escopo; o código é consequência deles, não o contrário.
Descoberta que contradiga a spec (API inexistente, decisão de design forçada) é
**registrada** em `research.md` da feature — nunca contornada em silêncio.

### II. Orquestração por sub-agentes (NÃO-NEGOCIÁVEL)

O agente principal **apenas orquestra** — nunca edita código do app diretamente.
Cada task passa pelo pipeline de `.claude/agents/`:

`api-scout` (verificar a forma real da API no SDK instalado, quando a task usa
API "a verificar") → `swift-implementer` (implementar só o escopo da task) →
`spec-reviewer` (veredicto independente contra os critérios de aceite) →
`sim-verifier` (evidência em runtime, quando o critério exige comportamento
observável).

Todos os sub-agentes rodam em `model: sonnet`. Os checkboxes de `tasks.md` são
marcados **somente pelo orquestrador**, depois de revisão aprovada — nunca pelo
sub-agente que implementou.

### III. Verificação = build limpo + runtime, não testes

**Testes são fora de escopo**: sem testes unitários (`MarcoTests`) e sem testes
de UI (`MarcoUITests`). A verificação de uma task é (a) `xcodebuild build` sem
erro, com o log no report, e (b) evidência do `sim-verifier` no simulador quando
o critério de aceite descreve comportamento observável. Critério de aceite deve
ser escrito em termos do que se observa rodando o app, nunca em termos de um
teste que passa.

Corolário: tamanhos de acessibilidade do Dynamic Type (`accessibility-medium` …
`accessibility-extra-extra-extra-large`) também estão fora de escopo — nem
implementar nem verificar. Os tamanhos padrão seguem funcionando por herança dos
estilos nativos de fonte.

### IV. Identificadores técnicos são imutáveis

O produto se chama **Markstone**; o código continua **Marco**. Só o que o
usuário vê mudou (`CFBundleDisplayName`, títulos, usage descriptions, docs).
**Nenhum identificador técnico é renomeado**: bundle ID `Eduardo.Marco`, App
Groups `group.Eduardo.Marco`/`.watch`, `Marco.sqlite`, targets, schemes,
diretórios, `Marco.xcodeproj`, color sets `Marco*` e `Marco.icon`. Trocar bundle
ID ou App Group renomeia o container e **apaga os dados do app instalado**. Ao
ler "Marco" no repo, presuma identificador, não marca.

### V. Uma fonte por comportamento compartilhado

Lógica usada por mais de um alvo mora em grupo compartilhado, nunca duplicada:
`Shared/` (app + widget: `ImportantDate`, enums, `Persistence`,
`DateType.symbolName`/`.stripeColor`, `ImportantDate.dateLabel`),
`WatchShared/` (app + watch + complications) e `DesignSystem/Assets.xcassets`
(paleta, sincronizada nos quatro alvos). Mapeamento duplicado entre alvos é
defeito, não conveniência — foi a origem dos achados de T40/T41/T42.

## Restrições técnicas

- **Plataforma:** iOS 26+ (mínimo para Foundation Models e App Intents atuais).
- **Stack:** SwiftUI + SwiftData + UserNotifications + AppIntents +
  FoundationModels + PhotosUI + WidgetKit + WatchConnectivity.
- **Strings de UI em pt-BR**, com localização em `Localizable.xcstrings` /
  `InfoPlist.xcstrings`. O String Catalog só extrai chaves novas abrindo o
  projeto no Xcode.app — `xcodebuild` pela CLI não extrai.
- **Build de referência:**
  `xcodebuild -project Marco.xcodeproj -scheme Marco -destination 'platform=iOS Simulator,name=iPhone 17' build`
- Alvos usam `PBXFileSystemSynchronizedRootGroup` (Xcode 16+): arquivo novo
  dentro de grupo já sincronizado entra no target sozinho. Mudar **membership**
  (arquivo passar a pertencer a outro target) continua exigindo editar o
  `project.pbxproj`.
- ⚠️ Nos color sets de `DesignSystem/Assets.xcassets` os slots de aparência
  estão **invertidos de propósito**: o slot sem tag ("Any") é o tom **escuro**,
  porque o watchOS descarta a entrada tagueada `luminosity` no build. Cor nova
  criada do jeito padrão no editor do Xcode sai errada no Watch.

## Fluxo de trabalho

- Tasks sem dependência entre si podem rodar **em paralelo**, cada uma em
  `git worktree` isolado. Tasks com dependência seguem a ordem de `tasks.md`.
- A integração de volta à `main` é **sempre sequencial** — uma branch de cada
  vez, nunca merge simultâneo. Mudanças que tocam `project.pbxproj` (novo
  arquivo, novo target, capability) raramente dão merge automático: resolver o
  conflito manualmente antes de reportar a task como concluída.
- Cada task delegada recebe: o caminho da spec, o ID da task e os critérios de
  aceite. O sub-agente implementa **somente** aquele escopo.
- Mensagens de commit **sem trailer de coautoria** — nunca incluir
  `Co-Authored-By` nem qualquer assinatura ou comentário de IA. Apenas a
  mensagem descritiva, em pt-BR.

## Governance

Esta constitution prevalece sobre qualquer outra prática do repositório. Toda
revisão de task (`spec-reviewer`) verifica conformidade com ela. Complexidade
que viole um princípio precisa de justificativa escrita em `plan.md`
(Complexity Tracking) — ou o princípio é emendado explicitamente, não ignorado.

Emendas exigem: registro do que mudou, versão nova abaixo e atualização do
`CLAUDE.md` quando a regra também vale para uso interativo. Versionamento
semântico: MAJOR para remoção/redefinição de princípio, MINOR para princípio ou
seção nova, PATCH para esclarecimento sem mudança de regra.

**Version**: 1.0.0 | **Ratified**: 2026-07-29 | **Last Amended**: 2026-07-29
