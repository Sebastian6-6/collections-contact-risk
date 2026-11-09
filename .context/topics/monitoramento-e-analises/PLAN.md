# Plano — monitoramento e análises

## 1. Objetivo e base no enunciado

Responder à parte "Análise de Dados" do enunciado com dados reprodutíveis, sem painel (decisão do desenho). São
quatro frentes:
- detectar os problemas de ingestão e desenhar o monitoramento diário;
- validar e calibrar a régua contra o histórico de contatos;
- mostrar o valor do CNPJ;
- justificar a política de não-contatar.

Base no enunciado:
- **Detecção de anomalias:** investigar se houve problema de ingestão em algum dia, propor a normalização e, se
  aplicável, a arquitetura de um monitoramento diário automático ("uma das formas [...] é usar uma média móvel")
  (p. 1 e 2).
- **Validação da régua:** "evidenciar acertos, erros e pontos cegos" (p. 1). "Avalie a acurácia e a calibração da
  régua [...], identificando as variáveis com maior peso preditivo, os principais padrões de erro e propostas de
  ajuste" (p. 2).
- **Segmentação dos devedores elegíveis e estratégia de canais e mensagens por nível** (p. 2).
- **O que a base de CNPJ agrega à cobrança** (p. 2).
- **Critério de avaliação:** "soluções elegantes para monitoramento volumétrico e tratamento de anomalias sem
  complexidade desnecessária" (p. 4).

## 2. Decisões herdadas

- `AGENTS.md`: só `ROW_NUMBER()` e `SUM()` como funções de janela, sempre com `ROWS BETWEEN`; nenhuma linha que não
  exista na origem; "Colunas da gold".
- `arquitetura-solucao/STATE.md`:
  - os incidentes de entrega da etapa 1;
  - a sazonalidade semanal (fim de semana com cerca de 1/3 do volume);
  - sem painel, com as conclusões no README.
- Modelo gold e régua:
  - a estrela;
  - `ft_devedor_contato` com os sinais;
  - o corte temporal da validação (D5);
  - `lista_nao_contatar`;
  - `dim_empregador`.

## 3. Decisões abertas (para a aprovação única)

| # | Decisão | Proposta | Por quê |
|---|---|---|---|
| D1 | Granularidade do monitoramento | `ft_entrega_diaria`: uma linha por provedor × data de referência que **recebeu** pelo menos um arquivo diário. Os arquivos do mesmo dia (original e reenvio) são somados antes; a carga histórica fica fora. A linha traz os registros repetidos (`qt_registros_repetidos`, pelo hash por registro) e os atrasados (`qt_registros_atrasados`, com data de atualização anterior à entrega) | Um dia sem arquivo não pode virar linha (não existe na origem), por isso o buraco aparece como "dias desde a entrega anterior" na entrega seguinte. Somar por dia evita que um reenvio conte como uma entrega a mais na média, e os atrasados explicam o alfa de 23/09, que traz o dia 22 |
| D2 | Como detectar um dia sem arquivo sem `LAG` | `ROW_NUMBER()` por provedor, ordenado pela data, e junção da entrega *n* com a *n-1* | A convenção do case só permite `ROW_NUMBER()` e `SUM()`; esse padrão faz o papel do `LAG` dentro da regra |
| D3 | Média móvel | Primeiro a do enunciado: `CAST(SUM(qt) AS NUMERIC) / SUM(1)` (o `CAST` evita a diferença de divisão inteira entre PostgreSQL e DuckDB) nas 7 entregas anteriores (`ROWS BETWEEN 7 PRECEDING AND 1 PRECEDING`), com o desvio em `tx_desvio_volume`. Se a medição mostrar falso alarme de fim de semana, troca para a base do mesmo dia da semana nas 4 semanas anteriores | Começa simples, como pede o critério de avaliação, e só fica mais sofisticado se o número justificar |
| D4 | Alertas | `flag_alerta_volume`, `flag_dia_faltante`, `flag_reenvio`, `flag_mudanca_cabecalho` (o hash do cabeçalho muda) e `flag_qualidade` (taxa de linhas ilegíveis ou rejeitadas acima de um limiar que o analista define e documenta no passo 4.1, por exemplo o dobro da média móvel da própria taxa). Um teste singular do dbt com severidade `warn` dispara quando a entrega mais recente tem alerta | Cada incidente real de setembro tem um sinal próprio, e o alerta aproveita a infraestrutura de testes que já roda |
| D5 | Onde ficam as respostas analíticas | Datasets como views no schema `analises` (pasta `models/analises/`, testados; regra criada no tópico 3), mais consultas pontuais na pasta `analyses/` do dbt (compiladas, versionadas, nunca materializadas). O `docs/perfil-das-fontes.md` passa a ser regenerado por essas consultas | Fecha a pendência do desenho: o perfil consulta a própria silver, com uma única definição de normalização |
| D6 | Classes de desfecho | Contato certo (`pagamento`, `promessa_pagamento`, `entregue`, `lido`); terceiro ou contato errado (`numero_errado`, `nao_conhece_devedor`); risco (`reclamacao`); exclusão (`opt_out`, `falecido`); neutro (`sem_resposta`) | Separa o erro que expõe a dívida a um terceiro do simples não atendimento. O analista confirma a classe de `entregue` e `lido` no e-mail |

## 4. Sequência de execução

### 4.1 Monitoramento diário das entregas
- **Quem:** `analista-dados` (Opus 5.5 · high) especifica D1 a D4; `engenheiro-sql` (Sonnet 5.5 · medium) implementa.
- **Fazer:**
  1. `ft_entrega_diaria` com volume, linhas ilegíveis, rejeitados, novos documentos, os dias desde a entrega
     anterior (D2), a média móvel (D3) e os alertas (D4).
  2. O teste singular de alerta.
- **Pronto quando:** os incidentes conhecidos de setembro aparecem como alerta:
  - alfa sem 09-22;
  - beta sem 09-24 e 09-25;
  - beta de 29/09 repetindo registros do dia 28;
  - gama truncada em 09-15 e o reenvio;
  - mudança de cabeçalho do alfa em 09-12.

  A contagem de alertas verdadeiros e falsos também precisa estar registrada.
- **Commit:** `feat: monitoramento diário das entregas com média móvel e alertas`, com o corpo trazendo quantos
  incidentes conhecidos foram detectados e quantos alertas falsos sobraram.
- **Se a medição mostrar falso alarme sazonal**, um `fix:`: `fix: base do mesmo dia da semana evita alarme falso de fim
  de semana`, com "Ganho medido: alertas falsos de X para Y, sem perder nenhum incidente conhecido".

### 4.2 Investigação e arquitetura do monitoramento
- **Quem:** `analista-dados` (Opus 5.5 · high).
- **Fazer:** `docs/monitoramento.md` com:
  - o que aconteceu em cada dia com problema e como a pipeline normaliza cada caso (chegada atrasada, reenvio,
    arquivo truncado, dia perdido, mudança de esquema, coorte com data padrão de 2025-09-01);
  - a arquitetura do monitoramento automático: execução diária agendada → `dbt build` → teste de alerta → notificação.
    O documento diz o que já roda e o que ficaria para produção.
- **Commit:** `docs: investigação das entregas e arquitetura do monitoramento diário` — responde à pergunta do enunciado
  sobre o dia com problema e mostra como o mesmo mecanismo passaria a avisar sozinho em produção.

### 4.3 Datasets de validação e calibração da régua
- **Quem:** `analista-dados` especifica; `engenheiro-sql` (Sonnet 5.5 · medium) implementa.
- **Fazer:**
  - `validacao_regua`: cada tentativa depois da data de corte D, com o nível do par devedor × contato calculado pela
    macro `regua_de_risco(D)` do tópico 3 (o corte único de D5, sem reimplementar os sinais) e a classe do
    desfecho (D6).
  - `calibracao_regua`: a matriz nível × classe de desfecho (a medida de acurácia) e, por nível, a quantidade de
    tentativas e as taxas de contato certo, terceiro, reclamação e exclusão.
  - `falsos_bloqueios`: tentativas em pares `bloqueado` ou `atencao` que terminaram em contato certo, ou seja, o
    custo da régua para a cobrança.
  - `peso_dos_sinais`: para cada sinal, a taxa de contato com terceiro com e sem o sinal e a razão entre as duas.
  - `pontos_cegos`: tentativas `liberado` que terminaram em terceiro ou reclamação.
  - `segmentacao_devedores`: devedores elegíveis por nível e canal disponível.
- **Pronto quando:** os datasets têm testes, e as taxas batem com uma conferência feita por fora em uma amostra.
- **Commit:** `feat: datasets de validação e calibração da régua` — mostra, com o corte temporal, onde a régua acerta,
  onde ela deixa passar um terceiro e onde ela bloqueia quem podia ser contatado.

### 4.4 Calibração da régua
- **Quem:** `analista-dados` (Opus 5.5 · high) interpreta e propõe; `engenheiro-sql` aplica.
- **Fazer:** ler acertos, erros e pontos cegos; identificar os sinais de maior peso; propor ajustes. Cada ajuste
  aplicado é medido antes e depois, com o mesmo corte temporal:
  - a taxa de terceiro entre os `liberado`;
  - o alcance de cobrança, ou seja, a fração de devedores com pelo menos um contato `liberado`.
- **Pronto quando:** o ajuste melhora a proteção a terceiros sem derrubar o alcance além do aceitável, com os dois
  números explícitos (o equilíbrio que o critério de avaliação pede).
- **Commit:** `fix: calibração da régua com base no histórico de contatos`, com o corpo no formato "Ganho medido:
  contato com terceiro entre os liberados de X% para Y%; alcance de A% para B% (corte temporal em <data>)".

### 4.5 Valor do CNPJ, perfil regenerado e respostas pontuais
- **Quem:** `analista-dados` (Opus 5.5 · medium); `engenheiro-sql` para as consultas.
- **Fazer:**
  1. Medir o que o CNPJ acrescenta:
     - vínculo com empresa baixada ou inapta (vínculo desatualizado);
     - setor e porte para a estratégia de canal;
     - CNPJ que não existe;
     - comparação entre devedores com e sem vínculo válido.
  2. Consultas em `analyses/` que regeneram os números de `docs/perfil-das-fontes.md` a partir da silver.
- **Commit:** `docs: perfil das fontes regenerado pela pipeline e valor do CNPJ`.

### 4.6 Conclusões das análises
- **Quem:** `analista-dados` (Opus 5.5 · high).
- **Fazer:** `docs/analises.md` com:
  - as respostas a cada item da "Análise de Dados";
  - a política de salvaguardas justificada com os números;
  - a estratégia de canais e mensagens por nível;
  - os limites de cada inferência (dados sintéticos, um mês de histórico, desfechos que dependem do canal).

  É a base das conclusões do README.
- **Commit:** `docs: conclusões das análises, política de não-contatar e estratégia por nível`.

### 4.7 Revisão e fechamento
- **Quem:** `revisor` (Opus 5.5 · medium) e `verificador` (Haiku 5.5 · low).
- **Fazer:**
  1. Correções da revisão como commits próprios (plano mestre, seção 5).
  2. Merge `--no-ff` com `chore: integra monitoramento-e-analises na develop`.
  3. `/c save` e capítulo 4 do storytelling.

## 5. Ganhos a medir

| O quê | Como | Onde entra |
|---|---|---|
| Incidentes conhecidos detectados e alertas falsos | `ft_entrega_diaria` × lista de incidentes da etapa 1 | commits 4.1 e o `fix:` sazonal |
| Taxa de terceiro entre os `liberado` e alcance, antes e depois da calibração | `calibracao_regua` com corte temporal | commit 4.4 |
| Peso de cada sinal | `peso_dos_sinais` | `docs/analises.md` e README |
| O que o CNPJ muda na decisão de contato | consultas do 4.5 | `docs/analises.md` |

## 6. Riscos e plano B

| Risco | Plano B |
|---|---|
| Um mês de histórico gera amostras pequenas por sinal | mostrar as quantidades junto das taxas e tratar o resultado como indício, nos limites |
| Corte temporal deixa pouca tentativa para validar | testar dois cortes e mostrar a estabilidade do resultado |
| Calibração melhora uma métrica e piora a outra demais | apresentar o trade-off e a escolha, sem esconder a perda |

## 7. Pronto do tópico e capítulo do storytelling

**Pronto:**
- todo item da "Análise de Dados" respondido com números reprodutíveis;
- monitoramento detectando os incidentes conhecidos;
- régua calibrada com o ganho medido;
- `verificador` verde;
- merge na `develop`.

**Capítulo "Provar que a régua funciona":**
- os dias com problema;
- a média móvel e a sazonalidade;
- os acertos, os erros e os pontos cegos;
- o ajuste e o seu custo.
