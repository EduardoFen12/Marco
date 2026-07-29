# Feature Specification: Markstone — Lembretes de Datas Importantes

**Feature Branch**: `001-markstone`

**Created**: 2026-07-29 (migrado do `SPEC.md` monolítico, escrito a partir de 2026-06)

**Status**: Entregue (T1–T43 concluídas; pendências abertas em `research.md`)

**Input**: App iOS de datas importantes (aniversários, datas comemorativas,
memoriais) com lembretes em camadas, consultas por voz via Siri, sugestões de IA
on-device, widget e Apple Watch. Projeto de aprendizado de App Intents,
Shortcuts e Foundation Models.

> **Nota de migração:** esta feature é retroativa — descreve o app que já
> existe. Trabalho novo entra como `specs/002-…`, `003-…` etc. Os IDs de task
> originais (`T1`–`T43`) foram preservados em `tasks.md` em vez de renumerados
> para `T001…`, porque `research.md` referencia dezenas deles pelo ID.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Guardar datas e ser lembrado (Priority: P1)

O usuário cadastra uma data importante (nome, dia, tipo, relação, notas,
foto opcional, hora do lembrete) e passa a ser avisado dela em três momentos:
uma semana antes, um dia antes e no dia. A lista inicial mostra as datas
ordenadas por proximidade, com "faltam N dias", e uma data em destaque.

**Why this priority**: é o app. Sem isso não existe produto — todo o resto
(Siri, IA, widget, Watch) são superfícies sobre este dado.

**Independent Test**: criar uma data no simulador, verificar que aparece na
lista com a contagem correta e que três notificações pendentes foram agendadas
na hora escolhida (`pendingNotificationRequests`).

**Acceptance Scenarios**:

1. **Given** o app sem nenhuma data, **When** o usuário cria "Mari — 12/03,
   aniversário", **Then** a data aparece na lista com "faltam N dias", nasce
   em destaque, e existem 3 notificações pendentes (7 dias antes, 1 dia antes,
   no dia) na hora configurada para ela.
2. **Given** uma data existente, **When** o usuário edita a data ou a hora do
   lembrete, **Then** as notificações são reagendadas com os novos valores e
   nenhuma pendência antiga sobra.
3. **Given** uma data existente, **When** o usuário exclui a data, **Then** ela
   some da lista e suas 3 notificações pendentes são canceladas.
4. **Given** um aniversário sem ano de nascimento, **When** o usuário salva,
   **Then** dia/mês são persistidos corretamente (inclusive 29/02) e nenhuma
   idade é exibida.

---

### User Story 2 - Perguntar para a Siri (Priority: P2)

O usuário consulta e cria datas por voz/Shortcuts, sem abrir o app: "quais
datas estão chegando no Markstone", "quanto falta para o aniversário da Mari no
Markstone", "quem faz aniversário esse mês no Markstone", "adicionar data no
Markstone".

**Why this priority**: é o objetivo de aprendizado declarado do projeto (os
dois padrões de App Intent — query read-only e escrita) e a superfície que
diferencia o app de uma lista qualquer.

**Independent Test**: os intents aparecem no app Shortcuts, aceitam seleção de
entidade e respondem com os dados reais do store.

**Acceptance Scenarios**:

1. **Given** datas cadastradas, **When** o usuário roda `UpcomingDatesIntent`,
   **Then** recebe as próximas datas com um dialog falável.
2. **Given** uma data chamada "Mari", **When** o usuário roda
   `DaysUntilDateIntent` selecionando essa entidade, **Then** o dialog informa
   os dias restantes corretos.
3. **Given** o app instalado, **When** o usuário roda `AddImportantDateIntent`
   preenchendo os prompts de parâmetro, **Then** a data é persistida no
   SwiftData, aparece na lista e tem notificações agendadas.
4. **Given** datas de vários tipos, **When** o usuário roda
   `BirthdaysThisMonthIntent`, **Then** só retornam `type == .birthday` do mês
   corrente.

---

### User Story 3 - Sugestões de IA on-device (Priority: P2)

Na tela de detalhe de uma data, o usuário pede uma **sugestão de presente**
(quando há notas de contexto) ou uma **mensagem personalizada**, geradas
localmente pelo Foundation Models, com tom ajustado à relação e ao tipo da data
(reflexivo para memoriais).

**Why this priority**: segundo objetivo de aprendizado do projeto; entrega
valor real, mas o app funciona inteiro sem ela.

**Independent Test**: abrir o detalhe de uma data com notas, tocar em "Sugerir
presente", ver o estado de loading e o resultado copiável; num device sem
modelo disponível, os botões somem/desabilitam com explicação e nada quebra.

**Acceptance Scenarios**:

1. **Given** uma data com `notes` preenchido e modelo disponível, **When** o
   usuário toca "Sugerir presente", **Then** vê loading e depois um resultado
   estruturado (título + justificativa) que pode copiar.
2. **Given** uma data sem `notes`, **When** o usuário abre o detalhe, **Then**
   o botão de sugestão de presente não é oferecido.
3. **Given** `type == .memorial`, **When** o usuário gera uma mensagem,
   **Then** o tom é reflexivo, não festivo, e não há sugestão de presente.
4. **Given** o modelo indisponível, **When** o usuário abre o detalhe,
   **Then** os recursos de IA degradam com explicação, sem crash.

---

### User Story 4 - Importar datas que o usuário já tem (Priority: P3)

Em vez de digitar tudo, o usuário importa aniversários dos Contatos e eventos
do Calendário — sempre por opt-in explícito, com tela de revisão e seleção.

**Why this priority**: reduz muito o atrito do primeiro uso, mas depende do
CRUD já existir.

**Independent Test**: tocar em "Importar…", conceder permissão, ver a lista de
candidatos agrupada por fonte com checkboxes pré-marcados, desmarcar alguns e
confirmar — só os selecionados viram `ImportantDate`.

**Acceptance Scenarios**:

1. **Given** contatos com aniversário, **When** o usuário importa, **Then** a
   tela de revisão lista os candidatos agrupados por fonte, sem repetir datas
   já salvas (mesmo nome + dia/mês).
2. **Given** candidatos revisados, **When** o usuário confirma, **Then** só os
   selecionados são criados, com notificações agendadas.
3. **Given** permissão negada, **When** o usuário tenta importar, **Then** o
   app explica e não trava.

---

### User Story 5 - Ver a próxima data sem abrir o app (Priority: P3)

Widget na home/lock screen do iPhone e lista + complication no Apple Watch
mostram a próxima data e a contagem regressiva.

**Why this priority**: superfície de valor contínuo, mas puramente derivada dos
dados já existentes.

**Independent Test**: com uma data cadastrada, o widget mostra o mesmo número
de dias da lista; alterar/excluir a data atualiza o widget sem esperar refresh
do sistema; o Watch mostra a mesma próxima data via sincronização.

**Acceptance Scenarios**:

1. **Given** datas no app, **When** o usuário adiciona o widget "próxima
   data", **Then** ele mostra a data mais próxima com a contagem correta.
2. **Given** o widget na tela, **When** o usuário cria/edita/exclui uma data,
   **Then** o widget reflete a mudança (recarga de timeline no ponto único de
   CRUD).
3. **Given** iPhone e Watch pareados, **When** o iPhone sincroniza, **Then** a
   lista do Watch e a complication mostram a mesma próxima data.

---

### User Story 6 - Encontrar uma data específica (Priority: P3)

Aba de busca dedicada, filtrando pelo nome, abrindo o mesmo detalhe/edição.

**Why this priority**: só importa quando o volume de datas cresce.

**Independent Test**: digitar parte de um nome na aba de busca e abrir o
resultado.

**Acceptance Scenarios**:

1. **Given** várias datas, **When** o usuário digita parte de um nome,
   **Then** só as correspondentes aparecem (respeitando acentuação e idioma).

---

### Edge Cases

- **29/02 sem ano bissexto:** a próxima ocorrência **não** é normalizada para
  28/02 ou 01/03 — avança até o próximo ano bissexto. Consequência aceita:
  notificações desses aniversários só disparam a cada 4 anos.
- **Aniversário sem ano de nascimento:** dia/mês são guardados contra o ano
  bissexto fixo 2000, para 29/02 ser representável; `birthYear` fica separado e
  só serve para idade.
- **Virada de ano:** uma data já passada neste ano conta para a ocorrência do
  ano seguinte.
- **Evento único (não anual) com data futura:** conta os dias até *aquele* ano,
  não até o próximo dia/mês — o caso "27/07/2027 → 0 DIAS" não pode acontecer.
- **Evento único já vencido:** fica escondido de todas as superfícies de
  leitura (Home, busca, entity, intents, widget, Watch), mas **continua no
  banco**. Hoje não há caminho de UI para reencontrá-lo — pendência registrada.
- **Modelo de IA indisponível** (device sem suporte, Apple Intelligence
  desligada, download pendente): a UI esconde/desabilita com explicação em
  pt-BR; nenhuma operação lança.
- **Permissões negadas** (notificações, Contatos, Calendário, Fotos): pedidas
  sob demanda, nunca no launch; recusa não impede o resto do app.
- **Data em destaque excluída:** nenhuma outra assume o destaque
  automaticamente — o usuário escolhe por long press.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: O app MUST persistir datas importantes com nome, data, tipo,
  relação opcional, notas opcionais, foto opcional, ano de nascimento opcional,
  hora do lembrete e hora do evento opcional.
- **FR-002**: O app MUST calcular a próxima ocorrência e os dias restantes de
  cada data, tratando virada de ano, 29/02 e eventos não-recorrentes.
- **FR-003**: O app MUST agendar 3 notificações locais por data (1 semana
  antes, 1 dia antes, no dia) na hora definida por aquela data, reagendando na
  edição e cancelando na exclusão.
- **FR-004**: As notificações MUST oferecer as ações "Adiar" e "Abrir para
  mensagem" (deep-link ao detalhe da data).
- **FR-005**: O app MUST pedir permissões (notificações, Contatos, Calendário,
  Fotos) sob demanda, nunca no launch.
- **FR-006**: O app MUST expor `ImportantDate` como `AppEntity` consultável e
  registrar frases de Siri via `AppShortcutsProvider`; **toda frase precisa
  citar o nome do app** ("no Markstone") ou a Siri não desambigua do domínio
  genérico do sistema.
- **FR-007**: O app MUST oferecer os intents de leitura (`UpcomingDatesIntent`,
  `DaysUntilDateIntent`, `BirthdaysThisMonthIntent`) e de escrita
  (`AddImportantDateIntent`), este último persistindo e agendando notificações
  pelo mesmo serviço do CRUD.
- **FR-008**: O app MUST gerar sugestão de presente (saída estruturada:
  título + justificativa) e mensagem personalizada **on-device**, com tom
  derivado da relação e sobreposto para reflexivo quando `type == .memorial`.
- **FR-009**: As operações de IA MUST retornar resultado ou erro de domínio
  (nunca lançar), com mensagens em pt-BR, para a UI degradar graciosamente.
- **FR-010**: A sugestão de presente MUST ser oferecida somente quando há notas,
  o modelo está disponível e o tipo não é memorial.
- **FR-011**: O app MUST importar aniversários de Contatos e eventos do
  Calendário por opt-in, com tela de revisão, agrupamento por fonte, seleção
  individual e dedupe contra datas já salvas (mesmo nome + dia/mês).
- **FR-012**: O app MUST manter exatamente uma data em destaque; a primeira
  data criada num store vazio nasce em destaque, e a exclusão do destaque não
  promove outra automaticamente.
- **FR-013**: O app MUST compartilhar o store SwiftData com a extensão de
  widget via App Group no mesmo dispositivo, e sincronizar com o Apple Watch
  via `WatchConnectivity` (App Group não atravessa dispositivos).
- **FR-014**: Widget e complication MUST refletir criação/edição/exclusão sem
  esperar o refresh automático do sistema (recarga disparada no ponto único de
  CRUD).
- **FR-015**: O app MUST oferecer busca por nome numa aba dedicada, abrindo o
  mesmo detalhe/edição da lista.
- **FR-016**: Datas não-aniversário MUST poder ser marcadas como evento único
  (não anual), contando até o ano específico e notificando uma única vez;
  aniversários são sempre anuais.
- **FR-017**: Toda a UI MUST estar em pt-BR, com localização por String
  Catalog (incluindo as usage descriptions do Info.plist).

### Key Entities

- **ImportantDate** — a data importante em si: identidade estável (`UUID`,
  também usada pela `AppEntity`), nome, data, tipo, relação opcional, notas,
  ano de nascimento opcional, hora do lembrete, hora do evento opcional, foto
  opcional, marca de destaque, flag de recorrência anual e `createdAt`.
  Detalhamento completo em `data-model.md`.
- **DateType** — categoria da data (`.birthday`, `.commemorative`, `.memorial`,
  `.appointment`); dirige tom da IA, símbolo e cor da categoria.
- **Relationship** — vínculo opcional (`.partner`, `.family`, `.friend`,
  `.colleague`, `.other`); dirige o tom das mensagens geradas.
- **ImportCandidate** — candidato de importação (Contatos ou EventKit) antes de
  virar `ImportantDate`; alimenta a tela de revisão.
- **WatchDateSnapshot** — recorte `Codable` (id, nome, tipo, próxima
  ocorrência) enviado ao Watch; **não** é um `@Model` SwiftData.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Criar uma data pelo formulário leva menos de 30 segundos e exige
  apenas nome e data — todo o resto é opcional.
- **SC-002**: 100% das datas criadas (pelo app, por Siri ou por importação)
  têm suas 3 notificações agendadas na hora configurada.
- **SC-003**: Os quatro intents aparecem no app Shortcuts e respondem com os
  dados reais do store, sem setup manual do usuário.
- **SC-004**: Em device sem Foundation Models disponível, nenhuma tela quebra —
  os recursos de IA somem ou explicam a indisponibilidade.
- **SC-005**: Widget e complication mostram o mesmo número de dias que a lista
  do app após qualquer operação de CRUD, sem esperar refresh do sistema.
- **SC-006**: Nenhuma tela migrada para o design system usa hex hardcoded — a
  paleta vem toda de `DesignSystem/Assets.xcassets`.

## Assumptions

- Uso pessoal, volume pequeno de datas — não há paginação, e a busca cobre o
  caso de "encontrar uma específica". Limite antes de precisar paginar segue em
  aberto.
- Um único dispositivo por usuário: **não há sincronização iCloud/CloudKit**.
  O par iPhone↔Watch é resolvido por `WatchConnectivity`, não por store
  compartilhado.
- Datas são anuais por padrão; o caso não-recorrente é a exceção, e só para
  tipos que não sejam aniversário.
- O tom das mensagens geradas é fixo por relação (não configurável pelo
  usuário).
- Testes automatizados estão **fora de escopo** por decisão do projeto (ver
  constitution, princípio III); verificação é build limpo + evidência de
  runtime.
- Tamanhos de acessibilidade do Dynamic Type estão fora de escopo; os tamanhos
  padrão funcionam por herança dos estilos nativos de fonte.
- Foto no Watch está deferida (custo de payload via `WatchConnectivity`).
