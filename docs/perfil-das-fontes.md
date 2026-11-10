# Perfil das fontes

O que os arquivos recebidos em `contact_data/` contêm, que problemas de qualidade e de entrega trazem e o que isso pediu da pipeline. A primeira versão saiu de uma exploração manual em 2026-11-08, antes da arquitetura; esta é regenerada pela pipeline.

- **Como regenerar:** `python pipeline.py` e depois `dbt show --select <consulta>` para cada consulta de `analyses/` citada nas seções. Elas leem a silver; arquivos e linhas recebidas vêm do registro de cargas da bronze (`bronze_<fonte>.arquivos`), o único lugar que conta arquivos.
- **Contagens por coluna e por formato** (máscaras, zeros perdidos, formatos de salário e de telefone, variações de chave do beta, layouts de endereço da gama) estão em [contratos-de-dados.md](contratos-de-dados.md), medidas sobre a bronze inteira. Aqui ficam só os números que descrevem as fontes como um todo.
- **Correção em relação à exploração:** o reenvio da gama de 15/09 tem 311 linhas, e não 309.
- **Limite:** os dados são sintéticos (enunciado, p. 2), com um mês de entregas.

## Visão geral

`perfil_fontes`:

| Fonte | Arquivos | Linhas recebidas | Entregas diárias | Documentos distintos (silver) | Versões (silver) |
|---|---|---|---|---|---|
| alfa (CSV) | 30 | 19.476 | 29 arquivos, 9.476 linhas | 11.458 | 18.587 |
| beta (JSON Lines) | 29 | 19.015 | 28 arquivos, 9.015 linhas | 11.321 | 17.861 |
| gama (CSV com JSON embutido) | 32 | 19.506 | 31 arquivos, 9.506 linhas | 11.436 | 18.564 |
| cobrança (`contatos_realizados.csv`) | 1 | 15.053 | — | 9.065 CPFs alvo | — |

Cada histórico tem 10.000 linhas. São 88 arquivos diários; a gama tem 31 porque 15/09 veio em dois.

## Identificação do devedor

`perfil_documentos`, com o CPF já padronizado pela silver (zeros à esquerda repostos; o RG do beta fica fora):

| Medida | CPFs |
|---|---|
| Nas cargas históricas | 16.552: 7.542 num provedor só, 5.771 em dois e 3.239 nos três |
| Com as entregas de setembro | 20.586: 10.337 num provedor, 6.911 em dois e 3.338 nos três |
| Em 2 ou mais provedores, com nomes diferentes (sem acento, versão atual) | 569 |
| Em 2 ou mais provedores, com datas de nascimento diferentes | 310 |

Nas versões da histórica, 50 têm a data de nascimento sentinela `1900-01-01` e 31 têm nascimento depois da carga histórica (`2031-05-10`).

O CPF é a chave natural de todas as fontes, e nenhuma o entrega pronto: há máscara, zero à esquerda perdido, documento vazio, dígito verificador inválido e RG no lugar do CPF ([contratos-de-dados.md](contratos-de-dados.md), seções 2 a 4). A gold liga os documentos ruidosos a uma pessoa quando a evidência é forte e chega a 20.181 devedores, 78 deles com CPF inválido sem ligação (`dim_devedor`; regra na seção 9.5 de [decisoes-de-modelagem.md](decisoes-de-modelagem.md)).

## Provedores

- **alfa:** a coluna `cpf` passa a se chamar `documento` nas entregas a partir de 12/09; salário em vários formatos, com `0,00` que a gold trata como não informado; CEP com o zero à esquerda perdido.
- **beta:** cada linha é um JSON, com 12 combinações de chaves (documento, nome, endereço, e-mail, telefone, data e renda variam de forma); 15 linhas do histórico vêm truncadas.
- **gama:** endereço num JSON com 3 layouts; um cabeçalho repetido no meio do histórico; listas de contatos com o JSON cortado; atributos de perfil (estado civil, dependentes, score externo) que só ela manda.

As contagens de cada item estão nas seções 2 a 4 de [contratos-de-dados.md](contratos-de-dados.md).

## Entregas diárias

`perfil_entregas`:

| Medida | alfa | beta | gama |
|---|---|---|---|
| Entregas (dias com arquivo) | 29 | 28 | 30 |
| Dias sem entrega | 1 | 2 | 0 |
| Dias com reenvio | 0 | 0 | 1 (original de 85 linhas, reenvio de 311) |
| Média de linhas, dia útil / fim de semana | 395,5 / 146,3 | 388,0 / 156,9 | 374,4 / 158,6 |
| Linhas atualizadas antes do dia da entrega, nas entregas comuns | 7,1% a 8,0% | 7,5% a 8,0% | 7,5% a 8,1% |
| Versões com data de atualização 2025-09-01 (todas na histórica) | 372 | 365 | 367 |
| Documentos das entregas diárias que já estavam na histórica | 4.619 de 6.466 (71,4%) | 4.332 de 6.045 (71,7%) | 4.598 de 6.428 (71,5%) |

O fim de semana tem cerca de 40% do volume de um dia útil, por isso o monitoramento compara cada entrega com a média do mesmo tipo de dia. A entrega diária é, na maior parte, atualização de devedor que já existe. O que aconteceu em cada dia com problema (alfa sem 22/09 e o 23/09 com o dia anterior, beta sem 24 e 25/09, beta de 29/09 repetindo o dia 28, gama de 15/09 truncada e reenviada, cabeçalho do alfa mudando em 12/09) e como a pipeline trata cada caso estão em [monitoramento.md](monitoramento.md).

## Empregadores (CNPJ)

Depois da padronização, os provedores mandam 13 CNPJs distintos, todos com dígito verificador válido, 3 deles alfanuméricos (seção 5.13 de [decisoes-de-modelagem.md](decisoes-de-modelagem.md)). No cruzamento com a Receita (`cnpj_cobertura_empregadores`), 10 raízes existem e 8 CNPJs existem como estabelecimento; as 3 raízes ausentes são as alfanuméricas. O valor do enriquecimento para a cobrança está em [analises.md](analises.md).

## Histórico de contatos

`perfil_contatos_realizados`:

- 15.053 tentativas a 9.065 CPFs, em 4 canais (e-mail, WhatsApp, ligação e SMS) e 10 resultados.
- O destino da tentativa foi trazido por 1 provedor em 7.720 tentativas, por 2 em 4.945 e pelos 3 em 2.388.
- **Horário:** 314 tentativas antes das 8h, nenhuma às 20h, 458 a partir das 21h e 629 aos domingos. A janela legal adotada está na seção 9.10 de [decisoes-de-modelagem.md](decisoes-de-modelagem.md).
- **Salvaguardas que falharam:** 84 tentativas a um destino depois de um `opt_out` nele (77 no mesmo par CPF × destino) e 38 a um CPF depois de um desfecho `falecido`.
- **Destino:** 13.961 tentativas vão a um contato que algum provedor entregou; 1.092 vão a um destino que nenhum provedor entregou para aquele CPF, um ponto cego que a régua não avalia.

## Sinais de risco

A exploração cruzou cada contato com as tentativas para achar sinais de contato com terceiro (`numero_errado` ou `nao_conhece_devedor`). Um deles se reproduz igual na pipeline (`taxa_terceiro_por_provedor`): o destino trazido por um só provedor teve 6,6% de terceiro (507 de 7.720), contra 1,1% quando trazido por dois (56 de 4.945) ou por três (26 de 2.388). Os números falsos `0000000000` e `1104687901` estão ligados a 35 e 44 CPFs (`dim_contato.qt_devedores_mesmo_contato`).

Os demais sinais (contato compartilhado, migrado, conflito de identidade) foram refeitos na gold e validados sem vazamento, com os sinais calculados só com dados até o corte: ver [analises.md](analises.md).

## O que isso pediu do desenho

1. **Registro de cada arquivo recebido** (nome, hash, linhas) antes de qualquer transformação, para tratar atraso, perda, repetição e truncamento e reprocessar do zero com o mesmo resultado.
2. **Um componente de ingestão por fonte, configurável:** nomes alternativos de coluna entram por configuração, sem código novo.
3. **Nenhuma linha some:** registros truncados, cabeçalhos repetidos e JSON cortado ficam na bronze, com o motivo, e são contados.
4. **Cruzamento de contato, CPF, provedor e entrega:** os sinais de risco mais fortes só aparecem aí; a silver guarda a primeira e a última entrega de cada par, e a gold calcula os sinais na `dim_contato`.
5. **Resolução de conflitos explícita** para nome, nascimento e CPF compartilhado, em vez de "o último vence".
6. **Monitoramento volumétrico por tipo de dia,** por causa da sazonalidade semanal.
