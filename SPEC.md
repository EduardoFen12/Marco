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
| `createdAt` | `Date` | housekeeping |

Regras derivadas:

- **Próxima ocorrência**: datas são recorrentes anualmente; "quanto falta" e "datas chegando" são calculados sobre a próxima ocorrência (dia/mês) a partir de hoje.
- Enums (`DateType`, `Relationship`) devem conformar a `Codable` e, quando expostos em intents, a `AppEnum`.

> O modelo acima é a proposta inicial; o sub-agente da task de modelo pode refinar nomes/tipos, mas mudanças estruturais (novos campos, novas entidades) devem voltar para revisão do orquestrador.

## 3. Funcionalidades

### 3.1 Notificações locais

- 3 notificações por data: **1 semana antes**, **1 dia antes** e **no dia**.
- Implementação: `UserNotifications` + `UNCalendarNotificationTrigger`, calculadas a partir do campo `date` (próxima ocorrência).
- Agendamento sincronizado com o ciclo de vida da entidade: criar/editar reagenda, excluir cancela (identificadores determinísticos derivados do `id` + camada).
- Pedir permissão de notificação no primeiro uso relevante (não no launch).

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

## 4. Stack técnico

| Camada | Tecnologia |
|---|---|
| UI | SwiftUI |
| Persistência | SwiftData |
| Notificações | UserNotifications |
| Integração com o sistema | App Intents "clássicos" (App Schemas avaliados e descartados — sem fit para o domínio, ver seção 7) |
| IA | Foundation Models framework (on-device) |
| Automação | Shortcuts, via os App Intents expostos |
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

## 7. Em aberto

- [x] **Tom padrão das mensagens geradas: fixo por `relationship`.** Decidido na T10 (`AISuggestionService.tone(for:)`): `.partner`/`.family` → carinhoso, `.friend` → engraçado, `.colleague`/`.other`/nil → formal. `type == .memorial` sempre sobrepõe para tom reflexivo, independente do `relationship`. Não configurável pelo usuário no MVP.
- [ ] Limite de datas antes de precisar de paginação/busca na UI (decidir se surgir necessidade; fora do MVP por ora)
- [x] **App Schemas: não aplicável.** Avaliado na T5 (api-scout, SDK iOS 26.4): o namespace `AppIntents.AssistantSchemas` só cobre os domínios `Books`, `Browser`, `Camera`, `Files`, `Journal`, `Mail`, `Photos`, `Presentation`, `Reader`, `Spreadsheet`, `System`, `VisualIntelligence`, `Whiteboard`, `WordProcessor` — nenhum schema para lembretes, tarefas, calendário ou datas. Marco segue com App Intents "clássicos" (custom), como a spec já assumia.
- **Limitação de ambiente — geração real do Foundation Models não verificável neste Mac (T11):** `sim-verifier` confirmou `SystemLanguageModel.default.availability == .available` no host de desenvolvimento, mas toda chamada de `respond` falha em runtime por um erro de infraestrutura do próprio framework (guardrail/safety checker: `DecodingError.keyNotFound("thoughtContents")`, provável mismatch entre assets do modelo e o simulador iOS 26.4 usados neste host) — não é um bug do código do Marco. A UI da T11 trata esse erro graciosamente (mensagem em pt-BR, sem crash), mas nem o caminho de sucesso (resultado + copiar) nem o caminho de indisponibilidade genuína (`.unavailable`) puderam ser exercitados neste ambiente. Repetir manualmente em um Mac com Apple Intelligence/assets íntegros antes de considerar a funcionalidade de IA validada ponta a ponta.

- **Decisão T2 — 29/02 sem ano bissexto:** a "próxima ocorrência" de uma data em 29/02 não é normalizada para 28/02 ou 01/03; avança até o próximo ano bissexto (`ImportantDate.nextOccurrence`). Coberta por testes. Impacto a considerar na T4: notificações de aniversário 29/02 só disparam a cada 4 anos — avaliar se isso é o comportamento desejado ou se merece tratamento de UX próprio.
