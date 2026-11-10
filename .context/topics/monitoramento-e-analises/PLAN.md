# Plano — monitoramento e análises (etapas 8 e 9, aprovado em 2026-11-10)

Substitui o rascunho de 2026-11-09. Decisões aprovadas em bloco na rodada de fechamento (STATE.md, Decisions). A validação da régua e o loop de refinamento ficaram na gold (passos 4.7 e 4.7b); este tópico fica com o monitoramento, o valor do CNPJ, o perfil e as conclusões.

## 1. Base no enunciado
- Detecção de anomalias e qualidade na ingestão, normalização e monitoramento diário automático, "uma das formas [...] é usar uma média móvel" (p. 1–2).
- O que a base de CNPJ agrega à esteira de cobrança (p. 2).
- "Soluções elegantes para monitoramento volumétrico e tratamento de anomalias sem complexidade desnecessária" (p. 4).

## 2. Decisões
- **D1.** `gold_monitoramento.ft_entrega_diaria`: uma linha por provedor × data de referência com pelo menos um arquivo diário. A carga histórica fica fora; os arquivos do mesmo dia são somados.
- **D2.** Dia faltante: a entrega *n* é comparada com a *n−1* por `ROW_NUMBER()`, sem `LAG`. O resultado é `qt_dias_desde_entrega_anterior`.
- **D3.** Média móvel por tipo de dia (útil ou fim de semana) no `PARTITION BY`: `CAST(SUM(qt) AS NUMERIC) / SUM(1)` com `ROWS BETWEEN n PRECEDING AND 1 PRECEDING`. Medido com ±50%: a média simples de 7 entregas dá 13 alarmes falsos de fim de semana; a média por tipo de dia dá 0 e mantém os dois picos. A janela e o limiar são calibrados na execução.
- **D4.** Uma coluna por pergunta, sem flags (AGENTS.md, "Colunas da gold"): `situacao_volume` (`normal`, `acima`, `abaixo`, `sem_base`), `qt_arquivos` (reenvio quando > 1), `situacao_cabecalho` (`igual`, `mudou`), `qt_registros_repetidos`, `qt_registros_atrasados`, `qt_linhas_ilegiveis`, mais o volume e a média. Um teste singular com severidade `warn` olha a entrega mais recente.
- **D5.** Sem schema `analises`: as respostas são consultas em `analyses/` (G1 da gold). Os números de `docs/perfil-das-fontes.md` são regenerados a partir da silver, com a correção do reenvio da gama de 15/09 (311 registros, não 309).
- **Critério de aceite do monitoramento:** os 6 incidentes conhecidos aparecem:
  - alfa sem 22/09, e o 23/09 trazendo o dia 22;
  - beta sem 24 e 25/09;
  - beta de 29/09 repetindo registros do dia 28;
  - gama truncada em 15/09, com o reenvio;
  - cabeçalho do alfa mudando em 12/09 (`cpf` → `documento`).
  Os alarmes falsos são contados e informados.

## 3. Sequência
Branch `feat/monitoramento-e-analises` a partir da `develop`, depois do merge da gold. Os passos 8.1 e 8.2 não dependem do CNPJ; o 9.1 espera o merge do `enriquecimento-cnpj` (`git merge develop` antes).

### 8.1 Monitoramento diário
- **Quem:** `engenheiro-sql` (Sonnet 5.5 · high), com a skill qualidade-sql.
- **Fazer:** D1–D4, com o teste de alerta e testes unitários de D2 e D3.
- **Commit:** `feat: monitoramento diário das entregas com média por tipo de dia e alertas`, com os incidentes detectados e os alarmes falsos no corpo.

### 8.2 Investigação e arquitetura
- **Quem:** `analista-dados` (Opus 5.5 · medium).
- **Fazer:** `docs/monitoramento.md`:
  - o que aconteceu em cada dia com problema e como a pipeline normaliza cada caso (chegada atrasada, reenvio, truncamento, dia perdido, mudança de cabeçalho, data padrão 2025-09-01);
  - a arquitetura do monitoramento diário: execução agendada → `dbt build` → teste de alerta → notificação, separando o que já roda do que fica para produção.
- **Commit:** `docs: investigação das entregas e arquitetura do monitoramento diário`.

### 9.1 Valor do CNPJ e perfil regenerado
- **Quem:** `analista-dados` (Opus 5.5 · medium) especifica e interpreta; ele mesmo escreve as consultas em `analyses/`.
- **Fazer:**
  - vínculo com empresa baixada ou inapta;
  - CNPJ não encontrado;
  - setor e porte para a estratégia de canal;
  - taxa de contato com terceiro por situação da empresa, com as quantidades;
  - consultas que regeneram `docs/perfil-das-fontes.md`.
- **Commit:** `docs: perfil das fontes regenerado pela pipeline e valor do CNPJ`.

### 9.2 Conclusões
- **Quem:** `analista-dados` (Opus 5.5 · high).
- **Fazer:** `docs/analises.md`:
  - a resposta a cada item da "Análise de Dados", com os números do 4.7, do 4.7b, do 8.1 e do 9.1;
  - a política de salvaguardas justificada;
  - a estratégia de canais e mensagens por nível;
  - os limites de cada inferência.
  É a base das conclusões do README.
- **Commit:** `docs: conclusões das análises, política de não-contatar e estratégia por nível`.

### 9.3 Verificação em bloco e merge
- `verificador` APROVADO e `revisor` sem achado que bloqueie; cada achado vira um commit próprio. Depois, merge `--no-ff` com `chore: integra monitoramento-e-analises na develop`.

### 8.3 Alerta por e-mail (opcional, só depois da publicação, se sobrar tempo)
- **Quem:** `engenheiro-python` (Sonnet 5.5 · medium), branch `feat/alerta-por-email` a partir da `develop`.
- **Fazer:** do jeito mais simples possível. `scripts/notificar_falha.py`, com `smtplib` da biblioteca padrão, é chamado pelo `pipeline.py` quando a ingestão ou o dbt falham ou quando um teste falha ou avisa. A configuração do SMTP vem só de variáveis de ambiente, nunca do repositório. Teste com pytest contra um servidor SMTP falso local, sem envio real. Documentado em `docs/monitoramento.md` e no README.
- **Commit:** `feat: e-mail de alerta quando a pipeline falha`.
- O envio real depende de credenciais do dono, que só ele configura.

## 4. Quando chamar o dono
As mesmas condições do plano do `enriquecimento-cnpj`, seção 4. Um incidente conhecido que não aparece não é motivo para chamar: recalibre a janela ou o limiar e registre.

## 5. Regras de commit
As mesmas do plano do `enriquecimento-cnpj`, seção 5.
