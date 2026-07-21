# Automation "Resumo da manhã"

Passo a passo para montar, no app **Atalhos** (Shortcuts), uma automação pessoal que roda todo dia de manhã e lê/mostra um resumo das datas importantes que estão chegando, usando a ação **Datas chegando** do Marco (`UpcomingDatesIntent`).

## Por que o intent já é encadeável

`UpcomingDatesIntent.perform()` retorna:

```swift
some IntentResult & ReturnsValue<[ImportantDateEntity]> & ProvidesDialog
```

- `ReturnsValue<[ImportantDateEntity]>` — o resultado da ação no Atalhos é uma **lista de itens** (`ImportantDateEntity`), disponível como variável mágica para as ações seguintes (igual a qualquer ação nativa que devolve uma lista de contatos, eventos, etc.).
- `ImportantDateEntity` conforma a `AppEntity` com `displayRepresentation` (título = nome, subtítulo = "Hoje" / "Amanhã" / "Faltam N dias"), então cada item aparece com um texto legível quando inserido diretamente numa ação de texto.
- Os campos `name` (`String`) e `daysUntilNextOccurrence` (`Int`) são propriedades simples da entidade, então o Atalhos também os expõe individualmente quando você usa **Repetir com Cada Item** e toca na variável "Item" (aparecem como "Name" / "Days Until Next Occurrence" — o Atalhos ainda não localiza nomes de propriedades de entidades de apps de terceiros para pt-BR; isso é uma limitação do framework, não do Marco).
- `ProvidesDialog` só é falado automaticamente quando o intent é **invocado por voz via Siri** ("Datas chegando no Marco"). Numa automação silenciosa (trigger "Hora do Dia"), o dialog não é lido sozinho — por isso a automação abaixo adiciona uma ação explícita de "Falar Texto" / "Mostrar Notificação" a partir do valor retornado.

Nenhuma mudança de código foi necessária para a T9: a query já retorna um valor `AppEntity` encadeável desde a T5.

## Passo a passo — versão simples (usar o resultado direto)

1. Abra o app **Atalhos**.
2. Aba **Automação** → toque em **+** (canto superior direito) → **Criar Automação Pessoal**.
3. Escolha o trigger **Hora do Dia**. Defina o horário (ex: 8:00) e "Repetir: Diariamente". Toque em **Avançar**.
4. Toque em **Adicionar Ação**, busque **Marco** e escolha a ação **Datas chegando**.
5. Adicione a ação **Falar Texto**. Toque no campo de texto da ação e insira a variável mágica **"Datas chegando"** (o resultado da ação anterior) — o Atalhos monta automaticamente uma lista textual usando o `displayRepresentation` de cada `ImportantDateEntity` (ex: "Mari, Faltam 3 dias; Dia das Mães, Faltam 12 dias").
6. Toque em **Avançar** e depois **Concluir**.
7. Nas configurações da automação, desative **Perguntar Antes de Executar** para que ela rode sozinha de manhã sem precisar de confirmação manual.

## Passo a passo — versão customizada (resumo mais natural)

Para um resumo com frase mais natural em vez da lista bruta de `displayRepresentation`:

1. Repita os passos 1–4 acima (trigger + ação **Datas chegando**).
2. Adicione a ação **Repetir com Cada Item**, usando como entrada a variável **"Datas chegando"** (a lista retornada pelo intent).
3. Dentro do bloco de repetição, adicione a ação **Texto** com algo como:
   `Item` — `está chegando (` `Days Until Next Occurrence` `dias)`
   (toque nos campos e insira as variáveis "Item" → "Name" e "Item" → "Days Until Next Occurrence" a partir do menu de variáveis).
4. Feche o bloco de repetição e adicione a ação **Combinar Texto**, com entrada = variável de saída do **Repetir com Cada Item** (lista de textos gerados no passo 3) e separador **Nova Linha**.
5. Adicione **Falar Texto** (ou **Mostrar Notificação**, se preferir só visual) usando o texto combinado do passo 4 como entrada.
6. **Avançar** → **Concluir** → desative **Perguntar Antes de Executar**.

## Validação manual (aparelho/simulador)

1. Cadastre 1–2 datas no app Marco (ex: uma daqui a 3 dias, outra daqui a 12 dias) para ter conteúdo no resumo.
2. Monte a automação (versão simples ou customizada) seguindo os passos acima.
3. Toque nos três pontos da automação → **Executar** (ou aguarde o horário configurado).
4. Confirme que a fala/notificação reflete as datas cadastradas e a contagem de dias, e que a automação roda sem exigir confirmação manual (com "Perguntar Antes de Executar" desativado).
