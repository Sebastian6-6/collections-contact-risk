# Análises

Respostas aos itens da "Análise de Dados" do enunciado (p. 1–2). Cada número sai de uma consulta de `analyses/`, rodada com `dbt show --select <consulta>` depois de `python pipeline.py`, ou de `scripts/medir_regua.py`, e vem com a quantidade de casos ao lado da taxa. Os dados são sintéticos (p. 2) e cobrem um mês; os limites de cada conclusão estão na última seção.

| Item do enunciado | Seção |
|---|---|
| Detecção de anomalias e qualidade na ingestão | [Anomalias na ingestão](#anomalias-na-ingestão) |
| Enriquecimento cadastral e valor de negócio | [O que a base de CNPJ agrega](#o-que-a-base-de-cnpj-agrega) |
| Política de salvaguardas e lista de não-contatar | [Política de não-contatar](#política-de-não-contatar) |
| Segmentação, canais e mensagens por nível; acurácia, calibração, peso das variáveis, padrões de erro e ajustes | [Régua de cobrança](#régua-de-cobrança) |

## Anomalias na ingestão

Detalhe e arquitetura em [monitoramento.md](monitoramento.md). Em resumo:

- **Seis incidentes**, todos detectados por `alertas_das_entregas`: cabeçalho do alfa trocando `cpf` por `documento` em 12/09; gama de 15/09 truncada (85 linhas, a última cortada) e reenviada (311); alfa sem 22/09, com o dia vindo no 23/09 (715 linhas, 362 atualizadas antes do dia); beta sem 24 e 25/09, sem reenvio; beta de 29/09 repetindo o dia 28 (761 linhas, 353 repetidas).
- **Alarmes:** 11 alertas em 5 entregas; nenhuma outra das 87 entregas gera alerta (18 delas ainda sem base para a média de volume). A média móvel compara cada entrega com as 5 anteriores do mesmo tipo de dia (útil ou fim de semana), com ±50%; a média simples das 7 anteriores daria 13 alarmes falsos, todos em fim de semana (commit 325264b), porque o fim de semana tem cerca de 40% do volume de um dia útil (`perfil_entregas`).
- **Normalização:** a linha que não se lê fica na bronze com o motivo; o reenvio vence o original pela ordem das versões; o registro atrasado entra na posição da sua data de atualização; o conteúdo repetido vira uma versão só; o dia perdido não gera linha, e os devedores ficam com a versão anterior.

## O que a base de CNPJ agrega

O enunciado pede para "demonstrar o que a base de CNPJ agrega à esteira de cobrança" (p. 2). O cruzamento está na seção 10 de [decisoes-de-modelagem.md](decisoes-de-modelagem.md); aqui fica o que ele mostra.

**Cobertura** (`cnpj_cobertura_empregadores`). Dos 13 CNPJs de empregador recebidos, 8 existem como estabelecimento na Receita e 10 têm a raiz (os 8 primeiros caracteres) registrada. Os 5 não encontrados são:

- os 3 alfanuméricos (`3RT8XB51000136`, `A7K2M9Q4000140`, `Z0P4LC22000124`), cuja raiz não existe na base;
- `04182736500157` e `51930487200150`, cuja raiz existe, mas não com essa ordem e esse dígito.

**Situação do empregador** (`cnpj_taxas_por_situacao`). Cada devedor tem no máximo um vínculo atual:

| Situação do empregador atual | Devedores | Tentativas em setembro | Terceiro | Contato confirmado |
|---|---|---|---|---|
| ativa na Receita | 10.770 (53%) | 7.991 | 326 (4,08% ± 0,43) | 961 (12,03% ± 0,71) |
| CNPJ não encontrado | 6.628 (33%) | 5.056 | 187 (3,70% ± 0,52) | 633 (12,52% ± 0,91) |
| sem vínculo atual | 2.783 (14%) | 2.006 | 76 (3,79% ± 0,84) | 250 (12,46% ± 1,45) |

A margem é a meia largura do intervalo de 95% (aproximação normal). Os 8 empregadores encontrados estão todos `ATIVA` e com porte `DEMAIS`: nenhum devedor tem vínculo com empresa baixada, inapta ou suspensa. As taxas das três situações cabem nas margens umas das outras, então a situação do empregador não separa o risco de falar com terceiro nem a chance de confirmar o contato.

**Setor e porte** (`cnpj_cobertura_empregadores`). Os 8 encontrados são 4 instituições financeiras (CNAE 6421200, 6422100 e 6423900), petróleo, minério de ferro, cerveja e lojas de departamento. Cada empregador tem de 1.296 a 1.423 devedores e de 943 a 1.095 tentativas; o terceiro vai de 2,94% a 4,66% (margens de ±1,1 a ±1,3 p.p.) e o contato confirmado, de 11,24% a 13,57% (±1,9 a ±2,1 p.p.). O porte é o mesmo para todos. A ordem dos canais também não muda com o empregador: em cada situação, ligação e WhatsApp confirmam mais (16,5% a 18,4%) e o e-mail menos (5,5% a 6,3%). A estratégia de canal segue o nível de risco, e não o setor ou o porte.

**O que agrega, então:**

1. **Qualidade cadastral.** 6.628 devedores (33%) têm como empregador atual um CNPJ que não existe como estabelecimento. É um achado para devolver aos provedores que o dígito verificador não pega, porque ele é válido nos 13.
2. **Empregador confirmado.** Para 10.770 devedores (53%), a operação sabe que o empregador existe e está ativo, com razão social, CNAE e município, onde antes havia só um número.
3. **Um sinal pronto para quando aparecer.** A `dim_empregador` já traz a situação cadastral, a data e o motivo. Um empregador baixado ou inapto pode indicar renda em risco e mudar a prioridade da cobrança, mas é uma hipótese: nestes dados não há nenhum, e o efeito não pode ser medido.

## Política de não-contatar

O risco central do case é "contatar quem não deve" (p. 1), e o enunciado pede para justificar "quais sinais acionam o bloqueio" (p. 2). O princípio, as bases legais e as opções descartadas estão na seção 9.9 de [decisoes-de-modelagem.md](decisoes-de-modelagem.md): `bloqueado` quando a evidência diz que o contato é de outra pessoa ou há um pedido explícito; `atencao` quando a dúvida é estatística ou de identidade.

A evidência de cada sinal vem da validação sem vazamento (`regua_validacao_peso_sinais`): os sinais calculados só com dados até 15/09 e a taxa de terceiro nas tentativas depois do corte, com o sinal e sem ele. Os pares contam o motivo principal na régua de operação (`dim_contato`).

| Sinal | Nível | Pares hoje | Terceiro com o sinal | Sem o sinal | Razão |
|---|---|---|---|---|---|
| falecido em algum contato do devedor | `bloqueado` | 128 | 0 de 12 | 4,12% | — |
| opt-out no contato | `bloqueado` | 382 | 4 de 36 (11,1%) | 4,08% | 2,7 |
| disse não ser o devedor (`numero_errado`, `nao_conhece_devedor`) | `bloqueado` | 490 | 22 de 46 (47,8%) | 3,81% | 12,5 |
| contato migrado para outro CPF | `bloqueado` | 2.165 | 32 de 118 (27,1%) | 3,70% | 7,3 |
| contato sem devedor | `bloqueado` | 269 | sem tentativa depois do corte | — | — |
| contato compartilhado entre CPFs | `atencao` | 4.142 | 163 de 506 (32,2%) | 1,81% | 17,8 |
| conflito de identidade no cadastro | `atencao` | 414 | 24 de 49 (49,0%) | 3,77% | 13,0 |
| documento ligado por correção ou por RG | `atencao` | 39 | 0 de 4 | 4,12% | — |
| CPF inválido sem ligação | `atencao` | 113 | sem tentativa depois do corte | — | — |

- **Falecido e opt-out** bloqueiam por ser fato ou pedido, não pela taxa de terceiro: depois de um `opt_out` houve 84 tentativas ao mesmo destino e, depois de um `falecido`, 38 ao mesmo CPF (`perfil_contatos_realizados`). Esses números mostram que a operação de setembro não aplicava essas salvaguardas.
- **O migrado tem taxa menor que o compartilhado** (27,1% contra 32,2%), e mesmo assim é bloqueado. A razão é o princípio: o número foi visto depois para outra pessoa. Na validação, passá-lo para `atencao` não muda a métrica (hipótese H4, abaixo), então a escolha é de política, e fica a mais protetora.
- **A lista de não-contatar** é a `dim_contato` com `nivel_risco = 'bloqueado'` (`lista_nao_contatar`): 3.434 pares. 154 devedores têm todos os pares bloqueados.
- **Ganho e custo** no corte de 15/09 (`scripts/medir_regua.py`): a régua põe em `atencao` ou `bloqueado` 202 de 275 tentativas que terminaram com terceiro (73,45%), e 99 de 774 contatos confirmados (12,8%) cairiam nesses níveis (67 em `atencao`, que ainda recebe uma mensagem neutra, e 32 em `bloqueado`).
- **Horário** diz quando, não com quem, e não muda o nível. Em setembro, 519 de 2.576 ligações (20,1%), 419 de 1.993 SMS (21,0%) e 991 de 4.781 WhatsApp (20,7%) ficaram fora da janela adotada (`conformidade_horario_por_canal`; janela na seção 9.10 de [decisoes-de-modelagem.md](decisoes-de-modelagem.md)).

## Régua de cobrança

### Segmentação dos devedores elegíveis

Cada devedor fica no segmento do melhor nível entre os seus pares. Na régua de operação (`regua_validacao_segmentacao` com `--vars '{data_corte_validacao: "2026-10-01"}'`, um corte depois do último dado, que devolve as mesmas contagens da `dim_contato`):

| Segmento | Devedores | Pares | Pares por nível | Pares não bloqueados: telefone / e-mail | Ação |
|---|---|---|---|---|---|
| `cobranca_normal` | 19.626 | 50.745 | 44.579 liberados, 3.639 atenção, 2.527 bloqueados | 28.778 / 19.440 | cobrança pelos pares liberados |
| `cobranca_com_cautela` | 400 | 1.359 | 1.069 atenção, 290 bloqueados | 610 / 459 | só mensagem neutra |
| `nao_contatar` | 154 | 342 | 342 bloqueados | 0 / 0 | nenhum contato |

Um devedor não tem par. No corte de 15/09, os segmentos tinham 17.950, 357 e 76 devedores.

### Canais e mensagens por nível

Tentativas depois de 15/09, pelo nível que a régua dava no corte (`regua_validacao_canais_por_nivel`):

| Nível | Canal | Tentativas | Contato confirmado | Terceiro |
|---|---|---|---|---|
| `liberado` | WhatsApp | 1.867 | 16,07% | 1,12% |
| `liberado` | ligação | 844 | 16,35% | 2,25% |
| `liberado` | SMS | 739 | 12,72% | 0,54% |
| `liberado` | e-mail | 2.518 | 5,68% | 1,15% |
| `atencao` | ligação | 88 | 21,59% | 21,59% |
| `atencao` | WhatsApp | 204 | 14,22% | 34,31% |
| `atencao` | SMS | 92 | 10,87% | 31,52% |
| `atencao` | e-mail | 118 | 7,63% | 23,73% |

- **`liberado`: mensagem de cobrança.** WhatsApp e ligação primeiro (16% de confirmação), SMS depois, e-mail como complemento de baixo custo (5,7%). O terceiro fica entre 0,5% e 2,3% em todos. Dentro da janela de horário: no corte, 14,6% a 17,5% das tentativas liberadas por telefone ficaram fora dela.
- **`atencao`: mensagem neutra**, sem mencionar a dívida, pedindo retorno ou confirmação de identidade. Aqui de 22% a 34% dos contatos são terceiros, em qualquer canal, e por isso a dívida não aparece. A ligação tem a melhor relação (21,59% de confirmados para 21,59% de terceiros, contra 14,22% para 34,31% no WhatsApp) e permite confirmar a identidade antes de falar da dívida. Com 88 a 204 tentativas por canal, a margem de 95% de cada taxa vai de ±4,8 a ±9,5 p.p. (calculada sobre as contagens da consulta, pela aproximação normal), então a ordem entre os canais é indicativa.
- **`bloqueado`: nenhum canal.** As 211 tentativas que a operação fez a pares bloqueados no corte tiveram 26,54% de terceiro.
- **CNPJ:** setor e porte não mudam a ordem dos canais ([seção do CNPJ](#o-que-a-base-de-cnpj-agrega)).

### Acurácia e calibração

**Métrica** (aprovada no plano da gold): acurácia balanceada, a média entre a fração dos desfechos de risco (`terceiro`, `opt_out`, `falecido`) cujo par ficou em `atencao` ou `bloqueado` e a fração dos `contato_confirmado` cujo par ficou `liberado`. `sem_confirmacao` (entregue, lido, sem resposta) fica fora, e as tentativas sem par no corte ficam fora das frações. Medida por `scripts/medir_regua.py`:

| Corte | Acurácia balanceada | Riscos pegos | Terceiros pegos | Confirmados liberados | Tentativas sem par |
|---|---|---|---|---|---|
| 15/09 | 0,6871 | 228 de 454 (50,22%) | 202 de 275 (73,45%) | 675 de 774 (87,21%) | 1.090 |
| 22/09 (controle) | 0,7208 | 150 de 271 (55,35%) | 134 de 180 (74,44%) | 389 de 438 (88,81%) | 480 |

**Matriz** no corte de 15/09 (`regua_validacao_matriz`), tentativas depois do corte:

| Nível | Tentativas | Confirmado | Sem confirmação | Terceiro | Opt-out | Falecido |
|---|---|---|---|---|---|---|
| `liberado` | 5.968 | 675 | 5.067 | 73 | 136 | 17 |
| `atencao` | 502 | 67 | 271 | 146 | 14 | 4 |
| `bloqueado` | 211 | 32 | 115 | 56 | 8 | 0 |
| sem par no corte | 1.090 | 170 | 834 | 52 | 26 | 8 |

**Calibração** (`regua_validacao_calibracao`): a taxa de risco (terceiro, opt-out e falecido) é 3,79% no `liberado`, 32,67% no `atencao` e 30,33% no `bloqueado`; só o terceiro, 1,22%, 29,08% e 26,54%. A régua separa bem o `liberado` dos outros dois níveis, mas não ordena `atencao` abaixo de `bloqueado`: os dois têm risco parecido.

O terceiro é bem previsto (73% pegos); o opt-out, não: 136 dos 158 opt-outs com nível vieram de pares `liberado`. É uma escolha do titular que nenhum sinal anterior antecipa.

### Peso dos sinais

`regua_validacao_peso_sinais`, taxa de terceiro com e sem cada sinal, nas 6.681 tentativas depois de 15/09 com par no corte:

| Sinal | Com o sinal | Sem o sinal | Razão | Usado na régua |
|---|---|---|---|---|
| contato compartilhado | 163 de 506 (32,21%) | 112 de 6.175 (1,81%) | 17,8 | sim |
| conflito de identidade | 24 de 49 (48,98%) | 250 de 6.627 (3,77%) | 13,0 | sim |
| disse não ser o devedor | 22 de 46 (47,83%) | 253 de 6.635 (3,81%) | 12,5 | sim |
| contato migrado | 32 de 118 (27,12%) | 243 de 6.563 (3,70%) | 7,3 | sim |
| provedor único | 234 de 3.695 (6,33%) | 41 de 2.986 (1,37%) | 4,6 | não |
| opt-out | 4 de 36 (11,11%) | 271 de 6.645 (4,08%) | 2,7 | sim |
| sem tentativa anterior | 235 de 5.394 (4,36%) | 40 de 1.287 (3,11%) | 1,4 | não |

Os quatro sinais de maior peso já definem o nível. O provedor único pesa, mas atinge 55% das tentativas: é o sinal que mais custaria em alcance (H1, abaixo).

### Padrões de erro

`regua_validacao_erros`, no corte de 15/09:

- **Pontos cegos** (`liberado` que terminou em terceiro): 73, todos sem nenhum sinal de risco. 40 deles (54,8%) vinham de contato entregue por um só provedor; por canal, 29 no e-mail, 21 no WhatsApp, 19 na ligação e 4 no SMS.
- **Falsos bloqueios** (`atencao` ou `bloqueado` que terminou em contato confirmado): 99. 63 (63,6%) por contato compartilhado e 22 (22,2%) por contato migrado; 73 (73,7%) em contato de um só provedor.
- **Fora da régua:** 1.090 tentativas não tinham par no corte (170 confirmados, 52 terceiros, 26 opt-outs e 8 falecidos). É o maior espaço que sobra, e não depende dos critérios da régua.

### Propostas de ajuste e o loop de refinamento

Cada proposta foi aplicada à macro `regua_de_risco()`, medida com `scripts/medir_regua.py` e revertida quando rejeitada. Só ficaria a que melhorasse a acurácia no 15/09 sem baixar os terceiros pegos da linha de base em nenhum corte e sem piorar o 22/09; o loop para em 3 rejeições seguidas.

| Hipótese | 15/09: acurácia, terceiros, confirmados | 22/09: acurácia, terceiros, confirmados | Resultado |
|---|---|---|---|
| linha de base | 0,6871, 202/275, 675/774 | 0,7208, 134/180, 389/438 | — |
| H1: provedor único vai a `atencao` | 0,5813, 242/275, 298/774 | 0,6073, 160/180, 178/438 | rejeitada: +40 terceiros protegidos custam 377 confirmados |
| H2: migrado bloqueado só com 1 provedor | 0,6910, 202/275, 681/774 | 0,7258, 133/180, 395/438 | rejeitada: abaixo do piso de terceiros no 22/09 |
| H3: e-mail sem tentativa anterior vai a `atencao` | 0,6922, 225/275, 560/774 | 0,7144, 147/180, 330/438 | rejeitada: piora o 22/09 em 0,64 p.p. |
| H4: migrado vai a `atencao` | 0,6871, 202/275, 675/774 | 0,7208, 134/180, 389/438 | sem efeito: a métrica conta `atencao` e `bloqueado` juntos |

A régua ficou como estava. O que sobra para ajustar está fora dela:

- **Avaliar com a régua da semana anterior** (`regua_de_risco(data_da_tentativa - 7 dias)`), em vez de um corte único, para dar nível a mais tentativas e medir em mais de um ponto (seção 9.9 de [decisoes-de-modelagem.md](decisoes-de-modelagem.md)).
- **Uma métrica que separe `atencao` de `bloqueado`,** o que pede o desfecho de mensagens neutras, que o histórico não tem.
- **Uma pontuação de 0 a 100 com faixas,** com os sinais que já estão em colunas na `dim_contato`, para usar o provedor único sem mandar 55% das tentativas para `atencao`.

## Limites

- **Dados sintéticos** (p. 2): proporções como a distribuição quase uniforme de devedores entre os 13 empregadores não devem ser generalizadas.
- **Um mês de histórico:** a validação usa um corte (15/09, 7.771 tentativas depois dele) e um controle (22/09). As hipóteses do loop foram formuladas olhando os dados depois do corte, e por isso o segundo corte serve de controle.
- **A métrica não separa `atencao` de `bloqueado`:** os dois contam como risco pego. Mudar a severidade de um sinal entre esses níveis é decisão de política, e o loop não a julga (H4).
- **O migrado depende das entregas parciais:** um contato é migrado quando um CPF o recebe depois da última entrega de outro CPF que o tinha. As entregas diárias são parciais: 49.952 de 52.721 pares (94,7%) não estavam na última entrega do seu provedor (`dim_contato.situacao_entrega`). Não verifiquei se as entregas são retratos completos ou atualizações.
- **O custo de `atencao` está superestimado:** a métrica trata todo confirmado em `atencao` como perdido, mas esse par ainda recebe a mensagem neutra; o histórico não tem o desfecho dela.
- **Canais observados, não sorteados:** as taxas por canal misturam o canal com o perfil de quem foi acionado por ele, e nos níveis `atencao` e `bloqueado` cada canal tem menos de 300 tentativas.
- **Tentativas sem par** (1.090 no corte de 15/09) ficam fora das frações: a régua não teve como avaliá-las.
- **CNPJ:** uma só base da Receita (2026-10), nenhum empregador baixado ou inapto entre os 8 encontrados, e o vínculo atual é o registro mais recente do devedor, não necessariamente o que valia no dia da tentativa.
- **O que não foi verificado** na régua e no horário (obrigação legal do bloqueio por opt-out e falecido, alcance da lei de SP, SMS e WhatsApp como telefonema, feriados locais) está nas seções 9.9, 9.10 e 9.12 de [decisoes-de-modelagem.md](decisoes-de-modelagem.md).
