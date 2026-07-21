# Marco — Lembretes de Datas Importantes

Spec de projeto (SDD) para praticar **App Intents**, **Shortcuts** e uma primeira integração com o **Foundation Models framework**. Este documento é a fonte da verdade do projeto: requisitos, design técnico e a lista de tasks executáveis por sub-agentes.

## 1. Visão geral

App iOS de datas importantes (aniversários, datas comemorativas, memoriais) com:

- **Lembretes em camadas** via notificações locais (1 semana antes, 1 dia antes, no dia).
- **Consultas por voz via Siri** através de App Intents (leitura e escrita).
- **Sugestões geradas por IA on-device** (Foundation Models) para presentes e mensagens personalizadas.

**Objetivo de aprendizado:** praticar os dois padrões de App Intent (query read-only e criação/escrita), montar uma automation simples no Shortcuts, e dar o primeiro passo com o Foundation Models framework.

**Requisito de plataforma:** iOS 26+ (mínimo para o Foundation Models framework e para as capacidades atuais de App Intents/App Schemas). Deployment target do projeto deve ser ajustado de acordo.

## 2. Modelo de dados

Entidade central: `ImportantDate` (SwiftData `@Model`).

| Campo | Tipo | Notas |
|---|---|---|
| `id` | `UUID` | identidade estável (usada também pela `AppEntity`) |
| `name` | `String` | nome da pessoa/data (ex: "Mari", "Dia das Mães") |
| `date` | `Date` | a data do evento; para recorrentes, importa dia/mês (ano usado p/ idade quando aplicável) |
| `type` | `DateType` (enum) | `.birthday`, `.commemorative`, `.memorial` |
| `relationship` | `Relationship?` (enum) | ex: `.partner`, `.family`, `.friend`, `.colleague`, `.other` — usado como contexto p/ IA |
| `notes` | `String?` | contexto livre (gostos, interesses) — habilita a sugestão de presente |
| `birthYear` | `Int?` | ano de nascimento (opcional; só p/ `type == .birthday`) — habilita cálculo de idade (T13) |
| `notificationHour` | `Int` | hora do lembrete desta data (default 9); vale para as 3 camadas (T13) |
| `notificationMinute` | `Int` | minuto do lembrete desta data (default 0) (T13) |
| `createdAt` | `Date` | housekeeping |

Regras derivadas:

- **Próxima ocorrência**: datas são recorrentes anualmente; "quanto falta" e "datas chegando" são calculados sobre a próxima ocorrência (dia/mês) a partir de hoje.
- **Aniversários guardam dia/mês contra um ano bissexto fixo (2000)** no campo `date`, para que 29/02 seja representável independente de haver ou não `birthYear`. `birthYear` fica separado, só para idade (`age(on:)`). O ano de `date` é ignorado pela próxima ocorrência.
- **Idade**: `age(on:) -> Int?` retorna a idade na próxima ocorrência quando `birthYear` está preenchido; `nil` caso contrário (T13/T15).
- Enums (`DateType`, `Relationship`) devem conformar a `Codable` e, quando expostos em intents, a `AppEnum`.

> O modelo acima é a proposta inicial; o sub-agente da task de modelo pode refinar nomes/tipos, mas mudanças estruturais (novos campos, novas entidades) devem voltar para revisão do orquestrador.

## 3. Funcionalidades

### 3.1 Notificações locais

- 3 notificações por data: **1 semana antes**, **1 dia antes** e **no dia**.
- Implementação: `UserNotifications` + `UNCalendarNotificationTrigger`, calculadas a partir do campo `date` (próxima ocorrência).
- **Hora por data:** a hora de disparo é definida por cada `ImportantDate` (`notificationHour`/`notificationMinute`, default 9:00) e vale para as 3 camadas — não é mais uma constante global (T13/T14).
- Agendamento sincronizado com o ciclo de vida da entidade: criar/editar reagenda, excluir cancela (identificadores determinísticos derivados do `id` + camada).
- Pedir permissão de notificação no primeiro uso relevante (não no launch).
- **Notificações interativas (T22):** `UNNotificationCategory` com ações "Adiar" (reagenda a curto prazo) e "Abrir para mensagem" (deep-link ao detalhe da data p/ gerar mensagem via `AISuggestionService`).

### 3.2 App Intents (consultas via Siri)

| Intent | Tipo | Exemplo de frase |
|---|---|---|
| `UpcomingDatesIntent` | Query | "Quais datas estão chegando?" |
| `DaysUntilDateIntent` | Query com parâmetro | "Quanto falta pro aniversário da Mari?" |
| `AddImportantDateIntent` | Criação/escrita | "Adiciona o aniversário da Mari, 31 de maio" |
| `BirthdaysThisMonthIntent` (bônus) | Query por período | "Quem faz aniversário esse mês?" |

Notas de design:

- `ImportantDate` exposta como `AppEntity` (com `EntityQuery`) para o parâmetro de `DaysUntilDateIntent`.
- Frases registradas via `AppShortcutsProvider` para invocação por voz sem setup manual.
- **Nota de aprendizado:** as duas primeiras são read-only (retornam dados existentes), a terceira é write (cria entidade nova com parâmetros). Implementar nessa ordem para sentir os dois padrões.
- Avaliar App Schemas (assistant schemas) se houver schema aplicável ao domínio; se não houver fit claro, seguir com App Intents "clássicos" e registrar a decisão.

### 3.3 Shortcuts

- **Automation de exemplo: "Resumo da manhã"** — roda todo dia de manhã, chama `UpcomingDatesIntent` e entrega um resumo das datas próximas.
- Não requer código novo além dos intents; a entrega desta parte é o intent retornar resultado utilizável no Shortcuts (valor de retorno + `IntentResult` com dialog) e um passo-a-passo documentado (`docs/shortcuts-resumo-da-manha.md`) para montar a automation.

### 3.4 Foundation Models (IA on-device)

`AISuggestionService` (`@MainActor`) mantém **uma única `LanguageModelSession`** (criada via `lazy var` a partir de um `SystemLanguageModel` injetável, padrão `.default`) reaproveitada entre chamadas; a instrução varia por `type`/`relationship` no *prompt* de cada operação (mesma sessão, prompt diferente), não em sessões separadas:

- **`suggestGift(notes:relationship:) async -> Result<GiftSuggestion, AISuggestionError>`** — usa `notes` + `relationship` como contexto. **Só é oferecida se `notes` estiver preenchido** (a UI só mostra o botão nessa condição, via `ImportantDateFormView.showsGiftSuggestion(notes:isModelAvailable:)` — o serviço em si não valida isso). Saída estruturada via `@Generable` (`GiftSuggestion`: `title` + `rationale`).
- **`personalizedMessage(name:type:relationship:notes:) async -> Result<String, AISuggestionError>`** — texto curto conforme `relationship` (tom carinhoso/engraçado/formal, ver `tone(for:)`) e `type`. Para `type == .memorial`, o mesmo prompt troca para **tom reflexivo** em vez de sugestão de presente — mesma arquitetura, instrução diferente.
- Construção de prompt isolada em funções `nonisolated static` (`giftPrompt`, `messagePrompt`) — puras, sem tocar a sessão, testáveis diretamente sem `@MainActor` nem modelo real.

Requisitos técnicos:

- `import FoundationModels`, sessão on-device.
- Ambas as operações retornam `Result<T, AISuggestionError>` — **não `throws`**. Indisponibilidade do modelo (`SystemLanguageModel.default.availability`, exposta via `AISuggestionService.availability`/`isAvailable`) e falhas de geração (`LanguageModelSession.GenerationError`, mapeado caso a caso em `domainError(from:)`) são convertidas em `AISuggestionError` (enum com `.unavailable(reason)` e `.generationFailed(String)`) com mensagens em pt-BR (`errorDescription`), para a UI degradar graciosamente (esconder/desabilitar os botões de IA com explicação) sem `try/catch` espalhado pelas views.
- Saída estruturada via `@Generable` na sugestão de presente; a mensagem personalizada retorna `String` livre.

### 3.5 Importação de datas existentes (Contatos + EventKit)

Importa datas que o usuário já tem no aparelho, **sempre por opt-in explícito** — nada entra automaticamente.

- **Fontes:** `Contacts` (aniversários dos contatos, com ano quando disponível → `birthYear`) e `EventKit` (eventos do Calendário, incl. o calendário de Aniversários). Duas permissões, pedidas **sob demanda** (só ao tocar em importar).
- **Fluxo de UX:** toque explícito → permissão → **tela de revisão** (sheet) com os candidatos em checkboxes pré-marcados, **agrupados por fonte**, com **dedupe** contra datas já salvas (mesmo nome + dia/mês) → importa **só os selecionados**, criando `ImportantDate` + agendando notificações (reuso do `NotificationService`).
- **Pontos de entrada:** botão no *empty state* da lista e item de menu "Importar…" na toolbar da lista (re-executável). Sem tela de Ajustes dedicada (a hora virou por-data; não há outra config a hospedar).
- Modelo `ImportCandidate` compartilhado pelas duas fontes alimenta a mesma tela de revisão.

### 3.6 Widget (WidgetKit)

- Widget de "próximas datas" com contagem regressiva, nas famílias de **home screen** e **lock screen**.
- Lê o store SwiftData compartilhado (App Group, ver 3.8) e reusa `nextOccurrence`/`daysUntilNextOccurrence`.

### 3.7 Apple Watch

- App watchOS com a lista das próximas datas + **complication** de contagem regressiva na carátula.
- Lê o mesmo store compartilhado (App Group).

### 3.8 Compartilhamento de dados (App Group)

- O `ModelContainer` SwiftData vive num container em **App Group**, para que o widget e o app do watch leiam os mesmos dados do app principal (T19, pré-requisito de 3.6 e 3.7).

## 4. Stack técnico

| Camada | Tecnologia |
|---|---|
| UI | SwiftUI |
| Persistência | SwiftData |
| Notificações | UserNotifications |
| Integração com o sistema | App Intents "clássicos" (App Schemas avaliados e descartados — sem fit para o domínio, ver seção 7) |
| IA | Foundation Models framework (on-device) |
| Automação | Shortcuts, via os App Intents expostos |
| Importação | Contacts + EventKit |
| Widget | WidgetKit (home + lock screen) |
| Watch | watchOS (app + complication) |
| Compartilhamento | App Group (store SwiftData compartilhado entre app, widget e watch) |
| Testes | Swift Testing — unitários no target `MarcoTests` (testes de UI / `MarcoUITests` fora de escopo; fluxos de UI verificados pelo `sim-verifier`) |

> Stack confirmada no SDK instalado (iOS 26.4): cada camada foi validada pelo sub-agente `api-scout` antes da implementação (T4 — notificações; T5–T8 — App Intents; T10 — Foundation Models). Divergências e decisões encontradas nesse processo estão registradas na seção 7.

## 5. Processo de implementação (orquestração SDD)

- O **agente principal apenas orquestra**: nunca edita código do app diretamente. Ele delega cada task ao sub-agente **`swift-implementer`**, revisa o resultado e atualiza esta spec.
- Sub-agentes de apoio (todos em `.claude/agents/`, rodando em Sonnet):
  - **`api-scout`** — antes de tasks que usam APIs "a verificar" (T4, T5–T8, T10), confirma no SDK instalado que os símbolos pressupostos existem e briefa o implementador.
  - **`swift-implementer`** — implementa a task.
  - **`spec-reviewer`** — após a implementação, verifica os critérios de aceite de forma independente e dá o veredicto.
  - **`sim-verifier`** — para critérios que exigem observar o app rodando (T3, T4, T7, T11), exercita o simulador e coleta evidências.
- **Execução consecutiva**: uma task por vez, na ordem da seção 6, respeitando dependências. (Paralelismo com worktrees fica como experimento futuro.)
- Cada task delegada recebe: o caminho desta spec, o ID da task (ex: `T3`) e os critérios de aceite. O sub-agente implementa **somente** o escopo da task.
- **Verificação por task:** o sub-agente deve compilar (`xcodebuild build`) e rodar os testes unitários do target `MarcoTests` (`xcodebuild test -only-testing:MarcoTests`) antes de reportar conclusão, incluindo o log de resultado no report. Testes de UI (`MarcoUITests`) não fazem parte do escopo — fluxos de UI são verificados pelo `sim-verifier`.
- **Rastreamento:** os checkboxes da seção 6 são a fonte da verdade. O **orquestrador** (não o sub-agente) marca `[x]` após revisar e aceitar o resultado.
- Descobertas que invalidem parte da spec (API inexistente, decisão de design forçada) são registradas na seção 7 ou como nota na task.

## 6. Tasks

> Formato: cada task é atômica, tem critérios de aceite verificáveis e lista suas dependências. Executar em ordem.

- [x] **T1 — Fundação do projeto**
  Ajustar deployment target para iOS 26, criar estrutura de pastas (`Models/`, `Views/`, `Services/`, `Intents/`), configurar o `ModelContainer` no `MarcoApp`.
  *Aceite:* projeto compila; container SwiftData injetado no ambiente. *Depende de:* —

- [x] **T2 — Modelo de dados**
  Implementar `ImportantDate` (@Model) + enums `DateType` e `Relationship` conforme seção 2, incluindo lógica de "próxima ocorrência" e "dias restantes" como extensões testáveis.
  *Aceite:* testes unitários cobrindo próxima ocorrência (incl. virada de ano e 29/02) passam. *Depende de:* T1

- [x] **T3 — UI: lista e CRUD**
  Lista de datas ordenada por proximidade (mostrando "faltam N dias"), tela de criação/edição com todos os campos, swipe para excluir.
  *Aceite:* fluxo criar → listar → editar → excluir funciona no simulador; preview das views compila. *Depende de:* T2

- [x] **T4 — Notificações locais**
  `NotificationService` com agendamento das 3 camadas por data, permissão sob demanda, reagendamento em edição e cancelamento em exclusão, integrado ao CRUD da T3.
  *Aceite:* testes do cálculo dos triggers passam; criar uma data agenda 3 requests pendentes (verificável via `pendingNotificationRequests`). *Depende de:* T3

- [x] **T5 — AppEntity + UpcomingDatesIntent**
  Expor `ImportantDate` como `AppEntity` com `EntityQuery`; implementar `UpcomingDatesIntent` (read-only) retornando as próximas datas com dialog falável pela Siri; registrar frase no `AppShortcutsProvider`.
  *Aceite:* intent aparece no app Shortcuts e retorna as datas do banco. *Depende de:* T2 (T3 ajuda a validar)

- [x] **T6 — DaysUntilDateIntent**
  Query com parâmetro (`ImportantDate` como entity parameter): "Quanto falta pro aniversário da Mari?" — resolução de entidade por nome, dialog com dias restantes.
  *Aceite:* intent no Shortcuts aceita seleção de entidade e responde corretamente. *Depende de:* T5

- [x] **T7 — AddImportantDateIntent**
  Intent de escrita: cria uma `ImportantDate` a partir de parâmetros (nome, data, tipo), com prompts de parâmetro faltante e agendamento das notificações (reuso do `NotificationService`).
  *Aceite:* criar via Shortcuts persiste no SwiftData e aparece na lista do app. *Depende de:* T5, T4

- [x] **T8 — BirthdaysThisMonthIntent (bônus)**
  Query por período: aniversários do mês corrente.
  *Aceite:* intent retorna somente `type == .birthday` do mês atual. *Depende de:* T5

- [x] **T9 — Shortcut "Resumo da manhã"**
  Garantir que `UpcomingDatesIntent` retorna valor encadeável no Shortcuts; escrever `docs/shortcuts-resumo-da-manha.md` com o passo-a-passo da automation (trigger diário de manhã → intent → mostrar/falar resumo).
  *Aceite:* automation montada seguindo o doc funciona no aparelho/simulador. *Depende de:* T5

- [x] **T10 — Foundation Models: serviço de IA**
  `AISuggestionService` com uma `LanguageModelSession`; checagem de disponibilidade; duas operações: sugestão de presente (requer `notes`) e mensagem personalizada (tom por `relationship`/`type`, reflexivo para `.memorial`), com saída estruturada via `@Generable` onde couber.
  *Aceite:* compila no SDK iOS 26; indisponibilidade tratada sem crash; instruções distintas por tipo verificáveis em teste/preview. *Depende de:* T2

- [x] **T11 — UI das sugestões de IA**
  Na tela de detalhe da data: botão "Sugerir presente" (visível só com `notes` preenchido) e "Gerar mensagem", com estado de loading, exibição do resultado e copiar para clipboard. Esconder recursos quando o modelo estiver indisponível.
  *Aceite:* fluxo completo no simulador com modelo disponível; UI degrada corretamente sem modelo. *Depende de:* T3, T10

- [x] **T12 — Revisão final e polish**
  Passada de integração: strings de UI consistentes (pt-BR), estados vazios, revisão dos testes, atualização desta spec com o que mudou.
  *Aceite:* `xcodebuild test -only-testing:MarcoTests` verde; seções 2–4 da spec refletem o código real. *Depende de:* todas

### Fase 2 — Extensões (T13+)

> Novas features aprovadas: hora de notificação por data, importação de Contatos/EventKit, aniversário sem ano (com idade), widget, Apple Watch e notificações interativas. Mesmas regras da seção 5 (uma task por vez, pipeline SDD, checkbox só pelo orquestrador).

- [x] **T13 — Modelo: hora por data + ano de nascimento + idade**
  Em `ImportantDate`: campos `notificationHour`/`notificationMinute` (default 9:00) e `birthYear: Int?`; helper `age(on:) -> Int?`; convenção do ano bissexto fixo (2000) para o `date` de aniversários. `NotificationService.triggerSpecs` passa a ler a hora da própria data (removendo/rebaixando as constantes `defaultHour`/`defaultMinute`). Migração SwiftData leve.
  *Aceite:* testes de `age(on:)` e de trigger com hora custom passam; store existente migra sem quebrar. *Depende de:* T2, T4

- [x] **T14 — Formulário: hora por data + aniversário sem ano**
  Em `ImportantDateFormView`: `DatePicker(.hourAndMinute)` para a hora do lembrete; quando `type == .birthday`, trocar o `DatePicker(.date)` por seletor **só dia/mês** + campo opcional "Ano de nascimento". Tipos não-aniversário mantêm data completa. Atualizar `save()`.
  *Aceite:* criar aniversário sem ano persiste dia/mês correto (incl. 29/02); a hora escolhida reflete nos pending requests. *Depende de:* T13, T3

- [x] **T15 — Idade nos aniversários**
  Mostrar "faz N anos" na lista e/ou detalhe quando houver `birthYear`.
  *Aceite:* item com ano mostra idade correta na próxima ocorrência; sem ano, nada é exibido. *Depende de:* T13, T3

- [x] **T16 — ContactsImportService (aniversários dos Contatos)**
  Framework `Contacts`: permissão sob demanda, buscar contatos com aniversário, produzir candidatos `type = .birthday` (com `birthYear` quando o contato tiver ano).
  *Aceite:* serviço retorna candidatos a partir dos contatos; sem permissão degrada sem crash. *Depende de:* T13

- [x] **T17 — EventKitImportService (eventos do Calendário)**
  `EventKit`: permissão sob demanda, buscar eventos num intervalo (inclui o calendário de Aniversários), produzir candidatos com data/tipo aproximado.
  *Aceite:* serviço retorna candidatos a partir dos eventos; sem permissão degrada sem crash. *Depende de:* T2

- [x] **T18 — Tela de revisão de importação + pontos de entrada**
  Modelo `ImportCandidate` compartilhado pelas duas fontes; sheet listando candidatos com checkbox (pré-marcados), **agrupados por fonte** (Contatos / Calendário), com **dedupe** contra datas já salvas (mesmo nome + dia/mês). Importar só os selecionados → cria `ImportantDate` + agenda notificações. Entradas: botão no *empty state* da lista + item de menu "Importar…" na toolbar. Permissão pedida só ao tocar em importar.
  *Aceite:* fluxo importa apenas os selecionados; reexecutar não duplica; itens já existentes aparecem marcados/ocultos. *Depende de:* T16, T17, T4

- [x] **T19 — App Group + ModelContainer compartilhado**
  Mover o store SwiftData para um container em App Group, para widget e watch lerem os mesmos dados. Ajustar `MarcoApp`/`Persistence`.
  *Aceite:* app continua lendo/gravando normalmente pelo container do App Group. *Depende de:* T1

- [ ] **T20 — Widget (WidgetKit: home + lock screen)**
  Extensão WidgetKit com timeline de "próximas datas" (contagem regressiva), famílias de home e lock screen, lendo o store compartilhado; reusa `nextOccurrence`/`daysUntilNextOccurrence`.
  *Aceite:* widget mostra as próximas datas e atualiza a contagem no simulador. *Depende de:* T19, T5

- [ ] **T21 — App Apple Watch (lista + complication)**
  Target watchOS: lista das próximas datas + complication de contagem regressiva na carátula, lendo o store compartilhado.
  *Aceite:* app do watch lista as datas; complication mostra a próxima. *Depende de:* T19

- [ ] **T22 — Notificações interativas**
  `UNNotificationCategory` com ações "Adiar" (reagenda a curto prazo) e "Abrir para mensagem" (deep-link abre o detalhe da data p/ gerar mensagem via `AISuggestionService`). Delegate trata as ações.
  *Aceite:* notificação exibe as ações; "Adiar" reagenda; abrir leva ao detalhe. *Depende de:* T4, T10

## 7. Em aberto

- [x] **Tom padrão das mensagens geradas: fixo por `relationship`.** Decidido na T10 (`AISuggestionService.tone(for:)`): `.partner`/`.family` → carinhoso, `.friend` → engraçado, `.colleague`/`.other`/nil → formal. `type == .memorial` sempre sobrepõe para tom reflexivo, independente do `relationship`. Não configurável pelo usuário no MVP.
- [ ] Limite de datas antes de precisar de paginação/busca na UI (decidir se surgir necessidade; fora do MVP por ora)
- [ ] **Ideias brainstormadas, não priorizadas (Fase 2):** sincronização multi-dispositivo via iCloud/CloudKit; Live Activity para datas iminentes (contagem no dia); foto por pessoa; busca/filtro na lista (relacionado ao item de paginação acima). Promover a task se/quando o usuário pedir.
- [x] **App Schemas: não aplicável.** Avaliado na T5 (api-scout, SDK iOS 26.4): o namespace `AppIntents.AssistantSchemas` só cobre os domínios `Books`, `Browser`, `Camera`, `Files`, `Journal`, `Mail`, `Photos`, `Presentation`, `Reader`, `Spreadsheet`, `System`, `VisualIntelligence`, `Whiteboard`, `WordProcessor` — nenhum schema para lembretes, tarefas, calendário ou datas. Marco segue com App Intents "clássicos" (custom), como a spec já assumia.
- **Limitação de ambiente — geração real do Foundation Models não verificável neste Mac (T11):** `sim-verifier` confirmou `SystemLanguageModel.default.availability == .available` no host de desenvolvimento, mas toda chamada de `respond` falha em runtime por um erro de infraestrutura do próprio framework (guardrail/safety checker: `DecodingError.keyNotFound("thoughtContents")`, provável mismatch entre assets do modelo e o simulador iOS 26.4 usados neste host) — não é um bug do código do Marco. A UI da T11 trata esse erro graciosamente (mensagem em pt-BR, sem crash), mas nem o caminho de sucesso (resultado + copiar) nem o caminho de indisponibilidade genuína (`.unavailable`) puderam ser exercitados neste ambiente. Repetir manualmente em um Mac com Apple Intelligence/assets íntegros antes de considerar a funcionalidade de IA validada ponta a ponta.

- **Decisão T2 — 29/02 sem ano bissexto:** a "próxima ocorrência" de uma data em 29/02 não é normalizada para 28/02 ou 01/03; avança até o próximo ano bissexto (`ImportantDate.nextOccurrence`). Coberta por testes. Impacto a considerar na T4: notificações de aniversário 29/02 só disparam a cada 4 anos — avaliar se isso é o comportamento desejado ou se merece tratamento de UX próprio.

- **Atenção para T20/T21 — App Group sem `SystemCapabilities` no `project.pbxproj` (achado do `spec-reviewer` na T19):** `Marco/Marco.entitlements` + `CODE_SIGN_ENTITLEMENTS` foram configurados manualmente (editando arquivos), sem passar pela UI "Signing & Capabilities" do Xcode, que normalmente também escreve uma entrada `SystemCapabilities` (`com.apple.ApplicationGroups.iOS`) no `TargetAttributes`. Resultado: em build limpo para Simulador, o binário assinado (`Marco.app.xcent`) sai com entitlements vazias mesmo com `CODE_SIGN_ENTITLEMENTS` apontando certo — mas funciona porque o Simulador não impõe sandboxing sobre entitlements (`containerURL(forSecurityApplicationGroupIdentifier:)` funciona mesmo assim, confirmado em runtime). Em **build de dispositivo real** (necessário para validar Widget/Watch de fato, ou distribuição), essa lacuna provavelmente faz `containerURL` retornar `nil` e disparar o `fatalError` de `Persistence.swift` na inicialização. Antes de verificar T20/T21 em dispositivo físico, adicionar a capability "App Groups" pela UI do Xcode (Signing & Capabilities) para que o `SystemCapabilities`/registro do App Group no Developer Portal seja feito corretamente.
