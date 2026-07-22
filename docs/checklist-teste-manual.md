# Checklist de teste manual — Marco (iPhone + Watch)

Baseado nas funcionalidades da SPEC.md (seção 3) e nos achados/ressalvas da seção 7.
Marque `[x]` conforme for validando no aparelho físico.

## 1. Lista e CRUD de datas (T3)

- [x] Lista abre vazia no primeiro uso, com empty state e botão de ação
- [x] Criar data: todos os campos (nome, data, tipo, relacionamento, notas) salvam corretamente
- [x] Lista ordena por proximidade ("faltam N dias" correto para cada item)
- [x] Editar uma data existente reflete na lista imediatamente
- [x] Excluir por swipe remove o item e não reaparece ao reabrir o app
- [] Rotação/Dynamic Type: aumentar o tamanho da fonte (Ajustes → Acessibilidade) não quebra o layout da lista nem do formulário
- [x] Dark mode: lista, formulário e detalhe legíveis nos dois modos

## 2. Aniversário sem ano / hora por data / idade (T13–T15)

- [x] Criar tipo "aniversário" mostra seletor só de dia/mês (sem ano obrigatório)
- [x] Preencher "ano de nascimento" (opcional) faz a idade aparecer na lista/detalhe ("faz N anos")
- [x] Deixar ano em branco: nenhuma idade é exibida, sem crash
- [x] Caso especial: cadastrar aniversário em 29/02 e conferir que salva e mostra "faltam N dias" plausível
- [x] Mudar a hora do lembrete (`DatePicker` hora/minuto) no formulário e conferir que persiste ao reabrir a data
- [x] Tipos não-aniversário (comemorativa, memorial) continuam pedindo data completa (dia/mês/ano)

## 3. Notificações locais (T4)

- [x] Primeira ação que dispara notificação pede permissão (não no launch do app)
- [x] Criar uma data agenda as 3 notificações (checar em Ajustes → Notificações → Marco, ou aguardar disparo)
- [x] Editar a data (mudar dia ou hora) reagenda as notificações — a antiga não dispara mais
- [x] Excluir a data cancela as notificações pendentes
- [x] Notificação "no dia" chega na hora configurada para aquela data específica (não um horário fixo global)

## 4. Notificações interativas (T22)

- [x] Notificação exibe as ações "Adiar" e "Abrir para mensagem" (long-press ou swipe na notificação)
- [] "Adiar" reagenda a notificação para um horário próximo (conferir que chega de novo depois)
- [x] "Abrir para mensagem" leva direto à tela de detalhe da data correspondente
- [x] Tocar no corpo da notificação (sem escolher ação) também abre o app corretamente

## 5. Siri / App Intents (T5–T8)

> Toda frase precisa citar **"no Marco"** explicitamente — sem o nome do app, a Siri roteia para o domínio genérico do sistema (Calendário/Lembretes) em vez do intent do Marco. Se mesmo assim não funcionar: checar Ajustes → Siri e Busca → Marco → "Usar com Perguntar à Siri" ligado, Ajustes → Siri e Busca → Idioma = Português (Brasil), e tentar de novo depois de alguns minutos (índice do sistema pode não ter atualizado logo após instalar via Xcode).

- [] Perguntar à Siri "Quais datas estão chegando no Marco" — responde com as datas reais do banco
- [] Perguntar "Quanto falta para o aniversário de [nome] no Marco?" — resolve a entidade certa e responde os dias corretos (frase parametrizada é a mais frágil por voz — se falhar, testar tocando o atalho direto no app Atalhos pra isolar se é a Siri ou o intent)
- [] Testar com nome ambíguo/inexistente — não crasha, dá resposta sensata
- [] Pedir "Adicionar data no Marco" — completa nome/data via prompt de parâmetro, cria a data e ela aparece na lista do app depois
- [] Perguntar "Quem faz aniversário esse mês no Marco?" — retorna só aniversários (não comemorativas/memoriais) do mês corrente
- [] Abrir o app Atalhos → aba Galeria/App → os 4 intents do Marco aparecem para montar automations

## 6. Foundation Models / sugestões de IA (T10, T11)

> Nota da SPEC (seção 7): neste Mac de desenvolvimento a geração real falhou por um erro de infraestrutura do framework (não é bug do Marco). Testar num dispositivo/Mac com Apple Intelligence funcionando é o que falta validar de fato.

- [ ] Detalhe de uma data **com** notas preenchidas mostra o botão "Sugerir presente"; **sem** notas, o botão não aparece
- [ ] "Sugerir presente" mostra loading e depois um resultado (título + justificativa) — ou mensagem de erro em pt-BR sem crash
- [ ] "Gerar mensagem" produz texto compatível com o relacionamento (ex: carinhoso p/ família, engraçado p/ amigo, formal p/ colega)
- [ ] Para uma data do tipo "memorial", a mensagem gerada tem tom reflexivo (não sugestão de presente)
- [ ] Resultado tem botão de copiar e o texto vai mesmo para a área de transferência
- [ ] Se o modelo estiver indisponível no aparelho, a UI esconde/desabilita os botões com explicação (não trava)

## 7. Importação de Contatos/EventKit (T16–T18)

- [ ] Empty state da lista tem botão "Importar" (ou similar) além do item de menu na toolbar
- [ ] Tocar em importar só pede permissão de Contatos/Calendário nesse momento (não antes)
- [ ] Tela de revisão mostra candidatos agrupados por fonte (Contatos / Calendário), com checkboxes pré-marcados
- [ ] Desmarcar um candidato e confirmar importação: só os marcados viram `ImportantDate` na lista
- [ ] Datas já existentes no app (mesmo nome + dia/mês) aparecem marcadas/ocultas como já importadas (dedupe)
- [ ] Reexecutar a importação depois não duplica os itens já importados
- [ ] Aniversário de contato com ano preenchido traz o `birthYear` (idade aparece depois na lista)
- [ ] Negar a permissão não deixa o app travado ou em estado inconsistente

## 8. Widget (T20)

- [ ] Home screen: adicionar o widget "Marco" pequeno (`.systemSmall`) — mostra a próxima data e contagem
- [ ] Home screen: adicionar o widget médio (`.systemMedium`) — mostra a informação esperada
- [ ] Criar/editar/excluir uma data no app reflete no widget sem esperar horas (o app força reload)
- [ ] **Lock screen** (pendente de verificação segundo a SPEC — testar agora): Ajustes → toque longo no papel de parede → Personalizar → Adicionar Widgets → localizar "Marco" e testar as 3 famílias (`.accessoryCircular`, `.accessoryRectangular`, `.accessoryInline`)
- [ ] Widget não crasha nem mostra dado zerado quando não há datas cadastradas

## 9. Apple Watch (T21)

- [ ] Abrir o app `MarcoWatch` no relógio — lista de próximas datas aparece com dado real (sincronizado do iPhone)
- [ ] Criar/editar uma data no iPhone e verificar que a lista do Watch atualiza (pode levar alguns segundos, é `WatchConnectivity`)
- [ ] Adicionar a complication do Marco numa carátula — mostra a contagem da próxima data
- [ ] Testar a complication em mais de uma família/carátula, se possível (`.accessoryRectangular`, `.accessoryInline`, `.accessoryCorner` — a spec só verificou `.accessoryCircular` até agora)
- [ ] Excluir uma data no iPhone: ela some da lista do Watch e da complication (não fica "fantasma")
- [ ] Testar com o iPhone fora de alcance/Wi-Fi: o Watch mantém o último snapshot sincronizado sem crashar

## 10. Coisas gerais / regressão

- [ ] **App Group em dispositivo físico** (ressalva da SPEC seção 7): se o widget ou o Watch mostrarem tela vazia/crash só em dispositivo real (funcionava no simulador), o motivo provável é a capability "App Groups" não registrada via Xcode Signing & Capabilities — não é bug de lógica, é configuração de projeto
- [ ] Girar o aparelho (se a UI permitir orientação) não quebra nenhuma tela
- [ ] Todas as strings visíveis estão em pt-BR (sem texto de placeholder em inglês esquecido)
- [ ] Fechar e reabrir o app preserva os dados corretamente em todas as telas
- [ ] VoiceOver: navegar pela lista e formulário com VoiceOver ligado não trava em nenhum controle
