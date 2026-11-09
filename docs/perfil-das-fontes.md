# Perfil das fontes

Análise exploratória de todos os arquivos recebidos em `contact_data/`, feita antes de qualquer decisão de arquitetura. Ela registra o que os dados realmente contêm, que problemas de qualidade e de entrega existem e o que isso exige da pipeline.

- **Data da análise:** 2026-11-08.
- **Escopo:** as três cargas históricas, os 88 arquivos de entregas diárias de setembro/2026 e `contatos_realizados.csv`.
- **Limite:** os números vêm de uma análise exploratória. Na fase de implementação, a análise vira um script versionado no repositório, e os números passam a poder ser gerados de novo a qualquer momento (o enunciado exige código reprodutível, p. 2).

Os dados são sintéticos, segundo o próprio enunciado (p. 2).

## Visão geral

| Fonte | Formato | Volume | Resumo |
|---|---|---|---|
| `provedor_alfa.csv` | CSV | 10.000 linhas | formatos mistos de CPF, salário e telefone; zeros à esquerda perdidos |
| `provedor_beta.jsonl` | JSON Lines | 10.000 linhas | 12 variações de esquema; 15 linhas truncadas |
| `provedor_gama.csv` | CSV com JSON embutido | ~10.000 linhas | cabeçalho repetido no meio; JSON cortado; 3 layouts de endereço |
| `entregas_diarias/` | CSV e JSON Lines | 88 arquivos (alfa 29, beta 28, gama 31) | atrasos, perdas, reenvios e truncamento |
| `contatos_realizados.csv` | CSV | 15.053 tentativas | limpo; serve de gabarito para a régua de risco |

Considerando as três cargas históricas, existem 16.577 CPFs distintos. 9.010 aparecem em mais de um provedor e 3.240 nos três.

## Identificação do devedor

O CPF é a chave natural de todas as fontes, e nenhuma o entrega pronto para uso.

| Problema | Onde | Volume |
|---|---|---|
| CPF com e sem máscara (`999.999.999-99` e `99999999999`) | todos | ambos os formatos são comuns |
| Zero à esquerda perdido: 9 ou 10 dígitos | alfa | 662 linhas. Padronizando para 11 dígitos, os CPFs válidos sobem de 9.230 para 9.890 |
| CPF vazio | alfa | 12 |
| Dígito verificador inválido mesmo após padronizar | alfa | 98 |
| RG no lugar do CPF (`documento.tipo = "RG"`) | beta | 24. Padronizar para 11 dígitos criaria um CPF falso |
| CPF repetido dentro do mesmo histórico | alfa e gama | 378 (alfa) e 393 (gama); a alfa tem ainda 150 linhas duplicadas por inteiro |
| Mesmo CPF com nomes diferentes entre provedores | entre provedores | 510; em 91 deles é claramente outra pessoa |
| Data de nascimento divergente: dia e mês trocados e datas sentinela `1900-01-01` e `2031-05-10` (futura) | entre provedores | 228 CPFs |

## Provedor alfa

- O bloco de vínculo (cargo, CNPJ e salário) vem sempre vazio junto: são 1.582 linhas sem vínculo.
- O salário aparece em 9 formatos (`R$ 8.556,50`, `8556.50`, `0,00`…), com 165 valores `0,00`. Pela convenção do case, ausência de dado é `NULL`, nunca zero, então esses zeros precisam de uma regra explícita.
- O telefone aparece em 6 formatos.
- 1.812 CEPs têm 7 dígitos (zero perdido).
- Nas entregas diárias, a coluna `cpf` passa a se chamar `documento` a partir de 12/09: uma mudança de esquema no meio do mês.

## Provedor beta

As 10.000 linhas seguem 12 combinações diferentes de chaves:

| Campo | Variações |
|---|---|
| documento | `cpf` ou `documento{tipo, valor}` |
| nome | `nome`, `nome_completo` ou `nome_devedor` |
| endereço | `enderecos[]` ou `endereco{}`; CEP com ou sem hífen; número `"S/N"` |
| e-mail | `emails[]` ou `email` |
| telefone | texto ou `{ddd, numero, tipo, principal}` |
| atualização | ISO 8601 com fuso `-03:00` ou epoch em milissegundos |
| renda | número, texto `"R$ 9241,83"` ou nulo |

Além disso, 15 linhas são registros truncados ("Registro Interrompido") e não formam JSON válido.

## Provedor gama

- O endereço vem num campo JSON com 3 layouts: `rua/municipio/estado`, `endereco/cidade/uf` e `logradouro/bairro/…`. Em 3.363 linhas o CEP vem como inteiro.
- O histórico tem uma linha de cabeçalho repetida no meio do arquivo.
- 22 campos `contatos` trazem JSON cortado.
- Nomes vêm em minúsculas e com espaços sobrando; datas em `dd/mm/aaaa`; CPF com máscara.
- `atributos_extra` traz estado civil, dependentes, escolaridade, imóvel e um score externo de 300 a 950, com a fonte do score.

## Entregas diárias

Setembro/2026 começa numa terça-feira. Nos fins de semana o volume é cerca de 1/3 do de um dia útil.

| Dia | O que aconteceu | O que exige da pipeline |
|---|---|---|
| alfa 22/09 | arquivo ausente; os 336 registros vieram dentro do arquivo de 23/09 (715 linhas) | atraso sem perda: deduplicar por registro, não por arquivo |
| beta 24 e 25/09 | arquivos ausentes, e os registros desses dias não aparecem em nenhum outro arquivo | perda real: alerta e lacuna documentada |
| beta 29/09 | reenvia os 323 registros de 28/09, idênticos (761 linhas) | ingestão idempotente |
| gama 15/09 | original truncado (85 linhas, a última cortada); o arquivo `_reenvio` (309 linhas) contém tudo | o reenvio substitui o original |
| todos | 7% a 10% de cada arquivo são registros de D-1 e D-2 | atraso é rotina: a data do arquivo não é a data do registro |
| todos | um grupo de cerca de 370 registros com data 01/09/2025 em cada provedor | parece uma data padrão de migração; não indica que o registro é recente |

Outros pontos das entregas:
- Há chaves repetidas dentro do mesmo arquivo diário.
- Os CSVs usam quebra de linha CRLF.
- Cerca de 72% dos CPFs de cada entrega diária já existem no histórico do mesmo provedor. A entrega diária é, na maior parte, atualização, não devedor novo.

O enunciado sugere média móvel para o monitoramento (p. 1–2). Com essa sazonalidade semanal, uma média móvel simples dispararia alarme falso todo fim de semana. A comparação precisa ser com o mesmo dia da semana.

## Empregadores (CNPJ)

- Os valores distintos de CNPJ (30 na alfa, 39 na beta) correspondem a só 13 empregadores, escritos de várias formas: sem zeros à esquerda (`191`), sem os dígitos verificadores (12 caracteres), com máscara e alfanuméricos (`A7K2M9Q4000140`).
- Todos passam na validação do dígito verificador, inclusive pela regra do CNPJ alfanumérico, que a Receita Federal adota a partir de julho/2026 (IN RFB nº 2.229/2024).
- Os CNPJs alfanuméricos são sintéticos e provavelmente não existem nos dados abertos da Receita: é um ponto cego conhecido para o enriquecimento.

## Histórico de contatos

`contatos_realizados.csv` é a fonte mais limpa: CPFs válidos e nenhuma linha duplicada.

- **Canais:** e-mail, WhatsApp, ligação e SMS.
- **Desfechos:** 10 tipos, entre eles `pagamento`, `promessa_pagamento`, `opt_out`, `numero_errado`, `nao_conhece_devedor`, `reclamacao` e `falecido`.
- `provedor_origem` pode combinar provedores (`alfa|beta`).
- **Horários:** há tentativas entre 6h e 7h e entre 21h e 23h, e nenhuma às 20h.

## Sinais de risco de contato

Para medir os sinais, cada telefone e e-mail de todas as fontes foi padronizado e cruzado com as tentativas de contato. Telefones foram reduzidos a DDD mais número, sem o 55, e e-mails convertidos para minúsculas, o que resultou em cerca de 53 mil pares CPF–contato. "Contato errado" significa desfecho `numero_errado` ou `nao_conhece_devedor`.

| Sinal | Contato errado | Tentativas |
|---|---|---|
| contato exclusivo do CPF | 1,4% | 13.283 |
| contato ligado a mais de um CPF | 23,1% | 1.770 |
| contato confirmado por 2 ou 3 provedores | 1,1% | 7.333 |
| contato visto por um só provedor | 6,6% | 7.720 |
| telefone que passou para outro CPF entre o histórico e as entregas diárias | 25,1% | 1.014 |

Outros achados:
- **Números falsos:** `0000000000` e `1104687901` estão ligados a 35 e 44 CPFs, todos vindos da alfa.
- **Salvaguardas que falharam:** 84 tentativas depois de um `opt_out` e 38 depois de um desfecho `falecido`.
- **Fora do horário:** 772 tentativas antes das 8h ou a partir das 20h e 629 aos domingos, sem diferença visível na taxa de reclamação. A referência legal de horário de cobrança ainda será confirmada no texto oficial antes de entrar na régua.
- **Destino das tentativas:** das 15.053, 13.948 foram para um contato que alguma fonte liga ao próprio CPF, 69 para um contato que as fontes ligam a outro CPF e 1.036 para destinos que não existem em nenhuma fonte. Essas 1.036 são um ponto cego: a régua não tem como avaliá-las.

## O que isso exige do desenho

1. **Registro de cada arquivo recebido** (nome, hash, número de linhas, se é reenvio) antes de qualquer transformação. É o que permite tratar atraso, perda, duplicação e truncamento e reprocessar do zero com o mesmo resultado.
2. **Um componente de ingestão por fonte, configurável.** Nomes alternativos de coluna (`cpf`/`documento`, `nome`/`nome_completo`/`nome_devedor`) entram por configuração, sem código novo.
3. **Linhas inválidas não somem.** Registros truncados, cabeçalhos repetidos e JSON cortado ficam separados e contados, para entrar nos alertas.
4. **Fatos de contato na silver:** uma linha por CPF, contato, provedor e data de recebimento. Os sinais mais fortes de risco só aparecem nesse cruzamento, e nenhum provedor sozinho os revela.
5. **Resolução de conflitos explícita** para nome, nascimento e CPF compartilhado, em vez de "o último vence".
6. **Monitoramento volumétrico por dia da semana,** por causa da sazonalidade.
