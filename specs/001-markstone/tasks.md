---
description: "Task list for feature 001-markstone"
---

# Tasks: Markstone — Lembretes de Datas Importantes

**Input**: Design documents from `/specs/001-markstone/`

**Prerequisites**: `spec.md`, `plan.md`, `data-model.md`, `research.md`

**Tests**: fora de escopo por decisão do projeto (constitution, princípio III).
Verificação de cada task = `xcodebuild build` limpo + evidência de runtime do
`sim-verifier` quando o critério de aceite exigir comportamento observável.

## Formato

Cada task é atômica, tem critérios de aceite verificáveis e lista suas
dependências. Os **IDs originais `T1`–`T43` foram preservados** na migração
(em vez de renumerados para `T001…`) porque `research.md` referencia dezenas
deles pelo ID.

Mapa task → user story do `spec.md`: T1–T4, T13–T15, T26, T30–T35, T37–T40 →
**US1**; T5–T8 → **US2**; T10–T11, T23 → **US3**; T16–T18, T25 → **US4**;
T19–T22, T41–T42 → **US5**; T27, T36 → **US6**; T12, T24, T28–T29, T43 →
transversais. (Não existe T9 — o ID foi pulado no plano original.)

**Checkbox só é marcado pelo orquestrador**, depois de revisão aprovada — nunca
pelo sub-agente que implementou.

### Fase 1 — MVP (T1–T12)

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

- [x] **T20 — Widget (WidgetKit: home + lock screen)**
  Extensão WidgetKit com timeline de "próximas datas" (contagem regressiva), famílias de home e lock screen, lendo o store compartilhado; reusa `nextOccurrence`/`daysUntilNextOccurrence`.
  *Aceite:* widget mostra as próximas datas e atualiza a contagem no simulador. *Depende de:* T19, T5

- [x] **T21 — App Apple Watch (lista + complication)**
  Target watchOS: lista das próximas datas + complication de contagem regressiva na carátula, lendo o store compartilhado.
  *Aceite:* app do watch lista as datas; complication mostra a próxima. *Depende de:* T19

- [x] **T22 — Notificações interativas**
  `UNNotificationCategory` com ações "Adiar" (reagenda a curto prazo) e "Abrir para mensagem" (deep-link abre o detalhe da data p/ gerar mensagem via `AISuggestionService`). Delegate trata as ações.
  *Aceite:* notificação exibe as ações; "Adiar" reagenda; abrir leva ao detalhe. *Depende de:* T4, T10

- [x] **T23 — Esconder "Sugerir presente" em datas memorial**
  Achado no teste manual do checklist (item 6): `ImportantDateFormView.showsGiftSuggestion` só checa `notes`/disponibilidade do modelo, não `type`, então o botão de sugestão de presente aparece também para `type == .memorial` — inconsistente com a mensagem personalizada, que já troca para tom reflexivo nesse caso. Adicionar parâmetro `type: DateType` a `showsGiftSuggestion` e retornar `false` quando `type == .memorial`, independente de `notes`; ajustar o call site em `ImportantDateFormView`.
  *Aceite:* teste unitário cobrindo `type == .memorial` com `notes` preenchido e modelo disponível retorna `false`; demais casos (T11) continuam passando. *Depende de:* T11

- [x] **T24 — Localização: inglês + português**
  App hoje é 100% pt-BR hardcoded (strings literais nas views, dialogs de intent, conteúdo de notificação, widget e app do Watch). Migrar para String Catalog (`.xcstrings`, Xcode 15+) com localizações pt-BR (padrão/development region) e inglês, cobrindo todas as superfícies user-facing: `Marco/Views/`, dialogs/`IntentDialog` em `Marco/Intents/`, texto de notificação em `NotificationService`, `MarcoWidgets`, `MarcoWatch`/`MarcoWatchWidgets`. Rodar `api-scout` antes, dado o escopo amplo tocando praticamente todo arquivo com string visível.
  *Aceite:* app compila e roda corretamente com o idioma do dispositivo em Português (Brasil) e em English, sem string hardcoded remanescente nas superfícies listadas; comportamento pt-BR atual preservado como default. *Depende de:* T22

- [x] **T25 — Selecionar todos na tela de importação**
  Na tela de revisão de importação (T18, sheet com candidatos de Contatos/EventKit), adicionar um toggle "Selecionar todos" / "Desmarcar todos" que marca/desmarca de uma vez todos os candidatos elegíveis (candidatos já dedupados/ocultos como já importados não são afetados).
  *Aceite:* tocar o toggle marca todos os candidatos visíveis; tocar de novo desmarca todos; importar após "Selecionar todos" cria uma `ImportantDate` para cada candidato marcado, igual ao fluxo de seleção manual. *Depende de:* T18

- [x] **T26 — Modelo + UI: hora do evento**
  Em `ImportantDate`: novos campos opcionais `eventHour: Int?`/`eventMinute: Int?` — a hora em que o evento em si acontece (ex: aniversário às 19h), distinta de `notificationHour`/`notificationMinute` (T13), que continuam controlando só a hora do lembrete. `nil` em ambos = evento sem hora definida (comportamento atual, preservado como default). Em `ImportantDateFormView`: UI para definir opcionalmente a hora do evento (ex: toggle + `DatePicker(.hourAndMinute)` condicional). Exibir a hora, quando definida, na lista (`ImportantDateRow`) junto da data/dias restantes. Migração SwiftData leve (campos opcionais, default `nil`, sem afetar dados existentes).
  *Aceite:* criar/editar uma data com hora definida persiste `eventHour`/`eventMinute` e a lista passa a exibir "às HH:mm"; deixar sem hora mantém `nil` e a exibição atual inalterada; store existente migra sem quebrar; `notificationHour`/`notificationMinute` seguem controlando só os triggers de notificação, sem serem afetados por este campo. *Depende de:* T13

- [x] **T27 — Tab bar com aba de busca (conforme 3.8)**
  `ContentView` passa a expor uma `TabView` raiz com 2 abas: "Datas" (mover a `ImportantDateListView` atual para dentro de uma aba, sem alterar seu comportamento) e "Buscar" (view nova com `.searchable` sobre as `ImportantDate` existentes, filtrando por `name` via `localizedStandardContains`). Tocar um resultado na busca navega para `ImportantDateFormView` do mesmo jeito que a lista já faz (`navigationDestination(for: UUID.self)`), numa `NavigationStack` própria da aba. Rótulos das abas ("Datas"/"Buscar") e ícones (SF Symbols) adicionados ao `Localizable.xcstrings` (pt-BR + inglês) já na implementação, sem gerar débito de localização novo.
  *Aceite:* tab bar visível com 2 itens; digitar parte do nome na aba "Buscar" filtra os resultados em tempo real (vazio/parcial/sem match); tocar um resultado abre o formulário de edição da data correta; aba "Datas" mantém todo o comportamento atual (criar/editar/excluir/importar) sem regressão. *Depende de:* T3

- [x] **T28 — Finalizar localização (gaps abertos na T24)**
  Fecha os dois gaps registrados na seção 7 (achado do `spec-reviewer` na T24): (1) `AISuggestionService` (`giftPrompt`/`messagePrompt`, hoje fixos em "Responda em português"/"em português") passa a instruir o modelo a responder no idioma corrente do app (pt-BR ou inglês, os dois já suportados desde T24), com fallback para português se o idioma do dispositivo não for um dos dois suportados — comportamento isolável nas próprias funções `nonisolated static` (já puras, testáveis por locale sem sessão real). (2) `INFOPLIST_KEY_NSCalendarsFullAccessUsageDescription`/`INFOPLIST_KEY_NSContactsUsageDescription` (hoje hardcoded em pt-BR no `project.pbxproj`) migram para `InfoPlist.xcstrings` (String Catalog para Info.plist, Xcode 15+), com pt-BR (texto atual preservado como default) e inglês. Rodar `api-scout` antes, dado que `InfoPlist.xcstrings` é um mecanismo ainda não usado no projeto.
  *Aceite:* teste unitário cobre `giftPrompt`/`messagePrompt` gerando instrução em português para locale pt-BR e em inglês para locale en, com fallback para português em locale não suportado; diálogo de permissão de Contatos/Calendário (fluxo de Importar) aparece em português com o simulador em Português (Brasil) e em inglês com o simulador em English (verificável via `sim-verifier`); comportamento pt-BR atual preservado como default. *Depende de:* T24, T10

### Fase 3 — Redesign de UI (Figma, T29+)

> Redesign final das telas conforme mocks do Figma (ver seção 3.9). Mesmas regras da seção 5 (uma task por vez, pipeline SDD, checkbox só pelo orquestrador). Tasks tocando `project.pbxproj` (nenhuma prevista nesta fase) seguem o mesmo cuidado de merge das fases anteriores.

- [x] **T29 — Design system: cores da marca (light + dark) em Assets**
  Criar/atualizar color sets no `Assets.xcassets` para a paleta do redesign Figma, com variantes dark definidas (sem mock de referência para dark — usar critério de contraste HIG): manter `MarcosGreen` (`#54BBAB`) já existente e adicionar `MarcoDarkGreen` (`#006B5F`), `MarcoDeepGreen` (`#00483F`), `MarcoGray` (`#BDC9C5`), `MarcoCream` (`#FFF8EF`), `MarcoCardFill` (`#FAF3E6`), `MarcoBeige` (`#E9E2D5`), `MarcoMint` (`#A4F1E5`), `MarcoLabel` (`#1E1B14`), `MarcoLabelSecondary` (`#3D4946`). Ações destrutivas continuam usando `Color.red`/`.systemRed` nativo (não um color set custom).
  *Aceite:* color sets compilam e resolvem corretamente em light e dark (preview/simulador); nenhum hex hardcoded fora dos assets nas telas migradas por esta fase. *Depende de:* —

- [x] **T30 — Modelo: foto e data em destaque**
  Em `ImportantDate`: adicionar `@Attribute(.externalStorage) var photoData: Data?` (default `nil`) e `var isFeatured: Bool = false`, com a exclusividade garantida no ponto único de escrita (marcar uma data como destaque desmarca as demais). Quando o store estiver vazio, a próxima `ImportantDate` criada nasce `isFeatured = true` automaticamente; criações subsequentes nascem `false`. Migração leve do SwiftData.
  *Aceite:* testes cobrindo exclusividade do `isFeatured`, a 1ª data criada nascendo em destaque (store vazio) e as seguintes não, e round-trip de `photoData`; store existente migra sem quebrar. *Depende de:* —

- [x] **T31 — Foto: PhotosPicker no form de edição**
  Header de foto no `ImportantDateFormView` (banner ~192pt de altura, radius 32) usando `PhotosPicker` (PhotosUI) para escolher/trocar a foto, gravando em `photoData` após redimensionar/comprimir (não o arquivo bruto do picker). Sem foto definida, o banner mostra um estado vazio visualmente distinto (borda tracejada + ícone + texto "Adicionar foto", não um ícone de câmera sobreposto) deixando claro que é tocável; tocar no banner, com ou sem foto, abre o picker.
  *Aceite:* escolher foto persiste e reexibe; sem foto mostra o estado vazio tocável descrito acima; imagem gravada é comprimida. *Depende de:* T30

- [x] **T32 — Nova `ImportantDateDetailView` (read-only) + IA**
  Nova view read-only para o detalhe de uma data: header com anel de contagem regressiva (dias até a próxima ocorrência), nome/tipo/data (+ idade quando houver `birthYear`, T15), seção "Anotações" read-only, seção "Sugestões de IA" (reaproveita `AISuggestionService`: botões "Sugerir presente"/"Gerar mensagem", exibição do resultado, copiar para clipboard — sem imagem de produto, conforme 3.9), seção "Lembretes" read-only (hora do lembrete + hora do evento quando definida, T26). Toolbar default (back + título contextual com o nome da data + botão `pencil`) que dá push na `ImportantDateFormView` (edição). Vira o destino de navegação padrão ao tocar numa data (lista, destaque, resultado de busca) — a lista deixa de abrir direto o form de edição.
  *Aceite:* detalhe exibe os dados corretos, incl. idade quando aplicável; `pencil` abre a edição; botões de IA reaproveitam o comportamento existente (T11/T23) incl. esconder "Sugerir presente" em `.memorial`; notas/lembretes aparecem só quando preenchidos. *Depende de:* T30

- [x] **T33 — Redesenho da Home + card de destaque**
  Reestilizar `ImportantDateListView`: toolbar Compact/Large (título "Markstone", botão `+` com `Menu` "Adicionar data"/"Importar…" — substitui o item de menu "Importar…" da toolbar da T18); card de destaque no topo mostrando a `ImportantDate` com `isFeatured == true` (foto de fundo ou estado vazio quando sem foto, pill "DESTAQUE", nome/tipo/data grandes, dias faltantes); lista abaixo com células restilizadas (stripe de categoria à esquerda, dias à direita); swipe-to-delete mantido; long press numa célula (ou no destaque) oferece a ação "Marcar como destaque" (aplica a exclusividade de T30); toque em qualquer célula/destaque navega para `ImportantDateDetailView` (T32). Se a data em destaque for excluída, nenhuma fica em destaque automaticamente.
  *Aceite:* card de destaque mostra sempre a data `isFeatured == true` (ou nada, se nenhuma estiver marcada); long press marca uma nova data como destaque e desmarca a anterior; swipe exclui; toque abre o Detalhe; `Menu` do `+` oferece as 2 ações. *Depende de:* T30, T32

- [x] **T34 — Empty state dedicado**
  `ContentUnavailableView` estilizado (ilustração custom: calendário + sino + coração), título "Nenhuma data cadastrada", subtítulo "Toque em + para adicionar uma data importante", botão primário "Adicionar data" (abre o form de criação) + botão secundário "Importar…" (abre a tela de revisão de importação, T18). Mesma toolbar Compact/Large + `Menu` da T33.
  *Aceite:* aparece quando a lista está vazia; os 2 botões abrem os fluxos corretos; desaparece assim que a 1ª data é criada (que já nasce em destaque, T30). *Depende de:* T33

- [x] **T35 — Redesenho do form "Nova Data"/"Editar Data"**
  Reestilizar `ImportantDateFormView` com cards agrupados por seção (label flutuante): "Identificação" (nome), "Quando" (mantém a lógica atual — seletor completo p/ não-aniversário, dia/mês + ano opcional p/ aniversário, T14), "Lembretes" (horário do lembrete + toggle "Definir hora do evento" existente, T26 — ambos preservados), "Categoria" (segmented `DateType`), "Relacionamento" (chips `Relationship`, incl. opção "Nenhum"), "Anotações" (textarea). Header de foto (T31) no topo. Botão "Salvar" no rodapé além do `checkmark` do toolbar (mesma ação). Remove os botões de sugestão de IA deste form (movidos para o Detalhe, T32) — `showsGiftSuggestion` (T23) deixa de ser usado aqui. Toolbar default com título contextual ("Nova data"/"Editar data").
  *Aceite:* criar/editar persiste todos os campos existentes sem regressão (T13/T14/T23/T26); segmented = `DateType.allCases`; chips = `Relationship.allCases` + Nenhum; salvar funciona pelo botão do rodapé e pelo `checkmark` do toolbar. *Depende de:* T30, T31, T32

- [x] **T36 — Navegação: `Tab(role: .search)` substituindo a aba "Buscar"**
  Ajustar `ContentView` (T27): trocar o `TabView` de 2 abas convencionais ("Datas"/"Buscar") por uma aba "Datas" (Home) + uma aba com `role: .search` (pill de busca, canto direito), mantendo o mesmo comportamento de busca por nome (`.searchable`, `localizedStandardContains`) e passando a abrir `ImportantDateDetailView` ao tocar num resultado (não mais direto o form — T32). Telas empurradas a partir da Home (Detalhe, Edição, Nova Data) ocultam a tab bar (`.toolbar(.hidden, for: .tabBar)`), consistente com os mocks.
  *Aceite:* tab bar mostra só a Home + a pill de busca no canto; buscar filtra em tempo real e abre o Detalhe da data; tab bar não aparece nas telas de detalhe/edição/criação; comportamento de criar/editar/excluir/importar da Home permanece sem regressão. *Depende de:* T33, T32

- [x] **T37 — Polimento do form contra o mock "Nova Data" (`24:61`)**
  Três ajustes no `ImportantDateFormView`, conferidos contra o frame `24:61` do Figma:
  (a) **Label da seção passa a flutuar de fato acima do card.** Hoje `FormSectionCard` renderiza o `Text(label)` *dentro* do card (mesmo fundo `MarcoCardFill`, dentro do `padding(16)`) e em caixa alta via `.textCase(.uppercase)`. No mock a label fica **fora** do card, sobre o fundo da tela, em *sentence case* ("Identificação", não "IDENTIFICAÇÃO"), pequena e discreta. Mover o `Text` para fora do container que tem `background`/`clipShape` e remover o `.textCase(.uppercase)`. **Não** é floating label animado estilo Material — é label estática acima do card.
  (b) **Chips de "Relacionamento" quebram linha em vez de rolar.** Hoje é um `ScrollView(.horizontal)` numa fileira só; no mock os chips ocupam 2 linhas (linha 1: "Parceiro(a)/Cônjuge", "Família"; linha 2: "Amigo(a)", "Colega", "Outro"). SwiftUI não tem flow layout nativo — implementar via conformance ao protocolo `Layout` (iOS 16+), o mínimo que resolve. O chip "Nenhum" (decisão da seção 3.9, não presente no mock) continua existindo e entra no mesmo fluxo, totalizando 6 chips.
  (c) **`showsGiftSuggestion` sai de `ImportantDateFormView`.** A função `static` já não é usada pelo form desde a T35 e só sobreviveu ali porque `ImportantDateDetailView` a chama — mover para onde a regra pertence (`ImportantDate` ou `AISuggestionService`) e ajustar os call sites.
  *Aceite:* labels de seção aparecem acima dos cards em sentence case; chips de Relacionamento quebram em múltiplas linhas sem rolagem horizontal, com "Nenhum" incluído e seleção única funcionando (incl. gravar `nil`); `showsGiftSuggestion` não é mais membro de `ImportantDateFormView` e o Detalhe segue escondendo "Sugerir presente" em `.memorial`; criar/editar continua persistindo todos os campos sem regressão (T13/T14/T26). *Depende de:* T35
  *Fora do escopo (deltas do mock observados, decidir depois):* ícones à esquerda dentro dos campos (pessoa/calendário/sino); valores em pill teal à direita nos campos "Data"/"Horário"; pill "NOVO REGISTRO" sobre o header de foto; ícone no botão "Salvar" do rodapé.

- [x] **T38 — Detalhes visuais restantes do form (mock `24:61`)**
  Os quatro itens que a T37 deixou explicitamente de fora, todos em `ImportantDateFormView`, conferidos contra o frame `24:61`:
  (a) ícone à esquerda dentro dos campos — `person` no campo de nome, `calendar` na linha "Data", `bell` na linha "Horário";
  (b) o valor de "Data" e de "Horário" aparece como **pill teal** encostada à direita da linha (fundo `MarcoMint`/`MarcoCardFill`, texto `MarcoDarkGreen`), em vez do controle padrão alinhado à direita;
  (c) pill "NOVO REGISTRO" sobreposta ao canto inferior esquerdo do header de foto (só na criação — no modo edição não faz sentido);
  (d) ícone no botão "Salvar" do rodapé (o mock usa um ícone de salvar/disquete à esquerda do texto; escolher o SF Symbol mais próximo, ex. `square.and.arrow.down` ou `checkmark`).
  Em (b), **preservar o comportamento** dos controles: o `DatePicker` continua sendo o que edita o valor (T13/T14/T26) — a pill é a apresentação compacta dele (`.datePickerStyle(.compact)` já renderiza um campo com fundo próprio; avaliar se basta estilizar em vez de recriar o controle do zero, o que quebraria acessibilidade e teclado).
  *Aceite:* os 4 elementos aparecem conforme o mock, **com a exceção registrada abaixo**: a pill de "Data"/"Horário" tem fundo `MarcoMint`, mas o texto do valor permanece preto (limitação da API, ver seção 7) — o texto em `MarcoDarkGreen` só é exigido onde o controle é um `Picker`, não um `DatePicker`. Editar data e hora continua funcionando pelos controles nativos, sem regressão em T13/T14/T26; a pill "NOVO REGISTRO" só aparece na criação; os controles continuam com rótulo acessível (VoiceOver). *Depende de:* T37

- [x] **T39 — Células da lista como cards flutuantes (mock Home `13:5`)**
  Hoje as células de data são linhas de `List` padrão: `NavigationLink` com separador, inset do sistema e chevron de disclosure. O mock `13:5` mostra **cards brancos independentes**, com gap vertical entre eles, cantos arredondados (~16), **stripe vertical de categoria na borda esquerda**, sem separador e sem chevron. Layout interno de cada card: tipo da data em cima, pequeno e discreto ("Comemorativo"/"Memorial"/"Aniversário"); nome em destaque; subtítulo com a data ("15 de Junho", "02 de Julho • 10 anos"); e à direita o número de dias grande com "DIAS" embaixo. **A cor do número acompanha a categoria** (mesma cor do stripe) — no mock, memorial em cinza, aniversário em teal, comemorativa em verde escuro.
  **Abordagem recomendada:** manter o `List` e estilizar as linhas (`.listRowSeparator(.hidden)`, `.listRowBackground(Color.clear)`, `.listRowInsets`, `.scrollContentBackground(.hidden)` + o card desenhado dentro de `ImportantDateRow`), como já é feito hoje para o card de destaque. Isso entrega a aparência do mock **preservando o swipe-to-delete nativo** e a ordenação determinística corrigida na T33. Trocar por `ScrollView` + `LazyVStack` ("lista custom" literal) obrigaria a reimplementar swipe-to-delete na mão — regressão funcional que o aceite da T33 exige; só seguir por esse caminho se o `List` provar não dar conta de algum detalhe visual, e nesse caso registrar aqui o motivo.
  *Aceite:* células viram cards flutuantes com gap, stripe de categoria e número colorido por categoria, sem separador nem chevron, batendo com `13:5`; swipe-to-delete continua funcionando e excluindo a data correta (regressão da T33 não pode voltar); long press "Marcar como destaque" preservado; toque continua abrindo o Detalhe; card de destaque no topo permanece como está. *Depende de:* T33

- [x] **T40 — Redesenho da tela de Detalhe contra o mock "Detalhe da Data (IA)" (`24:159`)**
  A `ImportantDateDetailView` (T32) foi construída com `List` + `Section` padrão do sistema, antes do polimento visual que T37–T39 aplicaram às outras telas. Migrar para o mesmo vocabulário visual do resto da Fase 3 (fundo `MarcoCream`, cards `MarcoCardFill` com label estática em *sentence case* acima), conferido contra o frame `24:159`:
  (a) **Estrutura:** trocar o `List` por `ScrollView` + `VStack` sobre fundo `MarcoCream`, com as seções "Anotações", "Sugestões de IA" e "Lembretes" desenhadas como cards. **Reaproveitar o `FormSectionCard` da T37** (hoje `private` em `ImportantDateFormView`) — promover para arquivo próprio em `Marco/Views/` e usar nas duas telas, em vez de duplicar o componente. O label de "Sugestões de IA" leva um ícone `sparkles` à esquerda; o de "Lembretes" e "Anotações", nenhum.
  (b) **Header:** o anel de contagem regressiva fica maior e mais grosso, em `MarcoDarkGreen`, com o número e a palavra "DIAS" (caps, pequena) em `MarcoDarkGreen` no centro. Abaixo: nome em título grande e bold; linha do tipo com um SF Symbol da categoria à esquerda (`heart` para `.birthday` conforme o mock; `star` para `.commemorative` e `leaf` para `.memorial` — não existe mapeamento símbolo↔categoria hoje, a stripe da T39 é só cor, então criar o mapeamento em `DateType` e não numa view); e **uma única linha** juntando data e idade separadas por " • " ("31 de Maio • Faz 24 anos"), no padrão que `ImportantDateRow` já usa (`ImportantDateListView`, ~linha 335) — hoje o Detalhe mostra data e idade em duas linhas separadas.
  (c) **Botões de IA:** os dois botões viram cards lado a lado de mesma largura, ícone em cima e rótulo em caps embaixo — "SUGERIR PRESENTE" com fundo `MarcosGreen` (texto claro) e "GERAR MENSAGEM" com fundo `MarcoMint` (texto `MarcoDarkGreen`). Quando "Sugerir presente" está escondido (`.memorial`, T23/T37), "Gerar mensagem" ocupa a largura toda.
  (d) **Resultado da IA:** card `MarcoCardFill` com ícone de lâmpada em círculo à esquerda do título, título em bold, botão de copiar (`doc.on.doc`, só ícone) no canto superior direito e o texto do resultado abaixo. Continua **sem imagem de produto** (decisão da seção 3.9 — o mock mostra uma, deliberadamente ignorada).
  (e) **Toolbar:** botões de voltar e de editar como botões circulares (voltar em fundo claro, `pencil` em `MarcosGreen` com ícone branco).
  Sem mudança de comportamento: os botões de IA, o `pencil`, o esconder de "Sugerir presente" em `.memorial`, o copiar para clipboard e a exibição condicional de notas/lembretes seguem exatamente como na T32/T37.
  *Aceite:* a tela bate com `24:159` nos itens (a)–(e); `FormSectionCard` existe em um único lugar e é usado pelo form e pelo Detalhe (sem cópia); data e idade numa linha só; os dois botões de IA continuam disparando as mesmas ações e "Sugerir presente" continua sumindo em `.memorial`; copiar resultado continua funcionando; notas e hora do evento continuam aparecendo só quando preenchidas. *Depende de:* T32, T37
  *Divergência do mock a manter:* o título da navigation bar continua sendo o **nome da data** (T32), não a string "Marco" que aparece no mock.
  *Fora do escopo:* imagem de produto no card de resultado (item (d)); trocar o anel de progresso por um círculo fechado — o mock desenha o anel completo, mas o progresso ilustrativo da T32 fica como está.

### Fase 4 — Design system nas extensões (T41+)

O redesign da Fase 3 parou na fronteira do app iOS: `MarcoWatch`, `MarcoWatchWidgets` e `MarcoWidgets` continuam com a aparência default do sistema de T20/T21, escrita antes da T29. Duas restrições valem para as duas tasks abaixo e **não** devem ser tratadas como falha de implementação:

- **Não há mock Figma para Watch nem para widget.** O arquivo `Hoa6IMsdE7Nl8G1cnFxrml` só tem os quatro frames de iPhone (`13:5`, `17:501`, `24:61`, `24:159`). O critério destas tasks é *derivar* do vocabulário já estabelecido (paleta T29, cards com cantos arredondados, número grande + "DIAS" em caps, símbolo por categoria), não bater pixel a pixel com um frame. Se um mock específico surgir depois, ele vira task própria.
- **Superfícies `.accessory*` não aceitam a paleta.** Complications do Watch e widgets de lock screen do iPhone são renderizadas pelo sistema em modo vibrante/monocromático: a cor custom é desaturada ou ignorada, e `AccessoryWidgetBackground()` é o fundo que o sistema espera. Aplicar a paleta ali é impossível por design da plataforma — o trabalho de cor se concentra nas famílias `.systemSmall`/`.systemMedium` (widget de home screen) e na UI do app do Watch. Nas `.accessory*` o ganho possível é só de **layout e consistência de conteúdo** (mesmo rótulo, mesmo símbolo por categoria).

- [x] **T41 — Design system do redesign na UI do Apple Watch**
  `MarcoWatch/WatchDateListView.swift` (T21) é uma `List` default com `HStack` + `Image(systemName:)` cinza e `ContentUnavailableView` padrão — nenhum elemento do redesign. Migrar para o vocabulário da Fase 3, respeitando o que uma tela de ~184pt de largura comporta (não é a Home do iPhone encolhida):
  (a) **Paleta disponível no watchOS.** Os color sets da T29 vivem em `Marco/Assets.xcassets`, catálogo do target `Marco` — invisível para `MarcoWatch`/`MarcoWatchWidgets`. Levar a paleta para o lado watchOS **sem duplicar valores de hex à mão em dois lugares**, avaliando na ordem: (1) mover/copiar os color sets para um catálogo em `WatchShared/` (grupo já sincronizado com `Marco`, `MarcoWatch` e `MarcoWatchWidgets` — mas cuidado: nomes de color set duplicados entre dois catálogos do mesmo target geram ambiguidade, então se `Marco/Assets.xcassets` mantiver os mesmos nomes o conflito precisa ser resolvido movendo, não copiando); (2) `MarcoWatch/Assets.xcassets` (já existe) + membership no target `MarcoWatchWidgets` via exception set no `project.pbxproj`. Registrar aqui qual caminho foi tomado e por quê. `AppIcon`/`AccentColor` ficam onde estão.
  (b) **Lista:** células como cards arredondados sobre fundo escuro (no watchOS o fundo do sistema é preto — usar `MarcoDeepGreen`/`MarcoCardFill` conforme o contraste permitir, **não** forçar o `MarcoCream` claro do iPhone, que brigaria com a carátula e com o modo Always-On), com nome em destaque, dias restantes e o símbolo da categoria. Manter `List` (rotação da Digital Crown e scroll nativo) — não trocar por `ScrollView`.
  (c) **Empty state:** mesma mensagem de hoje ("Nenhuma data" / "Abra o Markstone no iPhone para sincronizar."), restilizada na paleta em vez do `ContentUnavailableView` cru, se o resultado couber na tela sem truncar.
  (d) **Complications (`MarcoWatchWidgets/NextDateComplication.swift`):** **sem mudança de cor** (ver restrição acima). O que muda: o símbolo da categoria passa a vir do mapeamento único do item (e), e o rótulo "dias" da família `.accessoryCircular` passa a caps ("DIAS"), alinhado ao número grande + "DIAS" que o app usa desde a T39/T40.
  (e) **Símbolo por categoria unificado.** Hoje existem **três** mapeamentos divergentes: `DateType.symbolName` no app (`heart`/`star`/`leaf`, T40), `WatchDateKind.symbolName` em `WatchShared/WatchDateSnapshot.swift` e uma `private extension DateType` em `MarcoWidgets/NextDateWidget.swift` (ambos `birthday.cake`/`star`/`flame`). Alinhar o lado watchOS ao mapeamento do app (`heart`/`star`/`leaf`) — `WatchDateKind` vive em `WatchShared/`, visível aos três alvos, então é o lugar natural da versão watchOS. O lado iOS é responsabilidade da T42.
  *Aceite:* lista e empty state do `MarcoWatch` usam a paleta da T29 (nenhum hex hardcoded), com cards legíveis num Series 10 (46mm) e sem texto truncado nos nomes de teste; `WatchDateKind.symbolName` bate com `DateType.symbolName` do app; complication `.accessoryCircular` mostra "DIAS" em caps; sincronização via `WatchConnectivity` e a complication continuam funcionando sem regressão (T21). *Depende de:* T29, T40
  *Fora do escopo:* foto no Watch (item deferido na seção 7 — `WatchDateSnapshot` continua sem `photoData`); cores nas famílias `.accessory*`; tela de detalhe no Watch (hoje não existe, e o snapshot não carrega dado para preenchê-la).
  *Caminho tomado no item (a) (registro exigido pela task):* opção (1) — os 10 color sets da T29 foram **movidos** (`git mv`, sem cópia, sem tocar `project.pbxproj`) de `Marco/Assets.xcassets` para o catálogo novo `WatchShared/Assets.xcassets`. Motivo: conferido no `project.pbxproj` que `WatchShared` é o **único** grupo sincronizado por `Marco`, `MarcoWatch` e `MarcoWatchWidgets` ao mesmo tempo (`Marco` → `Marco`+`Shared`+`WatchShared`; `MarcoWidgets` → `Shared`+`MarcoWidgets`; os dois do Watch → seu próprio grupo + `WatchShared`). `AppIcon`/`AccentColor` ficaram em `Marco/Assets.xcassets`. **Consequência para a T42:** `MarcoWidgets` não enxerga `WatchShared`, e nenhum grupo existente cobre os quatro alvos — a T42 precisa generalizar o local do catálogo (ver nota na própria T42).
  *Nota de implementação:* o nome no card do Watch ficou **sem `lineLimit`** (quebra em quantas linhas precisar, o card cresce e a `List` rola) em vez de um cap numérico com `minimumScaleFactor` — qualquer cap fixo volta a truncar no próximo nome mais longo, e o aceite pede explicitamente "sem texto truncado". Verificado em runtime com "Bisavô Waldomiro Nascimento" (2 linhas) e "Aniversário de Casamento da Vovó Terezinha Auxiliadora" (4 linhas), ambos completos.

- [x] **T42 — Design system do redesign no widget iOS**
  `MarcoWidgets/NextDateWidget.swift` (T20) usa `.containerBackground(.fill.tertiary)`, `.foregroundStyle(.secondary)` e tipografia default — escrito antes da T29. Migrar as famílias de home screen para a paleta e o layout do redesign:
  (a) **Paleta disponível no target.** ⚠️ **Este item ficou desatualizado com a T41** — o texto original (preservado abaixo) supunha a paleta ainda em `Marco/Assets.xcassets`. A T41 já a moveu para `WatchShared/Assets.xcassets`, e **nenhum grupo sincronizado existente é visto pelos quatro alvos**: `MarcoWidgets` vê `Shared` mas não `WatchShared`; os alvos do Watch veem `WatchShared` mas não `Shared`. Mover de novo para `Shared/` quebraria o Watch; adicionar `WatchShared` ao `MarcoWidgets` arrastaria `WatchDateSnapshot`/`WatchSnapshotStore` para dentro do widget iOS. **Caminho decidido:** criar um grupo novo `DesignSystem/` contendo **só** o catálogo de cores e registrá-lo como `PBXFileSystemSynchronizedRootGroup` dos quatro alvos (`Marco`, `MarcoWidgets`, `MarcoWatch`, `MarcoWatchWidgets`). É uma edição de `project.pbxproj` que a T42 teria que fazer de qualquer forma, e devolve `WatchShared/`/`Shared/` ao papel de conterem só código. *Texto original:* `Shared/` já é grupo sincronizado de `Marco` **e** `MarcoWidgets`, então mover os color sets da T29 de `Marco/Assets.xcassets` para um catálogo em `Shared/` resolve sem tocar no `project.pbxproj`. `AppIcon`/`AccentColor` permanecem em `Marco/Assets.xcassets`. Conferir que o app iOS continua resolvendo as cores após a mudança (as telas da Fase 3 usam `Color("MarcoX")` por nome, sem bundle explícito — o lookup precisa continuar achando no bundle do app).
  (b) **`.systemSmall`/`.systemMedium`:** fundo `MarcoCream` via `.containerBackground(_:for:)` (não `.fill.tertiary`), nome em destaque em `MarcoLabel`, número de dias grande em rounded bold com "DIAS" em caps embaixo na cor da categoria — o mesmo bloco visual de `ImportantDateRow` (T39) e do anel do Detalhe (T40) — e o símbolo da categoria. `.systemMedium` tem espaço para a data por extenso além do nome; `.systemSmall` prioriza número + nome.
  (c) **Estado vazio:** "Nenhuma data próxima" restilizado na paleta, em vez de texto `.secondary` cru.
  (d) **`.accessoryCircular`/`.accessoryRectangular`/`.accessoryInline`:** **sem mudança de cor** (ver restrição acima). Só alinhar o rótulo "dias" → "DIAS" em caps na `.accessoryCircular`, consistente com a T41(d).
  (e) **Símbolo por categoria:** apagar a `private extension DateType { var symbolName }` de `NextDateWidget.swift` e passar a usar o mapeamento único do app. `DateType.symbolName` está hoje em `Marco/Views/ImportantDateListView.swift` (target `Marco` apenas) — mover para `Shared/DateType.swift`, que já é visível aos dois alvos. Encerra o achado da seção 7 sobre ícones divergentes entre app e widget.
  *Aceite:* `.systemSmall` e `.systemMedium` renderizam na paleta da T29 (nenhum hex hardcoded, nenhum `.fill.tertiary`) com o bloco número + "DIAS" no padrão de T39/T40; existe **um único** `DateType.symbolName`, em `Shared/`, usado por app e widget; o app iOS continua resolvendo todas as cores após a mudança de catálogo; widget continua lendo o store compartilhado e atualizando via `WidgetCenter` sem regressão (T20). *Depende de:* T29, T40
  *Fora do escopo:* cores nas famílias `.accessory*`; foto da data no widget; widget configurável (`AppIntentConfiguration`) para escolher qual data mostrar — hoje é sempre a mais próxima.
  *Executado no item (a):* grupo novo `DesignSystem/` contendo só `Assets.xcassets`, registrado como `PBXFileSystemSynchronizedRootGroup` (ID `1BFBC3F0E53C225D7EA80F50`) nos quatro alvos. Diff do `project.pbxproj`: `+10 -0`. Confirmado por `assetutil --info` nos quatro produtos compilados (`Marco.app`, `MarcoWidgets.appex`, `MarcoWatch.app`, `MarcoWatchWidgets.appex`) que o catálogo linka em todos — não só que o `.pbxproj` abre. `Shared/` e `WatchShared/` voltaram a conter só código.
  *Movimentação extra necessária (fora do que a task previa):* `ImportantDate.dateLabel` também teve de sair de `Marco/Views/ImportantDateListView.swift` para `Shared/ImportantDate.swift` — a `.systemMedium` precisa da data por extenso e o widget não enxergava a extensão no target `Marco`. Mesmo padrão de `nextOccurrence`/`age(on:)`, que já moravam em `Shared/`.

### Fase 5 — Eventos não-recorrentes (T43+)

- [x] **T43 — Evento anual vs. evento único (data com ano que conta)**
  **Bug que originou a task:** o usuário criou um memorial datado no ano seguinte e o card mostrou "0 DIAS". Não é bug de exibição — `ImportantDate.nextOccurrence` (`Shared/ImportantDate.swift`) extrai só `.month`/`.day` de `date` e **descarta o ano**, porque o modelo assume que toda data é recorrente anual (seção 2, "Regras derivadas"). Com hoje sendo 27/07, uma data 27/07/2027 resolve para 27/07/2026 = hoje = 0 dias. A correção do bug e a feature pedida (switch "evento anual") são a mesma mudança: dar ao modelo o conceito de evento não-recorrente.

  (a) **Modelo.** Novo campo `isAnnual: Bool = true` em `ImportantDate` (default `true` → lightweight migration; **todo dado existente continua se comportando exatamente como hoje**). `nextOccurrence(from:calendar:)` passa a bifurcar: `isAnnual == true` mantém o cálculo atual (dia/mês, ignora ano, incl. a regra de 29/02 e do ano bissexto fixo 2000); `isAnnual == false` retorna o `startOfDay` do próprio `date`, **mesmo que já tenha passado** — daí `daysUntilNextOccurrence()` naturalmente devolver negativo para evento único vencido. `age(on:)` não muda (aniversário é sempre anual, ver (b)).

  (b) **Regra por tipo.** `type == .birthday` é **sempre** anual — a lógica de T13/T14 (dia/mês + ano de nascimento opcional, `birthYear` separado) fica intacta e o switch nem aparece no form. Os demais tipos (`.commemorative`, `.memorial`, `.appointment`) ganham a escolha.

  (c) **Form (`ImportantDateFormView`, card "Quando").** Para tipo não-aniversário, adicionar um `Toggle` "Evento anual", **desligado por default ao criar** (decisão do usuário; no modo edição vence o valor persistido). Ligado → esconder o ano e mostrar só dia/mês, reaproveitando os `Picker` de mês/dia do ramo aniversário (sem o campo "Ano de nascimento") e gravando `date` com a mesma convenção do ano bissexto fixo 2000, para 29/02 continuar representável. Desligado → o controle de data completo com ano que o ramo não-aniversário já usa hoje (`PillDatePicker(title: "Data", …, displayedComponents: .date)`). Manter o estilo visual de T37/T38 nos dois ramos.

  (d) **Notificações (`NotificationService.triggerSpecs`/`schedule`).** Anual → sem mudança (`DateComponents` de mês/dia + hora, `UNCalendarNotificationTrigger(repeats: true)`). Único → `DateComponents` **incluindo `.year`** e `repeats: false`, e **descartar as camadas cujo disparo já passou** (criar um evento para daqui a 3 dias não deve tentar agendar a camada "1 semana antes"). As 3 camadas, os identificadores determinísticos e o ponto único de CRUD em `cancel(_:center:)` (que recarrega widget e sincroniza o Watch) permanecem como estão.

  (e) **Eventos únicos vencidos ficam escondidos** (decisão do usuário). Definir **um único** predicado em `Shared/ImportantDate.swift` (ex. `var isPast: Bool { !isAnnual && daysUntilNextOccurrence() < 0 }` + um helper de filtro) e roteá-lo por **todas** as superfícies de leitura, em vez de repetir a condição em cada view: Home (`ImportantDateListView`, incl. o card de destaque — se a data em destaque estiver vencida, o card não aparece), aba de busca, `ImportantDateEntity.EntityQuery`, `UpcomingDatesIntent`, widget (`NextDateProvider`) e o snapshot enviado ao Watch (`WatchConnectivityService.sync`). `BirthdaysThisMonthIntent` não é afetado (só aniversário, sempre anual). Nada é excluído do banco — só filtrado da leitura.
  *Fica registrado como pendência (seção 7), não implementar agora:* filtro/aba "eventos que já passaram" para o usuário reencontrá-los.

  (f) **Detalhe.** `ImportantDateDetailView` não deve renderizar número negativo no anel: quando `isPast`, mostrar "Passou" no lugar do número + "DIAS". Caminho raro (a data já saiu da lista), mas é uma condição só.

  (g) **Criação fora do form fica anual.** `AddImportantDateIntent` e a importação de Contatos/EventKit (T16–T18) continuam criando com `isAnnual = true` — nenhum dos dois tem UI para a escolha, e importar um evento passado de calendário como "único" o esconderia no ato. Não adicionar parâmetro de intent nesta task.

  *Aceite:* uma data não-aniversário com o switch desligado e ano futuro mostra o número de dias correto até aquele ano (o caso "27 de julho de 2027 → 0 DIAS" deixa de acontecer) e notifica **uma vez só**; com o switch ligado, some o campo de ano, o comportamento anual atual é preservado (incl. 29/02) e as notificações repetem todo ano; aniversário não exibe o switch e não regride em T13/T14/T15; um evento único cuja data já passou desaparece da Home, da busca, do widget e do Watch sem ser excluído do banco; store existente migra com todas as datas como anuais e nenhuma mudança visível de comportamento. *Depende de:* T13, T26, T39, T42
  *Divergência de implementação (item (e)):* `isPast` ficou como propriedade **e** como função `isPast(from:calendar:)`, ambas roteando para o mesmo predicado. A forma parametrizada é exigida pelo widget: `NextDateProvider` pré-calcula uma janela de 7 dias e precisa avaliar "já passou" contra cada dia da janela, não só contra `.now` — sem isso, um evento único que vence dentro da janela ganharia o `.min` de "data mais próxima" com valor negativo nas entradas posteriores da mesma timeline.
  *Achado do `spec-reviewer`, corrigido antes do fecho:* o `onChange(of: isAnnual)` do form recompunha `date` via `birthdayDate(month:day:)` ao **desligar** o switch, e esse helper fixa o ano em 2000 (convenção correta só do ramo anual). Editar uma data anual existente e convertê-la em evento único gravaria `date` em 2000 → `isPast` imediato → a data sumiria da Home/busca/widget/Watch logo após ser salva, sem aviso. Corrigido para `ImportantDate.nextOccurrence(ofMonth:day:from:calendar:)`, que devolve a próxima ocorrência futura do mesmo dia/mês.
  *Evidência de runtime (`sim-verifier`, iPhone 17 / iOS 26.4):* memorial em 27/07/2027 com switch desligado mostra "365 DIAS" (`ZISANNUAL=0` conferido no SQLite do App Group); toggle esconde/mostra o campo de ano; aniversário não exibe o switch; evento único datado no passado some da Home e da busca com a linha ainda presente no store; notificações conferidas no unified log — evento único agendou 2 camadas com `Calendar Year` e `repeats: NO` (a camada "1 semana antes", já vencida, foi descartada), evento anual agendou 3 camadas sem ano e com `repeats: YES`. Não verificável por automação: o "Passou" do Detalhe (item (f)) — o próprio filtro de (e) remove o evento de toda superfície de navegação, então não há caminho de UI até ele; conferido só por leitura de código.


## Pendências promovíveis

Itens ainda abertos em `research.md`, prontos para virar task numerada quando
priorizados (nenhum está em execução):

- Filtro/aba para reencontrar eventos únicos vencidos (aberta pela T43).
- Contraste insuficiente de `.memorial` (`MarcoGray` sobre fundo claro, ≈1,6:1)
  quando `stripeColor` é usada como cor de **texto** — ajuste de paleta
  cross-cutting (achado da T42, herdado de T29/T39).
- Troca automática de aba ao abrir notificação estando em "Buscar" (achado da
  T27).
- Dedupe de candidatos de importação **entre si** (Contatos × EventKit), não só
  contra o que já está salvo (achado da T25).
- Chevron residual no card da aba Buscar (achado da T39).
- Foto no Watch (`WatchDateSnapshot` não leva `photoData`) — deferida na T30.
- Limite de datas antes de precisar de paginação.
- Ideias não priorizadas: iCloud/CloudKit, Live Activity para datas iminentes.
