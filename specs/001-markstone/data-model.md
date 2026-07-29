# Data Model: Markstone

**Feature**: `001-markstone` | **Fonte**: seção 2 do `SPEC.md` original (migrada verbatim)


Entidade central: `ImportantDate` (SwiftData `@Model`).

| Campo | Tipo | Notas |
|---|---|---|
| `id` | `UUID` | identidade estável (usada também pela `AppEntity`) |
| `name` | `String` | nome da pessoa/data (ex: "Mari", "Dia das Mães") |
| `date` | `Date` | a data do evento; para recorrentes, importa dia/mês (ano usado p/ idade quando aplicável) |
| `type` | `DateType` (enum) | `.birthday`, `.commemorative`, `.memorial`, `.appointment` |
| `relationship` | `Relationship?` (enum) | ex: `.partner`, `.family`, `.friend`, `.colleague`, `.other` — usado como contexto p/ IA |
| `notes` | `String?` | contexto livre (gostos, interesses) — habilita a sugestão de presente |
| `birthYear` | `Int?` | ano de nascimento (opcional; só p/ `type == .birthday`) — habilita cálculo de idade (T13) |
| `notificationHour` | `Int` | hora do lembrete desta data (default 9); vale para as 3 camadas (T13) |
| `notificationMinute` | `Int` | minuto do lembrete desta data (default 0) (T13) |
| `eventHour` | `Int?` | hora em que o evento em si acontece (ex: aniversário às 19h); opcional, `nil` = evento sem hora definida (default) — distinto de `notificationHour`, que só controla o lembrete (T26) |
| `eventMinute` | `Int?` | minuto do evento em si; opcional, junto com `eventHour` (T26) |
| `photoData` | `Data?` (`.externalStorage`) | foto opcional da pessoa/data, comprimida antes de gravar; exibida no card de destaque da Home e no header do form de edição (T30/T31) |
| `isFeatured` | `Bool` | marca a data em destaque na Home; exclusivo entre todas as datas — a 1ª data criada no store nasce `true` (T30) |
| `isAnnual` | `Bool` | `true` (default) = recorre todo ano; `false` = evento único, o ano da `date` conta (T43). `type == .birthday` é sempre anual |
| `createdAt` | `Date` | housekeeping |

Regras derivadas:

- **Próxima ocorrência**: datas são recorrentes anualmente; "quanto falta" e "datas chegando" são calculados sobre a próxima ocorrência (dia/mês) a partir de hoje.
- **Aniversários guardam dia/mês contra um ano bissexto fixo (2000)** no campo `date`, para que 29/02 seja representável independente de haver ou não `birthYear`. `birthYear` fica separado, só para idade (`age(on:)`). O ano de `date` é ignorado pela próxima ocorrência.
- **Idade**: `age(on:) -> Int?` retorna a idade na próxima ocorrência quando `birthYear` está preenchido; `nil` caso contrário (T13/T15).
- **Evento único** (`isAnnual == false`, T43): a próxima ocorrência é a própria
  `date` (com ano), não o próximo dia/mês. `isPast(from:calendar:)` — também
  exposta como propriedade `isPast` — é o predicado **único** de "evento único
  já vencido", usado por Home, busca, `ImportantDateEntity`, intents, widget e
  Watch para escondê-lo. A forma parametrizada existe porque o widget precisa
  avaliar contra a data da entry, não contra `.now`.
- Enums (`DateType`, `Relationship`) devem conformar a `Codable` e, quando expostos em intents, a `AppEnum`.

> O modelo acima é a proposta inicial; o sub-agente da task de modelo pode refinar nomes/tipos, mas mudanças estruturais (novos campos, novas entidades) devem voltar para revisão do orquestrador.

**Localização no projeto (desde T20):** `ImportantDate`, `DateType`, `Relationship` e `Persistence` (o `ModelContainer`) moraram em `Marco/Models`/`Marco/Services` até a T19, mas foram movidos para `Shared/` (pasta sincronizada, Xcode 16+) quando o widget (T20) passou a precisar compilar o mesmo código num target separado. `Marco/Models` não existe mais.

**Entidade derivada, só do lado Watch (T21):** `WatchDateSnapshot` (`WatchShared/WatchDateSnapshot.swift`) — `Codable` simples (`id`, `name`, `kind: WatchDateKind`, `nextOccurrence: Date`), **não é um `@Model` SwiftData**. É o formato serializado que o iPhone envia por `WatchConnectivity` (ver 3.6/3.7) e que o Watch persiste localmente; existe porque o Watch não pode abrir o `ModelContainer` do iPhone (App Group não atravessa dispositivos), então carrega só o subconjunto de dados que a lista e a complication precisam, não a entidade completa.

