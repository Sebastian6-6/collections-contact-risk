# Contratos de dados dos provedores

O que se espera de cada entrega dos provedores alfa, beta e gama e do histórico de contatos da Cobrança. Para cada item, o documento registra três coisas:
- o que foi recebido;
- o que o contrato pede;
- quem garante: um teste do projeto que falha ou avisa, ou só o provedor, quando nenhum teste consegue verificar.

- **Base:** o enunciado diz que "cada provedor fornece o que tem disponível" (p. 2) e que cada um entrega "no seu próprio formato" (p. 1). O contrato não exige um formato único: exige que cada provedor mantenha o seu e avise quando mudar.
- **Números:** medidos em 2026-11-09 sobre a bronze da carga completa (92 arquivos), por consulta ao banco ou pelos commits do tópico. Os dados são sintéticos (p. 2), com um mês de entregas.
- **Legenda da coluna "Quem garante":** *erro* = o teste falha e a pipeline para; *aviso* = teste com severidade warn, que mostra a contagem e não para; *provedor* = nenhum teste verifica, e o item é obrigação do provedor.

As decisões por trás das regras estão em [decisoes-de-modelagem.md](decisoes-de-modelagem.md).

## 1. Regras comuns a todas as entregas

| Item | Esperado | Quem garante |
|---|---|---|
| Local e nome do arquivo | histórico: `contact_data/provedor_<provedor>.<ext>`; entrega diária: `contact_data/entregas_diarias/<provedor>/provedor_<provedor>_AAAA-MM-DD.<ext>` ("um arquivo por provedor e por dia (com a data expressa no nome do arquivo)", p. 3) | a ingestão lê só o que casa com os padrões de `ingestion/fontes.yml`. Erro se um arquivo casar com duas entradas (`test_arquivo_que_casa_com_duas_entradas_gera_erro_e_nao_carrega_nada`) ou se uma entidade ficar sem arquivo (`test_entidade_sem_arquivo_e_erro_e_nao_silencio`). Um arquivo com nome fora do padrão é ignorado **sem aviso**: provedor (o alerta de dia sem arquivo é do monitoramento, etapa seguinte) |
| Data no nome | `AAAA-MM-DD`, data real do calendário. Reenvio: mesmo nome com sufixo `_reenvio` e a mesma data (gama, 15/09) | a macro `data_do_nome_do_arquivo` lê a data (teste `macro_data_do_nome_do_arquivo`). Só o arquivo histórico configurado (variável `arquivo_historico`, nome exato) recebe a data da carga (2026-08-31); um arquivo que casa com o padrão mas não traz data válida no nome fica com `data_entrega` nula, e o teste `entrega_diaria_sem_data_valida` (severidade `error`) reprova a pipeline. A macro `data_de_entrega` tem o teste `macro_data_de_entrega`. Provedor |
| Encoding | UTF-8 | erro: um byte fora do encoding interrompe a fonte com o arquivo e a linha (`test_byte_fora_do_encoding_interrompe_a_fonte_com_o_arquivo_e_a_linha` e os testes equivalentes do leitor de CSV e de JSONL). Medido: os 92 arquivos decodificam em UTF-8 estrito |
| Caractere U+FFFD (substituição) | ausente: ele indica um texto que já foi corrompido antes da entrega | provedor. O U+FFFD é UTF-8 válido e passa pela ingestão sem erro; nenhum teste o procura. Medido em 2026-11-09: 0 ocorrências nos 92 arquivos e nas quatro tabelas da bronze. A observação do passo 4.5 de que nomes e cidades do beta traziam U+FFFD **não se reproduziu** |
| Quebra de linha | LF ou CRLF (as entregas do alfa e da gama usam CRLF) | `test_csv_crlf_sai_do_texto_mas_nao_dos_campos_internos` |
| CSV | separador vírgula, aspas duplas em campo com vírgula ou JSON, cabeçalho só na primeira linha | uma linha que não separa em colunas entra como ilegível, com o texto e o motivo (`test_csv_malformado_fica_com_o_texto_e_o_motivo`). O cabeçalho repetido no meio vira linha comum e sai da silver por falta de chave (aviso `gama_linhas_sem_chave`) |
| Colunas do CSV | as do contrato de cada fonte, sem acréscimo nem remoção sem aviso | erro: `colunas_declaradas` falha se a tabela da bronze ganhar ou perder uma coluna em relação a `models/bronze/<fonte>/_fontes.yml` |
| Linhas por arquivo | toda linha física coberta | erro: `linhas_iguais_ao_registro` (linhas da tabela por arquivo = `arquivos.linhas`) e `combinacao_unica` em (`_arquivo`, `_linha`) |
| Chave preenchida | documento (devedores) ou `contato_id` (cobrança) em toda linha | aviso: `<fonte>_linhas_sem_chave` conta as linhas que ficaram fora da silver |
| Data de atualização | nunca posterior à data da entrega | provedor; medido só na gama (seção 4) |
| Troca de campos com o mesmo formato (bairro no lugar da cidade) | não acontece | provedor: nenhum teste distingue dois textos livres |

## 2. Provedor alfa (CSV)

Arquivos: `provedor_alfa.csv` e 29 entregas diárias. Não há arquivo de 22/09; os registros desse dia vieram dentro do arquivo de 23/09 ([perfil-das-fontes.md](perfil-das-fontes.md)).

| Item | Recebido (medido) | Contrato | Quem garante |
|---|---|---|---|
| Coluna do documento | `cpf` no histórico e nas entregas até 11/09 (12 arquivos); `documento` desde 12/09 (18 arquivos) | nome fixo adotado: `documento`. Uma nova renomeação precisa de aviso prévio | erro: `colunas_declaradas` falha para coluna nova; `test_o_alfa_junta_cpf_e_documento_na_mesma_tabela` |
| Demais colunas | `nome_completo`, `data_nascimento`, `cnpj_empregador`, `cargo`, `salario_informado`, `telefone`, `email`, `endereco`, `cep`, `uf`, `data_atualizacao` | os mesmos nomes; a silver mantém todos | erro: `colunas_declaradas` |
| CPF | com e sem máscara; zeros à esquerda perdidos (662 linhas do histórico com 9 ou 10 dígitos) | 11 dígitos, com ou sem máscara | a silver repõe os zeros (`macro_cpf_normalizado`). O dígito verificador inválido não falha nenhum teste: `cpf_valido` só informa, e a gold decide |
| Datas | `data_nascimento` e `data_atualizacao` em `AAAA-MM-DD` nas 19.476 linhas | `AAAA-MM-DD` | `macro_data_flexivel`. Uma data em formato desconhecido vira `NULL` e **nenhum teste conta esses `NULL`**: provedor |
| Salário | decimal com vírgula, com ou sem ponto de milhar (`8.556,50`, `3135,87`) ou com ponto decimal (`2400.92`); vazio em 2.843 linhas; `0,00` em 341 | decimal com vírgula; vazio = não informado. O provedor precisa dizer se `0,00` é "sem renda" ou "não informado" | `macro_valor_monetario`. O significado do zero fica em aberto para a gold |
| Telefone | 6 formatos (`21954107566`, `+5571944014509`, `+55 62 94981-7073`...) | DDD + número, com ou sem `+55` e máscara | `macro_telefone_normalizado` |
| Telefones sentinela | `0000000000` em 35 linhas (35 documentos) e `1104687901` em 44 linhas (44 documentos) | não enviar número de preenchimento: telefone desconhecido vai vazio | provedor. A silver mantém os dois como vieram; a régua os trata na gold |
| Endereço | uma string `LOGRADOURO, NUMERO[, COMPLEMENTO] - BAIRRO - CIDADE` (ex.: `AVENIDA BRASIL, 3489, APTO 101 - ITAPUA - SALVADOR`) | essa ordem, sem vírgula nem hífen dentro das partes | erro: `alfa_endereco_ida_e_volta` (as partes recompõem o texto). Cobertura: 11.459 de 11.459. A ordem trocada entre bairro e cidade passa: provedor |
| CEP | 8 dígitos em 15.914 linhas e 7 em 3.562 (zero perdido) | 8 dígitos, em texto | a silver repõe o zero; nenhum teste conta os CEPs de 7 dígitos: provedor |
| CNPJ do empregador | com e sem máscara, sem zeros, com 12 caracteres (sem dígitos verificadores) e alfanumérico | 14 caracteres, numérico ou alfanumérico | `macro_cnpj_normalizado`. O CNPJ de 12 caracteres fica como veio (escolha ainda a confirmar) |
| Data de nascimento sentinela | `1900-01-01` em 19 linhas; `2031-05-10` (futura) em 14 | data desconhecida vai vazia | provedor; a silver mantém como veio |
| Data de atualização sentinela | `2025-09-01` em 376 linhas, todas no histórico | data desconhecida vai vazia | provedor. O alfa não tem o teste de aviso que o beta e a gama têm |

## 3. Provedor beta (JSON Lines)

Arquivos: `provedor_beta.jsonl` e 28 entregas diárias. Não há arquivos de 24 e 25/09, e os registros desses dias não aparecem em nenhum outro arquivo. O arquivo de 29/09 reenvia os registros de 28/09 ([perfil-das-fontes.md](perfil-das-fontes.md)).

| Item | Recebido (medido) | Contrato | Quem garante |
|---|---|---|---|
| Linha | um objeto JSON por linha; 15 linhas truncadas no histórico (19.000 de 19.015 linhas são JSON válido) | um objeto JSON completo por linha | aviso: `beta_linhas_sem_chave` (as 15 truncadas e as 33 com documento nulo) |
| Chaves do objeto | 12 combinações de chaves | as variantes abaixo; **uma chave nova no JSON passa sem aviso**, porque `colunas_declaradas` vê só a coluna `registro` | provedor |
| Documento | `cpf` (texto) ou `documento{tipo, valor}`; `tipo` = `CPF` em 10.502 linhas e `RG` em 45 (42 documentos) | nomes fixos adotados: `tipo_documento` + `documento`. RG nunca no lugar do CPF | o teste unitário `silver_beta_devedores_versao_mais_recente` cobre CPF e RG com o mesmo número; o RG não ganha zeros e não vira CPF |
| Nome | `nome`, `nome_completo` ou `nome_devedor` | nome fixo adotado: `nome_completo` (os outros entram por `COALESCE`) | `silver_beta_padronizacao_das_variantes_de_json` |
| Telefones | `contato.telefones[]` com texto ou `{ddd, numero, tipo, principal}` | as duas formas são aceitas; o objeto precisa de `ddd` e `numero` | `macro_telefone_de_elemento_json`; objeto sem DDD ou sem número vira `NULL` |
| E-mails | `contato.emails[]` ou `email` | as duas formas | `silver_beta_padronizacao_das_variantes_de_json` |
| Endereço | `enderecos[]` ou `endereco{}`, com `tipo`, `logradouro`, `numero`, `complemento`, `bairro`, `cidade`, `uf`, `cep`, `atual`; CEP com hífen em 11.118 endereços e sem hífen em 8.749; número `S/N` em 1.933 | os campos separados, na ordem logradouro → número → complemento → bairro → cidade; CEP com ou sem hífen | `silver_beta_devedores_enderecos_versao_atual`. O conteúdo trocado entre bairro e cidade passa: provedor |
| Vínculo | `vinculo_empresa{cnpj, desde}`, com `desde` em `AAAA-MM` | nomes fixos adotados: `cnpj_empregador` e `vinculo_desde` (texto, sem dia inventado) | `macro_cnpj_normalizado` |
| Renda | número em 11.320 linhas, texto `"R$ 9241,83"` em 3.262, nulo em 4.418 | número ou texto em reais; nulo = não informado | `macro_valor_monetario` |
| Data de atualização | `atualizado_em` em ISO 8601 com fuso `-03:00` (16.216 linhas) ou epoch em milissegundos (2.784) | ISO 8601 com fuso | `macro_data_flexivel`. O epoch é convertido em UTC-3 (escolha ainda a confirmar) |
| Data de nascimento | `AAAA-MM-DD` em 18.906 linhas e `DD/MM/AAAA` em 94 | `AAAA-MM-DD` | `macro_data_flexivel` aceita as duas |
| Datas sentinela | `atualizado_em` = 2025-09-01 em 372 das 9.969 linhas do histórico e em nenhuma das 8.998 linhas diárias; nascimento `1900-01-01` em 21 linhas e `2031-05-10` em 10 | data desconhecida vai nula | aviso: `beta_data_20250901_so_no_historico` avisa se a data aparecer numa entrega diária. As de nascimento: provedor |

## 4. Provedor gama (CSV com JSON embutido)

Arquivos: `provedor_gama.csv` e 31 entregas diárias, entre elas `provedor_gama_2026-09-15_reenvio.csv`. O original de 15/09 tem 85 linhas, e a última está cortada; o reenvio traz o conteúdo completo.

| Item | Recebido (medido) | Contrato | Quem garante |
|---|---|---|---|
| Colunas | `documento`, `nome`, `data_nascimento`, `contatos`, `endereco_json`, `atributos_extra`, `cnpj_empregador_raw`, `dt_ref` | nomes fixos adotados na silver: `cnpj_empregador` (de `cnpj_empregador_raw`) e `data_atualizacao` (de `dt_ref`); os demais iguais | erro: `colunas_declaradas` |
| Cabeçalho | 1 cabeçalho repetido no meio do histórico | cabeçalho só na primeira linha | aviso: `gama_linhas_sem_chave` |
| Linha cortada | 1 linha ilegível (o original de 15/09) | arquivo completo; um reenvio substitui o original com o sufixo `_reenvio` | a linha entra na bronze com o motivo e fica fora da silver (aviso `gama_linhas_sem_chave`) |
| Documento | CPF com máscara | 11 dígitos, com ou sem máscara | `macro_cpf_normalizado`; 45 linhas com documento vazio ficam fora (aviso) |
| Nome | em minúsculas em 1.544 linhas; com espaço sobrando em 1.363 | nome como no documento | provedor; a silver só apara as pontas |
| Datas | `data_nascimento` e `dt_ref` em `DD/MM/AAAA` (19.504 linhas; a outra é o cabeçalho repetido) | `DD/MM/AAAA` | `macro_data_flexivel` |
| `dt_ref` | nunca posterior à data da entrega; nas diárias, 8.791 linhas com a data da entrega e 714 de 1 a 3 dias antes | data de atualização do registro, nunca posterior à entrega | provedor; medido no passo 4.6, sem teste permanente |
| Contatos | lista JSON `[{tipo, valor}]`, com `tipo` em `celular`, `fixo` ou `email`; 21 linhas com documento têm a lista truncada | lista JSON completa | aviso: `gama_contatos_truncados`; teste unitário `silver_gama_contatos_tipos_e_aparicao_mais_recente` |
| Endereço | `endereco_json` em 3 layouts: `rua` + `municipio`, `estado`, `cep` (6.918 linhas; `rua` = `LOGRADOURO, NUMERO`); `endereco` + `cidade`, `uf`, `cep` (2.936; `endereco` = `LOGRADOURO, NUMERO - BAIRRO`); estruturado com `logradouro`, `numero`, `complemento`, `bairro`, `cidade`, `uf`, `cep` (9.650) | um desses três layouts, com a ordem logradouro → número → complemento → bairro → cidade dentro do texto | erro: `gama_endereco_ida_e_volta`; cobertura de 100% nos layouts em texto. Um quarto layout ou o conteúdo trocado entre bairro e cidade passa: provedor |
| CEP | inteiro no JSON em 6.696 linhas (perde o zero à esquerda) e texto em 12.808 | texto com 8 dígitos | a silver repõe o zero; nenhum teste conta: provedor |
| Atributos extras | `atributos_extra` com `estado_civil`, `qtd_dependentes`, `score_externo` (300 a 950), `escolaridade`, `possui_imovel`, `fonte_score`; nem toda linha traz todas as chaves | essas chaves, opcionais; chave ausente vira `NULL` | `silver_gama_padronizacao_atributos_e_tres_formatos_de_endereco`. **Uma chave nova passa sem aviso**: provedor |
| Datas sentinela | `dt_ref` = 01/09/2025 em 372 linhas do histórico e em nenhuma diária; nascimento `01/01/1900` em 12 linhas e `10/05/2031` em 12 | data desconhecida vai vazia | aviso: `gama_data_20250901_so_no_historico`. As de nascimento: provedor |

## 5. Histórico de contatos (Cobrança)

Arquivo único: `contact_data/contatos_realizados.csv`, com as tentativas de setembro/2026 (p. 3).

| Item | Recebido (medido) | Contrato | Quem garante |
|---|---|---|---|
| Colunas | `contato_id`, `cpf_alvo`, `canal`, `destino`, `data_hora`, `resultado`, `provedor_origem` | os mesmos nomes; na silver, o texto de `destino` fica em `destino_original` e `destino` passa a ser o normalizado | erro: `colunas_declaradas` |
| Identificador | `contato_id` único nas 15.053 linhas | único e preenchido | erro: `unique` e `not_null`; aviso: `cobranca_linhas_sem_chave` (0 hoje) |
| Data e hora | `AAAA-MM-DD HH:MM:SS` nas 15.053 linhas, sem fuso | esse formato, na hora local da operação | `macro_timestamp_ou_nulo`; erro: `not_null` em `data_hora`. O fuso não está na origem e não foi confirmado |
| Canal | `sms`, `email`, `whatsapp`, `ligacao` | esses quatro | erro: `accepted_values`; canal novo deixa o destino `NULL` até ser mapeado |
| Destino | telefone (ligação, SMS, WhatsApp) ou e-mail | coerente com o canal | `silver_cobranca_padronizacao_destino_por_canal` |
| Resultado | 10 valores distintos | lista fechada, com aviso antes de um valor novo | provedor: não há `accepted_values` em `resultado` |
| Provedor de origem | um ou mais de `alfa`, `beta`, `gama`, separados por `\|` | esse formato | erro: `accepted_values` em `provedor` e `cobranca_contato_sem_provedor` |

## 6. O que nenhum teste fiscaliza hoje

Itens que dependem só do provedor, reunidos para a revisão do tópico e para o monitoramento:
1. Arquivo com nome fora do padrão (é ignorado) e arquivo que casa com o padrão sem uma data válida no nome (recebe a data da carga histórica).
2. O caractere U+FFFD dentro do texto.
3. Chave nova no JSON do beta e nos `atributos_extra` da gama.
4. Data em formato desconhecido, que vira `NULL` sem contagem.
5. Bairro e cidade trocados, e qualquer troca entre campos de texto livre.
6. Valores sentinela de telefone e de data de nascimento, e a data 2025-09-01 no alfa.
7. CEP com zero perdido (a silver corrige, mas não conta).
8. Valor novo em `resultado` da cobrança.

## 7. O que não foi verificado

- As versões PostgreSQL das macros com `adapter.dispatch` (`json_ou_nulo`, `json_texto`, `json_abrir_lista`, `data_iso_ou_nulo`, `timestamp_ou_nulo`) foram escritas a partir da documentação e nunca executadas. Os testes de macro citados aqui rodaram só no DuckDB.
- Os significados de `0,00` no salário do alfa, das datas sentinela e do fuso da `data_hora` são suposições até o provedor confirmar.
- A afirmação anterior sobre o U+FFFD no beta não se reproduziu (seção 1). Se ela veio de uma leitura do terminal com outro encoding, isso não foi verificado.
