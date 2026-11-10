# Plano — modelo gold e régua de risco de contato (refeito em 2026-11-10)

Decisões fechadas com o dono na sessão da etapa 6 (2026-11-09/10) e conferidas contra o contrato da silver na develop (2fb4b44, `docs/contratos-de-dados.md` §6). O enriquecimento por CNPJ (etapa 7) e o monitoramento da ingestão (etapa 8) ficam fora deste plano (seção 6). Detalhe das medições e das opções descartadas: `.context/topics/modelo-gold-e-regua/STATE.md` e `g3a-document-correction.md`.

## 1. Objetivo e base no enunciado

Unir as três fontes numa base cadastral única, num modelo dimensional, e aplicar a régua de risco a cada telefone e e-mail de cada devedor, com a lista de não-contatar.

- "Base cadastral única e confiável" com identificação, endereço, contatos e vínculo empregatício; régua "aplicável a cada telefone e e-mail de cada devedor", níveis e critérios a meu critério; o risco central é "contatar quem não deve" (p. 1).
- Canais e mensagens por nível, salvaguardas e justificativa dos sinais de bloqueio; validação contra o histórico de tentativas (p. 2).
- Avaliação: "consistência no tratamento de deduplicações, conflitos cadastrais e dados incompletos ou ruidosos", integridade referencial (p. 3); equilíbrio entre cobrança e proteção a terceiros, "limites das inferências" (p. 4).

## 2. Decisões

### Papel e forma da gold
- **G1. O critério é o grão.** A gold tem só tabelas `dim_` e `ft_` em que cada linha é uma entidade ou um evento derivado de registros recebidos, com as regras de negócio já aplicadas. Os agregados que respondem às perguntas do case (matriz de acertos, calibração, peso das variáveis, horário, provedor) são consultas em `analyses/`, com `ref()`, executadas com `dbt show`; as conclusões vão para o README. Sem exposures. `analyses/` não é materializado, então a regra de materialização do AGENTS.md (Stack) não se aplica a ele; a D7 do rascunho (datasets como views no schema `analises`) foi substituída por esta decisão.
- **G2. Tabelas**, todas no schema `gold_devedores` (G2 schema):

| Tabela | Grão | Base |
|---|---|---|
| `dim_devedor` | uma pessoa identificada por CPF (G3a′) | silver `devedores` e `devedores_historico` das três fontes |
| `dim_contato` | CPF × contato normalizado; contato sem documento com `sk_devedor` `NULL` (G2c′); guarda a régua | silver `devedores_contatos` das três fontes |
| `dim_endereco` | CPF × endereço padronizado distinto (G2c, ponto 5) | silver `devedores_enderecos` das três fontes |
| `dim_empregador` | um CNPJ recebido; o enriquecimento é da etapa 7 | CNPJs das históricas |
| `ft_vinculo_empresa` | período contínuo de um mesmo vínculo, por documento e provedor (ponto 3) | silver `devedores_historico` |
| `ft_tentativa_contato` | uma tentativa (`contato_id`) | silver `cobranca.contatos_realizados` |

  O par devedor × contato descreve o devedor, por isso é dimensão, e não fato (teste usado: aconteceu num momento ou descreve alguém?). `dim_contato` → `dim_devedor` é um floco pequeno, aceito.
- **G2b.** `canal` e `resultado` ficam como colunas da `ft_tentativa_contato`, com colunas de classificação derivadas num lugar só; sem `dim_canal`, `dim_resultado` nem dimensão junk. As classes do `tipo_desfecho` (aprovadas em 2026-11-10), sobre os 10 valores de `resultado`:
  - `contato_confirmado`: `pagamento`, `promessa_pagamento`, `reclamacao` (a reclamação confirma que a pessoa certa foi alcançada);
  - `terceiro`: `numero_errado`, `nao_conhece_devedor`;
  - `opt_out`;
  - `falecido`;
  - `sem_confirmacao`: `entregue`, `lido`, `sem_resposta` (`lido` não confirma quem leu).
  Um valor novo de `resultado` fora da lista reprova um teste `accepted_values`, para não cair numa classe por acaso.
- **G2d.** Linha montada a partir de vários provedores traz só `qt_provedores`. A pergunta "qual provedor" é uma consulta em `analyses/` sobre `silver_cobranca.contatos_realizados_provedores`.
- **Nomes de coluna (G2 naming).** Substantivo que é o próprio identificador ou valor fica sem prefixo (`cpf`, `cnpj`, `cnae`, `cep`, `uf`, `canal`, `contato`, `resultado`, `cargo`). Prefixos: `sk_`, `desc_`, `nome_`, `tipo_`, `qt_`, `vl_`, `tx_`, `flag_`, `dt_`, `hr_`; `situacao_` e `nivel_` por extenso. Texto do AGENTS.md no Anexo A.
- **G6. Chave substituta** `INTEGER` por `ROW_NUMBER()` ordenado pela chave natural, com o frame declarado. Determinística porque o banco é recriado a cada execução, e não carrega o CPF. `md5` descartado: medi 10 milhões de hashes de CPF em 3,1 s, o que torna o `md5(cpf)` reversível.
- **Premissa.** Os três provedores falam dos mesmos devedores, e a cobrança é uma operação só. Nada é sobrescrito: cada provedor mantém as próprias linhas nas tabelas de contato, endereço e vínculo; só o nome e o nascimento da `dim_devedor` guardam um valor escolhido. Vai para as premissas do README.

### Quem é o devedor e como os conflitos se resolvem
- **G3a′. Uma linha por pessoa identificada por CPF.** Todo documento recebido chega à gold:
  - CPF inválido (dígito verificador, macro `cpf_valido` da silver) com o mesmo nome comparável e o mesmo nascimento de exatamente um CPF válido, a um dígito de distância: liga-se a esse devedor (372 medidos);
  - `RG` do beta com o mesmo nome e nascimento de exatamente um CPF válido: liga-se, como evidência mais fraca (30);
  - CPF inválido sem ligação: linha própria com `situacao_cpf = 'invalido'` (ponto 1 da conferência; também o CPF com mais de 11 dígitos, 0 hoje);
  - `RG` sem ligação (13) e documento vazio ou zerado: não são devedores; os contatos entram com `sk_devedor` `NULL`, bloqueados.
  Regra, testes e riscos completos em `g3a-document-correction.md`; os números são medidos de novo na execução, com o nome comparável.
- **Nome comparável (ponto 2).** Macro da gold `nome_comparavel` = `TRANSLATE` com o mapa de acentos maiúsculos (existe no núcleo do PostgreSQL 18 e no DuckDB 2.0; conferido nas documentações). Medido: mesmo resultado do `strip_accents` nos 21.650 nomes distintos; o alfa manda nomes sem acento, e os documentos com nomes diferentes entre provedores caem de 3.494 para 569. Quando as formas diferem só no acento, a coluna mostra a forma acentuada. Um teste de aviso conta caracteres fora do ASCII que sobrem na chave.
- **G3b. Escolha de atributos.**
  - Estáveis (nome, nascimento): maioria entre provedores, um voto por provedor, a versão atual de cada um. Abreviação não é conflito (mesmo primeiro e último nome e mesmas iniciais: fica a forma por extenso); depois, maioria das formas completas; empate, a mais recente.
  - Nascimento: sentinelas (1900-01-01, datas futuras, datas inválidas) não votam; empate, inclusive dia e mês trocados, dá `NULL` (ponto 9/b2: é a falta de um valor confiável, não uma data recebida trocada).
  - Mutáveis (endereço, vínculo, renda): o mais recente. `situacao_endereco = 'atual'` e `situacao_vinculo = 'atual'` saem da versão mais recente entre os provedores (no beta, o `atual` do endereço).
  - Perfil da gama (`estado_civil`, dependentes, `score_externo`, `escolaridade`, imóvel, `fonte_score`): só a gama manda (verificado); versão atual da gama, `NULL` estrutural para quem a gama não manda.
  - **Recência:** a versão atual de cada fonte é a da silver (`devedores`), com a data de atualização como veio, inclusive 2025-09-01 (ponto 9/a2).
- **Datas (ponto 9).** A gold nunca troca uma data recebida por `NULL`: `dt_atualizacao` e as demais datas mostram o valor de origem.
- **G3c.** Conflito de identidade (`tipo_conflito_cadastral` com `identidade`) na `dim_devedor`: primeiro ou último nome diferentes para o mesmo CPF (249 medidos, 29,5% de contato com terceiro contra 3,6%). Os atributos continuam seguindo a G3b; a régua decide o que fazer.
- **Conflito de versões (ponto 4).** Nos 208 documentos com duas versões diferentes no mesmo arquivo e nas mesmas datas, vale a escolha da silver (`_linha DESC`, declarada arbitrária no README), e a `dim_devedor` marca `versao` em `tipo_conflito_cadastral`, guardado como sinal de coluna da régua.
- **Complemento (ponto 5).** Na `dim_endereco`, dois endereços do mesmo CPF iguais em tudo menos o complemento se juntam quando um dos complementos é `NULL` (fica o preenchido, a menor primeira entrega e a maior última entrega); dois complementos diferentes continuam separados. Medido: 342 grupos na gama, todos `NULL` contra um valor (a doc da silver fala em 221 pares; reconciliar na execução).
- **Salário 0,00 do alfa (ponto 6).** Vira `vl_renda` `NULL` ("não informado"), pela regra do case "ausência de dado é `NULL`, nunca zero". As 330 linhas têm cargo e CNPJ; em 210 dos 325 documentos outra versão traz salário maior que zero. A silver guarda o 0,00; a suposição vai para os limites.

### Vínculo e endereço
- **`ft_vinculo_empresa` (G2 employment + ponto 3).** Uma linha por período contínuo do mesmo conteúdo de vínculo, por documento e provedor: as versões da histórica ordenadas pela data de atualização como veio, depois entrega, arquivo e linha; um vínculo que volta depois de outro abre uma linha nova (ilhas por diferença de `ROW_NUMBER()`, sem `LAG`). Conteúdo: alfa `cnpj_empregador`, `cargo`, `salario_informado`; beta `vinculo_empresa_cnpj`, `vinculo_empresa_desde`, `renda_mensal`; gama `cnpj_empregador_raw`. Conteúdo todo vazio não vira linha, mas separa períodos. Sem SCD2 (a data de fim pediria `LEAD`).
- **Renda alterada.** 1.982 documentos no alfa e 1.416 no beta, confirmados. O 962 da medição antiga contava só a renda que veio como número JSON; 3.262 linhas do beta mandam texto (`"R$ 9.241,83"`), e, restrita aos valores numéricos, a conta dá 960. A consulta vai para `analyses/`.
- **`dim_endereco` (G2c).** CPF × endereço distinto pelo `hash_endereco` da silver (sem o documento, igual nas três fontes), com a regra do complemento acima e `qt_provedores`.

### Régua de risco
- **G4a. Três níveis**, com `desc_motivo_risco`:
  - `liberado`: contato com mensagem de cobrança;
  - `atencao`: contato sem expor a dívida (mensagem neutra pedindo retorno ou confirmação de identidade antes de qualquer menção à dívida);
  - `bloqueado`: sem contato; vai para a lista de não-contatar com o motivo.
  Base: CDC art. 42 e 71; LGPD art. 6º I, III e VII e art. 7º X (planalto.gov.br, 2026-11-10). Evolução estudada nas análises: 4 níveis e uma pontuação de 0 a 100 com rótulos por faixa; por isso cada grupo de sinais é uma coluna categórica ou `qt_` (seção 3), e o nível sai delas.
- **G4b. Sinais.**
  - `bloqueado`: contato sem devedor; par com `numero_errado` ou `nao_conhece_devedor` no histórico; `opt_out` no contato; `falecido` em qualquer contato do devedor (bloqueia todos os pares dele); contato que migrou (compartilhado e visto depois para outro CPF).
  - `atencao`: contato compartilhado sem migração; conflito de identidade; documento ligado por correção ou por RG (G3a′); CPF inválido.
  - Só como coluna, sem mudar o nível agora: provedor único, par ausente das entregas, contagens e conflito de versão.
- **G5. Lista de não-contatar** = `dim_contato` filtrada por `nivel_risco = 'bloqueado'`, com a consulta no README. `desc_motivo_risco` guarda o motivo principal pela prioridade falecido > opt_out > disse não ser o devedor > contato migrado > contato sem devedor; os demais motivos ficam visíveis nas colunas de sinal. O `opt_out` bloqueia o contato para todos os CPFs ligados a ele; `numero_errado` e `nao_conhece_devedor` valem para o par.
- **G4c. Validação sem vazamento.** Um corte único D = 2026-09-15: sinais calculados só com entregas e tentativas até D, avaliados nas tentativas depois de D. Uma macro só, `regua_de_risco(data_corte)`: a `dim_contato` a chama sem corte (régua de operação), a análise a chama com D, e a régua validada é a mesma que opera. A validação no ponto de corte não depende de colunas de data guardadas: a macro recalcula cada sinal só com as entregas e tentativas até a data de corte. As datas da `dim_contato` (`dt_situacao_compartilhamento`, `dt_alerta_historico`) são informativas, e os sinais do devedor não têm data própria. As métricas de validação e a calibração são da etapa 9 (tópico `monitoramento-e-analises`), que usa esta macro. Evolução no README: cada tentativa avaliada com a régua de sete dias antes, no mesmo dia da semana, `regua_de_risco(data_da_tentativa - 7 dias)`.
- **Par ausente das entregas (ponto 7).** Calculado só na régua de operação (última entrega do par antes da última entrega do provedor) e fora da validação em D, porque a silver guarda só a primeira e a última entrega de cada par. Evolução: uma tabela de presença por entrega na silver.
- **Contatos truncados da gama.** Nenhum sinal sai da falta de um contato na versão atual: as 8 versões atuais da gama com a lista cortada não são "sem contato".

### Horário de contato
- **G7.** O horário diz quando, não com quem, e nunca muda `nivel_risco`. Janela única e conservadora, a interseção da Lei SP 17.832/2023, art. 51, com o SARB 27/2023, art. 32: segunda a sexta das 8h às 20h, sábado das 9h às 14h, sem domingos nem feriados nacionais, para todo canal exceto e-mail. `situacao_horario` na `ft_tentativa_contato`; o resumo de conformidade fica em `analyses/`. Feriados nacionais como `var` do dbt, citando a Lei 662/1949 com a redação da Lei 10.607/2002. Não verificado (limites do README): se SMS e WhatsApp contam como "telefonemas", o alcance territorial da lei de SP, se a operação é signatária da Febraban, feriados estaduais e municipais e o texto consolidado do SARB depois da alteração.

### Rastreabilidade
- As tabelas que vêm de um registro de um provedor (`dim_contato`, `dim_endereco`, `ft_vinculo_empresa`, `ft_tentativa_contato`, `dim_empregador`) terminam com `_arquivo`, `_linha` e `_hash_arquivo` da aparição mais recente, como na silver.
- **`dim_devedor` (ponto 8): sem rastreabilidade.** A linha junta até três provedores; a origem de cada atributo se acha pelas tabelas filhas e pela silver.
- `hash_conteudo` e `hash_endereco` são usados só dentro da pipeline e não viram coluna da gold (não são portáveis entre motores, contrato §6.3).

## 3. Colunas (aprovadas em 2026-11-10)

Ordem do AGENTS.md: chave substituta → chave natural → atributos → nomes → números e valores → flags → datas → rastreabilidade.

**Sinais como colunas categóricas.** Sinais que respondem à mesma pergunta viram uma coluna `situacao_` ou `tipo_` com valores fechados, em vez de uma flag por sinal. O estado conhecido "sem sinal" tem valor próprio (`nenhum`, `exclusivo`), e não `NULL`: `NULL` fica para dado ausente. Quando dois valores do mesmo grupo coexistem, vale a prioridade da G5; nada se perde, porque os eventos estão na `ft_tentativa_contato` e as contagens ficam em `qt_`. Os sinais do devedor ficam só na `dim_devedor`; a régua os lê pela chave, sem repeti-los em cada contato.

- **`dim_devedor`:** `sk_devedor`, `cpf`, `situacao_cpf` (`valido`, `invalido`), `tipo_conflito_cadastral` (`nenhum`, `identidade`, `versao`, `identidade_e_versao`), `estado_civil`, `escolaridade`, `fonte_score`, `nome_devedor`, `qt_dependentes`, `score_externo`, `qt_provedores`, `qt_documentos_vinculados`, `flag_possui_imovel` (atributo recebido da gama, não sinal), `dt_nascimento`.
- **`dim_contato`:** `sk_contato`, `sk_devedor`, `cpf`, `tipo_contato`, `contato`, `nivel_risco`, `desc_motivo_risco`,
  - `situacao_documento`: por qual documento o contato chegou ao devedor (`cpf_valido`, `cpf_corrigido`, `rg_por_nome_nascimento`, `cpf_invalido`, `sem_documento`), com `documento_original` quando não é `cpf_valido`;
  - `situacao_compartilhamento` (`exclusivo`, `compartilhado`, `migrado`);
  - `tipo_alerta_historico` (`nenhum`, `falecido`, `opt_out`, `nao_e_o_devedor`), pela prioridade da G5;
  - `situacao_entrega` (`presente`, `ausente`; só na régua de operação, ponto 7);
  - `qt_provedores` (o "provedor único" é `qt_provedores = 1`), `qt_devedores_mesmo_contato`, `qt_tentativas`, `qt_tentativas_terceiro`;
  - `dt_primeira_entrega`, `dt_ultima_entrega`, `dt_situacao_compartilhamento` (quando passou a compartilhado ou migrado), `dt_alerta_historico`;
  - rastreabilidade. Nenhuma flag.
- **`dim_endereco`:** `sk_endereco`, `sk_devedor`, `tipo_endereco`, `situacao_endereco` (`atual`, `anterior`), `endereco`, `logradouro`, `numero_endereco`, `complemento`, `bairro`, `cidade`, `uf`, `cep`, `qt_provedores`, `dt_primeira_entrega`, `dt_ultima_entrega`, rastreabilidade.
- **`dim_empregador`:** `sk_empregador`, `cnpj`, rastreabilidade; os atributos da Receita entram na etapa 7.
- **`ft_vinculo_empresa`:** `sk_devedor`, `sk_empregador`, `provedor`, `situacao_vinculo` (`atual`, `anterior`), `cargo`, `vl_renda`, `dt_inicio_vinculo` (o mês, dia 01 por convenção), `dt_atualizacao`, `dt_primeira_entrega`, `dt_ultima_entrega`, rastreabilidade.
- **`ft_tentativa_contato`:** `sk_devedor`, `sk_contato`, `contato_id`, `canal`, `resultado`, `tipo_desfecho` (classes da G2b), `situacao_horario` (`permitido`, `fora_do_horario`, `domingo`, `feriado`, `nao_se_aplica` para e-mail), `dt_tentativa`, `hr_tentativa`, rastreabilidade.

  A tentativa liga-se ao par (CPF, contato); sem par, ao contato sem devedor de mesmo valor; sem nenhum dos dois, as chaves ficam `NULL` e são contadas.

A gold tem uma flag só, `flag_possui_imovel`, que é dado recebido, e não sinal.

## 4. Sequência de execução

Cada passo roda com o agente indicado, que lê este plano, o AGENTS.md e o contrato da silver. Os commits listados são os autorizados; o que a revisão do passo 4.9 apontar entra como commit próprio. Nenhum passo edita `models/silver/` nem as macros de padronização: o que faltar da silver vira pendência para o dono.

**Ponto de verificação de cada passo**, antes do commit: `dbt build` dos modelos alterados e dos que dependem deles, SQLFluff sem erro nos arquivos alterados e `scripts/verificar_execucoes_identicas.py` verde. O passo só segue com os três verdes.

**Condições de parada.** A execução para e chama o dono, sem contornar, quando:
- uma contagem medida diverge mais de 10% da que está neste plano;
- for preciso mexer na silver ou nas macros de padronização;
- um teste só passa mudando uma decisão da seção 2;
- aparece uma coluna, um nome ou um valor categórico que não está na seção 3.

### 4.0 Git (feito em 2026-11-10)
- `feat/modelo-gold-e-regua` criado a partir da `develop` (2fb4b44), levando a memória do `.context/`.

### 4.1 AGENTS.md e decisões da gold
- **Quem:** `analista-dados` (Opus 5.5 · medium).
- **Fazer:** aplicar o Anexo A ao AGENTS.md; escrever a seção da gold em `docs/decisoes-de-modelagem.md` com as decisões da seção 2, as opções descartadas, os números e as páginas do enunciado (inclusive a nota `g3a-document-correction.md`).
- **Commit:** `docs: decisões da gold e da régua de risco antes do código`.

### 4.2 Schemas da gold e macros
- **Quem:** `engenheiro-sql` (Sonnet 5.5 · medium).
- **Fazer:** `generate_schema_name` passa a gerar `gold_<domínio>` a partir de `models/gold/<domínio>/`, com teste; macros `nome_comparavel` e `regua_de_risco(data_corte)` (esqueleto com os sinais), com testes; `var` dos feriados nacionais.
- **Commit:** `feat: schema por domínio na gold e macros de nome comparável e da régua`.

### 4.3 Devedor único
- **Quem:** `engenheiro-sql` (Sonnet 5.5 · high).
- **Fazer:** `dim_devedor` com G3a′, G3b, G3c, ponto 4 e ponto 8. Testes unitários de cada regra de ligação e de escolha (os da seção 6 da nota da G3a′); `cpf` e `sk_devedor` únicos; nenhum CPF válido ligado a outro documento.
- **Pronto quando:** documentos recebidos → devedores, ligações por caso e conflitos estão medidos.
- **Commit:** `feat: devedor único com ligação de documentos ruidosos e escolha de atributos`, com as contagens no corpo.

### 4.4 Endereço, empregador e vínculo
- **Quem:** `engenheiro-sql` (Sonnet 5.5 · medium).
- **Fazer:** `dim_endereco` (regra do complemento), `dim_empregador`, `ft_vinculo_empresa` (períodos, 0,00 como `NULL`); teste unitário das ilhas (A → B → A dá três linhas; A → vazio → A dá duas); consulta de reconciliação da renda em `analyses/`.
- **Commit:** `feat: endereços, empregadores e períodos de vínculo por provedor`.

### 4.5 Contatos e régua
- **Quem:** `engenheiro-sql` (Sonnet 5.5 · high).
- **Fazer:** `dim_contato` com os sinais da G4b nas colunas categóricas da seção 3, `nivel_risco` e `desc_motivo_risco` pela `regua_de_risco()`; testes: todo `bloqueado` tem motivo; `opt_out` bloqueia em todos os CPFs do contato; `falecido` bloqueia todos os pares do devedor; relacionamentos aceitando `NULL`.
- **Commit:** `feat: contatos com a régua de risco aplicada a cada par`.

### 4.6 Tentativas
- **Quem:** `engenheiro-sql` (Sonnet 5.5 · medium).
- **Fazer:** `ft_tentativa_contato` com a ligação ao par, as classificações (G2b) e a janela de horário (G7); contagem das chaves `NULL` por motivo.
- **Commit:** `feat: tentativas de contato ligadas ao par e à janela de horário`.

### 4.7 Consultas pedidas pelas decisões da gold
- **Quem:** `analista-dados` (Opus 5.5 · medium).
- **Fazer:** em `analyses/`, só as consultas que as decisões desta etapa pedem: conformidade de horário por canal (G7), taxa de terceiro por provedor sobre `silver_cobranca.contatos_realizados_provedores` (G2d) e a lista de não-contatar (G5). A reconciliação da renda já entra no passo 4.4. A validação com corte D, a matriz de acertos e a calibração são da etapa 9; a macro `regua_de_risco(data_corte)` fica pronta para ela.
- **Commit:** `feat: consultas de conformidade de horário, provedor e lista de não-contatar`.

### 4.8 Otimização medida
- **Quem:** `engenheiro-sql`, com o plano de execução real dos modelos mais pesados; um `refactor:` só com ganho medido (antes e depois no corpo).

### 4.9 Revisão e fechamento
- `revisor` (Opus 5.5 · medium) lê o diff contra o enunciado, o AGENTS.md e este plano; `verificador` (Haiku 5.5 · low) roda tudo do zero.
- Correções como commits próprios; depois, a memória do tópico e o merge `--no-ff` com `chore: integra modelo-gold-e-regua na develop`.

## 5. Ganhos e números a registrar

| O quê | Onde |
|---|---|
| Documentos recebidos → devedores; ligações por caso (G3a′) | commit 4.3 e README |
| Conflitos de identidade e de versão | commit 4.3 e README |
| Pares por nível e motivo | commit 4.5 e README |
| Tentativas sem par e sem devedor | commit 4.6 e limites |
| Tentativas fora da janela, por canal | consulta do passo 4.7 |
| Tempo e plano dos modelos | cada `refactor:` |

## 6. Fora deste plano
- **Etapa 7 (CNPJ, D8 do rascunho):** extrato reproduzível da Receita e atributos da `dim_empregador`; não discutido.
- **Etapa 8:** o fato de monitoramento da ingestão, noutro schema `gold_<domínio>`.
- **Etapa 9 (tópico `monitoramento-e-analises`):** validação com corte D, matriz de acertos e erros, calibração, chamando `regua_de_risco(data_corte)`.
- **Ciclo medido de refinamento da régua** (log do PROJECT.md, 2026-11-10: refinamentos além da calibração rodam num ciclo medido planejado no tópico da régua): depende da métrica que a etapa 9 define. Ele é planejado neste tópico quando essa métrica existir, como um passo novo deste plano, aprovado pelo dono antes de rodar.
- **ERD e dicionário:** tópico `documentacao-e-entrega` (D1, D2).
- **Referências da web** (Kimball, Microsoft Learn, dbt, CDC, LGPD, Lei SP 17.832/2023, SARB 27/2023, Lei 662/1949): a cópia em `.context/raw/referencias/` depende do aval do dono.

## Anexo A — texto do AGENTS.md aprovado pelo dono (aplicado no commit do passo 4.1)

### A. "Camadas e nomes": troca do item de schemas

Antes:
> - Schemas no banco: `bronze_<fonte>`, `silver_<fonte>` e `gold`. A tabela leva só o nome da entidade (`bronze_alfa.devedores`).

Depois:
> - Schemas no banco: `bronze_<fonte>`, `silver_<fonte>` e `gold_<domínio>`. Na bronze e na silver o sufixo é a fonte; na gold, o domínio de negócio (`gold_devedores`), e nenhum domínio repete o nome de uma fonte. A tabela leva só o nome da entidade (`bronze_alfa.devedores`, `gold_devedores.dim_devedor`). O schema sai da pasta: `models/gold/<domínio>/`.

### B. "Colunas da gold": troca da tabela de prefixos e dos itens seguintes

Depois:
> - Nomes em português, minúsculos. O substantivo que é o próprio identificador ou valor não leva prefixo (`cpf`, `cnpj`, `cnae`, `cep`, `uf`, `canal`, `contato`, `resultado`, `cargo`); os prefixos dizem o papel da coluna:
>
>   | Prefixo | Uso | Exemplo |
>   |---|---|---|
>   | `sk_` | chave substituta | `sk_devedor` |
>   | `desc_` | descrição de um código ou de um motivo | `desc_cnae`, `desc_motivo_risco` |
>   | `nome_` | nome | `nome_devedor` |
>   | `tipo_` · `situacao_` | tipo · situação (valores fechados) | `tipo_contato`, `situacao_cpf` |
>   | `qt_` · `vl_` · `tx_` | quantidade · valor · taxa | `qt_provedores`, `vl_renda` |
>   | `flag_` | booleano | `flag_possui_imovel` |
>   | `dt_` · `hr_` | data · hora | `dt_atualizacao`, `hr_tentativa` |
>
>   Nível vai por extenso: `nivel_risco`. Sinais que respondem à mesma pergunta viram uma coluna `situacao_` ou `tipo_`, e não uma flag por sinal; o estado "sem sinal" tem valor próprio, e `NULL` fica para dado ausente.
> - Ordem das colunas nas dimensões: chave substituta → chave natural → atributos, com cada código seguido da própria descrição (`cnae`, `desc_cnae`) → nomes → números e valores → flags → datas → rastreabilidade por último.
> - (ordem nos fatos: sem mudança)
> - Linhas montadas a partir de várias fontes trazem `qt_provedores`, a quantidade de provedores que contribuíram para a linha. A pergunta "qual provedor" é respondida por uma análise sobre a silver, e não por uma coluna com vários valores.
> - (chave ausente `NULL` e `LEFT JOIN`: sem mudança)
