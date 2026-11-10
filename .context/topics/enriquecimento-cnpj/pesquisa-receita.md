# Pesquisa: dados abertos do CNPJ e licenças das referências

Data de acesso de todas as fontes: 2026-11-10. "Verificado" = conferido na própria página ou no próprio arquivo oficial nesta data. "Medido" = contado por mim nos arquivos oficiais (não é número publicado pela Receita). "Não verificado" = não encontrei fonte oficial.

## Parte A — Dados abertos do CNPJ (Receita Federal)

### A1. Onde está, periodicidade, mês mais recente

- **Página no dados.gov.br:** https://dados.gov.br/dados/conjuntos-dados/cadastro-nacional-da-pessoa-juridica---cnpj (é SPA em JavaScript; li a página renderizada com navegador headless). A página antiga da Receita, https://www.gov.br/receitafederal/pt-br/acesso-a-informacao/dados-abertos/cadastros/cnpj, redireciona (302) para ela. Verificado.
  - Texto da página: "A periodicidade de atualização dos dados é mensal. Data da última extração: 11/01/2026." / "Atualização: Mensal" / "Catalogação: 29/12/2021" / "Última alteração nos metadados: 09/02/2026" / "Última alteração em um arquivo: 05/07/2024" / Organização "MF - Ministério da Fazenda" / Área técnica "RFB - Secretaria Especial da Receita Federal do Brasil". A página marca o conjunto como "Desatualizado", embora o servidor de arquivos já tenha outubro/2026 (ver abaixo): a descrição do catálogo não acompanha as publicações.
  - Recursos listados (5): Nota Técnica RFB/Cocad nº 47/2024 (PDF); Nota Técnica RFB/Cocad nº 86/2024 (PDF); "Dicionário de dados do CNPJ" (PDF, "Data de atualização do arquivo: 02/12/2021"); "Inscrições no CNPJ" (ZIP); "Regimes Tributários" (ZIP). A URL exata por trás de cada botão "Acessar o recurso": **não verificado** (o botão abre a URL por JavaScript e a API do portal respondeu 401 fora do navegador).
- **Endereço oficial atual de download:** servidor Nextcloud da Receita, "Arquivos da Receita Federal - SERPRO+".
  - https://arquivos.receitafederal.gov.br/ redireciona para o compartilhamento público https://arquivos.receitafederal.gov.br/index.php/s/gn672Ad4CF8N6TK, com as pastas `Dados/Cadastros/CNPJ/AAAA-MM/`. Verificado.
  - O mesmo conteúdo existe como compartilhamento próprio, intitulado "CNPJ": https://arquivos.receitafederal.gov.br/index.php/s/YggdBLfdninEJX9 (pastas `AAAA-MM/` na raiz). Verificado (mesmas pastas e datas).
  - Acesso por máquina (WebDAV público do Nextcloud, usuário = token do compartilhamento, senha vazia): listagem com `PROPFIND https://arquivos.receitafederal.gov.br/public.php/webdav/<pasta>/` e download com `GET` no mesmo caminho, com `-u "YggdBLfdninEJX9:"`. Funcionou nos testes (HTTP 207 na listagem, 200/206 no download, aceita `Range`). É o mecanismo padrão do Nextcloud, não uma API documentada pela Receita.
  - Os endereços antigos `https://arquivos.receitafederal.gov.br/dados/cnpj/dados_abertos_cnpj/` e `.../dados/cnpj/LAYOUT_DADOS_ABERTOS_CNPJ.pdf` respondem 404; `dadosabertos.rfb.gov.br` aparece só em comentários antigos do portal.
- **Pastas disponíveis:** 2023-05 até **2026-10** (uma por mês, sem lacunas), mais um `cnpj.tar.gz` de 63.954.782.749 bytes (modificado em 28/01/2026; conteúdo não verificado).
- **Mês mais recente hoje: 2026-10**, pasta modificada em 13/10/2026 22:09 GMT. Não existe pasta 2026-11. Os nomes internos dos arquivos trazem `D61010` (ex.: `K3241.K03200Y1.D61010.EMPRECSV`); em julho era `D60711`. Leitura provável: data de geração 2026-10-10 / 2026-07-11 (**não verificado**: a Receita não documenta o padrão).
- **Periodicidade:** "mensal" (texto do dados.gov.br, verificado). Na prática houve uma pasta por mês de 2023-05 a 2026-10.

### A2. Licença

- dados.gov.br, campo do conjunto: **"Licença: Creative Commons Attribution"**, sem a versão. Verificado na página renderizada.
- O rodapé dos sites gov.br (e das páginas da Receita) diz que o conteúdo do site está sob "Creative Commons Atribuição-SemDerivações 3.0 Não Adaptada" (CC BY-ND 3.0). Isso vale para o conteúdo do portal, não necessariamente para o conjunto de dados; para os dados vale o campo do dados.gov.br.
- Um usuário perguntou na discussão do próprio conjunto (28/06/2023) qual normativo atribuiu a licença; não há resposta oficial com norma. A versão da CC BY: **não verificado**.

### A3. Arquivos, tamanhos e formato (mês 2026-10)

| Grupo | Zips | Tamanho somado (bytes) | Arquivo interno (exemplo) |
|---|---|---|---|
| Empresas | 10 (`Empresas0`..`9`) | 1.386.551.928 | `K3241.K03200Y0.D61010.EMPRECSV` |
| Estabelecimentos | 10 | 5.416.929.969 | `K3241.K03200Y1.D61010.ESTABELE` |
| Socios | 10 | 643.590.817 | `K3241.K03200Y1.D61010.SOCIOCSV` |
| Simples | 1 | 310.608.217 | `F.K03200$W.SIMPLES.CSV.D61010` |
| Cnaes | 1 | 22.078 | `F.K03200$Z.D61010.CNAECSV` |
| Motivos | 1 | 1.180 | `F.K03200$Z.D61010.MOTICSV` |
| Municipios | 1 | 43.443 | — |
| Naturezas | 1 | 1.585 | `F.K03200$Z.D61010.NATJUCSV` |
| Paises | 1 | 2.745 | — |
| Qualificacoes | 1 | 980 | `F.K03200$Z.D61010.QUALSCSV` |
| **Total** | **37** | **7.808.752.942** (≈ 7,81 GB; 7,27 GiB) | |

Formato, verificado nos próprios arquivos (amostras e varredura completa de Empresas e Estabelecimentos):
- Um único arquivo por zip, comprimido com deflate (método 8). Extensão interna fora do padrão (`...CSV`, `...ESTABELE`), sem `.csv`.
- **Sem cabeçalho.** Separador `;`, todos os campos entre aspas duplas (`"`), fim de linha `\n`.
- **Encoding:** bytes de 1 byte para acentos (`0xE3` = "ã", `0xED` = "í", `0xD3` = "Ó"): ISO-8859-1/Windows-1252; os dois coincidem nesses bytes, e nenhum documento oficial declara o encoding (**não verificado** qual dos dois). O arquivo de Motivos é ASCII puro.
- Números com vírgula decimal (`"120000000000,00"` em capital social). Datas `AAAAMMDD`; no Simples, data ausente vem como `"00000000"`. Campos vazios vêm como `""`.
- **Quebra de linha dentro de campo:** em Estabelecimentos há linhas físicas que começam no meio de um registro, por exemplo `";"PARQUE RESIDENCIAL DA LAPA";"05034000";"SP";...` no arquivo 0. Medido: pelo menos 1 no arquivo 0, 1 no 3 e 2 no 5; nos outros grupos não há. Ou seja, há campos com `\n` dentro das aspas, e o leitor da bronze precisa respeitar as aspas ao separar linhas (o `_linha` da bronze deixa de ser igual ao número da linha física nesses casos).
- Número de campos por linha, medido: Empresas 7, Estabelecimentos 30, Socios 11, Simples 7, domínios 2. Bate com o layout.
- Os zips "0" são maiores porque os arquivos 1–9 têm todos exatamente o mesmo número de linhas (medido, ver A9): a Receita parece cortar em blocos fixos e deixar o resto no arquivo 0 (**inferência**, não documentada).

### A4. Layout oficial

- Documento: "Novo Layout para os DADOS ABERTOS do CNPJ", https://www.gov.br/receitafederal/dados/cnpj-metadados.pdf (59.315 bytes, 6 páginas). Metadados do PDF: título "Microsoft Word - NOVOLAYOUTDOSDADOSABERTOSDOCNPJ-convertido", criado e modificado em 02/12/2021, a mesma data do "Dicionário de dados do CNPJ" listado no dados.gov.br. Não traz número de versão. Que o botão do dados.gov.br aponta exatamente para este PDF: **não verificado** (só a coincidência de data).
- **Códigos (texto do layout):**
  - Porte da empresa: `00` NÃO INFORMADO; `01` MICRO EMPRESA; `03` EMPRESA DE PEQUENO PORTE; `05` DEMAIS.
  - Identificador matriz/filial: `1` MATRIZ; `2` FILIAL.
  - Situação cadastral: `01` NULA; `2` ATIVA; `3` SUSPENSA; `4` INAPTA; `08` BAIXADA. O layout escreve uns com 2 dígitos e outros com 1; no arquivo vêm com 2 dígitos (`"02"`, `"08"`, medido nas amostras).
  - Opção pelo Simples / pelo MEI: `S` SIM; `N` NÃO; em branco OUTROS.
  - Identificador de sócio: `1` PESSOA JURÍDICA; `2` PESSOA FÍSICA; `3` ESTRANGEIRO.
  - Faixa etária: `1` 0–12 anos; `2` 13–20; `3` 21–30; `4` 31–40; `5` 41–50; `6` 51–60; `7` 61–70; `8` 71–80; `9` mais de 80; `0` não se aplica.
  - CNAE fiscal secundária: várias ocorrências separadas por vírgula, no mesmo campo.
  - CPF de sócio e de representante: mascarado (ocultos os 3 primeiros dígitos e os 2 verificadores), com base no art. 129 § 2º da Lei 13.473/2017. No arquivo aparece como `***240659**`.
  - Ente federativo responsável: preenchido só para natureza jurídica do grupo 1XXX.
  - Motivo da situação cadastral: é um campo de Estabelecimentos e existe o arquivo `Motivos.zip`, mas o layout **não descreve** a tabela de domínio de motivos (lista só Países, Municípios, Qualificações, Naturezas e CNAEs). O arquivo tem 2 colunas, como os outros domínios (`"00";"SEM MOTIVO"`).
- **Mudança não documentada no layout (verificado):** em Socios, o campo "CNPJ/CPF DO SÓCIO" de sócio pessoa jurídica vinha com 14 dígitos em 2026-07 (`"79942645000101"`) e vem com 8 dígitos (só o CNPJ básico) em 2026-10 (`"79942645"`), para as mesmas linhas. O layout de 2021 não registra isso. Um projeto de terceiros (github.com/rictom/cnpj-sqlite, não oficial) diz que a mudança é de agosto/2026.

### A5. CNPJ alfanumérico

- **Norma:** a FAQ oficial da Receita (https://www.gov.br/receitafederal/pt-br/centrais-de-conteudo/publicacoes/perguntas-e-respostas/cnpj/cnpj-alfanumerico.pdf), pergunta 26: "conforme consta da Instrução Normativa 2.119/2022, com as alterações introduzidas pela Instrução Normativa RFB 2.229/2024, o cronograma para implementação do CNPJ alfanumérico será julho de 2026". Verificado na FAQ; o texto da IN em si não foi aberto.
- **Início efetivo:** notícia oficial do Ministério da Fazenda (https://www.gov.br/fazenda/pt-br/assuntos/noticias/2026/julho/receita-federal-gera-o-primeiro-cnpj-em-formato-alfanumerico/, publicada em 31/07/2026, atualizada em 26/10/2026): o primeiro CNPJ alfanumérico foi gerado em 31/07/2026, para uma unidade do Banco do Brasil, `00.000.000/E08G-12`. Os novos números "serão emitidos gradualmente durante o ano de 2026"; os CNPJs anteriores "permanecem válidos".
- **Formato (FAQ, perguntas 2, 20 e 27–28):** 14 posições, `AA.AAA.AAA/AAAA-DV`, as 12 primeiras podem ser 0–9 ou A–Z maiúsculas e os 2 DV são numéricos. Só novas inscrições; a atribuição é aleatória e uma inscrição nova ainda pode receber número só numérico. O sufixo `0001` deixa de identificar a matriz com certeza (pergunta 25, trecho lido: "o sufixo 0001 deixa de ser um identificador definitivo de matriz").
- **Dígito verificador (FAQ, pergunta 14): confirmado, valor = código ASCII − 48.** Módulo 11, com cada caractere convertido pelo código ASCII menos 48 ("0" = 48 → 0, ..., "9" = 57 → 9, "A" = 65 → 17, ..., "Z" = 90 → 42). Exemplo oficial: `12.ABC.345/01DE` → 1º DV: soma 459, 459 mod 11 = 8, DV = 11 − 8 = 3; 2º DV: soma 424, mod 11 = 6, DV = 5 → `12.ABC.345/01DE-35`. Os pesos são os mesmos do CNPJ numérico (5,4,3,2,9,8,7,6,5,4,3,2 e depois 6,5,4,3,2,9,...). A regra "resto 0 ou 1 → DV 0" não aparece no trecho que li da FAQ (**não verificado** nessa fonte; é a regra do módulo 11 numérico).
- **Os dados abertos já trazem CNPJ alfanumérico? Sim, mas em 2026-10 é só um (medido).** Varri todos os registros de 2026-10: o cnpj_basico de Empresas e Socios, o cnpj_basico, o cnpj_ordem e o cnpj_dv de Estabelecimentos, e o cnpj_basico do Simples. **Um único registro tem letra:** em `Estabelecimentos5`, `"00000000";"E08G";"12";"2";"";"02";"20260731";...` (o `00.000.000/E08G-12` do Banco do Brasil, filial, situação 02, início em 31/07/2026). O cnpj_basico continua numérico em todos os registros; a letra está no cnpj_ordem. O layout não mudou: mesmos 30 campos, e os campos de CNPJ já eram texto entre aspas. Não encontrei comunicado oficial sobre o alfanumérico nos dados abertos (**não verificado**). Consequência para o projeto: os campos de CNPJ precisam ser texto em todas as camadas, e o cálculo do DV precisa da regra ASCII − 48.

### A6. Consulta oficial de poucos CNPJs, sem baixar tudo

- **Consulta pública gratuita, sem API:** serviço "Consultar Cadastro Nacional de Pessoas Jurídicas" (https://www.gov.br/pt-br/servicos/consultar-cadastro-nacional-de-pessoas-juridicas): "Este serviço é gratuito para o cidadão", só pela web (Portal REDESIM, consultacnpj.redesim.gov.br), exige conta gov.br nível Prata ou Ouro. Um CNPJ por vez; não é para uso automatizado.
- **API Consulta CNPJ no Conecta gov.br** (https://www.gov.br/conecta/catalogo/apis/consulta-cnpj): da Receita, gateway no Serpro, com adesão para "órgão Público Federal e Estadual", liberação de IP no firewall e token JWT. Não é aberta a pessoas e empresas.
- **API Consulta CNPJ do Serpro (paga):** https://loja.serpro.gov.br/consulta-cnpj/product/consultacnpj (link tirado da notícia oficial do Serpro de 24/09/2026, https://www.serpro.gov.br/menu/noticias/noticias-2026/contratacao-entidades-representativas: "Cada empresa paga pelo que utiliza"). A loja respondeu 403 ao acesso automatizado; preço atual: **não verificado**.
- **Conclusão:** não há API oficial aberta e gratuita. APIs de terceiros (ex.: CNPJ.ws, BrasilAPI, ReceitaWS): **não oficiais**, não avaliadas.

### A7. Tamanho exato de cada zip de 2026-10 (`getcontentlength` da listagem WebDAV)

| Arquivo | Bytes | Arquivo | Bytes |
|---|---|---|---|
| Cnaes.zip | 22.078 | Estabelecimentos5.zip | 335.452.647 |
| Empresas0.zip | 570.972.127 | Estabelecimentos6.zip | 369.782.592 |
| Empresas1.zip | 77.901.368 | Estabelecimentos7.zip | 338.419.961 |
| Empresas2.zip | 79.125.712 | Estabelecimentos8.zip | 343.568.209 |
| Empresas3.zip | 85.102.880 | Estabelecimentos9.zip | 364.761.032 |
| Empresas4.zip | 90.222.463 | Motivos.zip | 1.180 |
| Empresas5.zip | 97.310.075 | Municipios.zip | 43.443 |
| Empresas6.zip | 94.194.819 | Naturezas.zip | 1.585 |
| Empresas7.zip | 98.676.055 | Paises.zip | 2.745 |
| Empresas8.zip | 98.736.571 | Qualificacoes.zip | 980 |
| Empresas9.zip | 94.309.858 | Simples.zip | 310.608.217 |
| Estabelecimentos0.zip | 2.277.696.710 | Socios0.zip | 251.430.070 |
| Estabelecimentos1.zip | 341.948.627 | Socios1.zip | 49.546.399 |
| Estabelecimentos2.zip | 336.288.966 | Socios2.zip | 49.056.863 |
| Estabelecimentos3.zip | 368.597.760 | Socios3.zip | 49.011.621 |
| Estabelecimentos4.zip | 340.413.465 | Socios4.zip | 49.560.198 |
| | | Socios5.zip | 49.063.747 |
| | | Socios6.zip | 49.147.194 |
| | | Socios7.zip | 49.212.792 |
| | | Socios8.zip | 49.447.177 |
| | | Socios9.zip | 49.114.756 |

**Total: 37 arquivos, 7.808.752.942 bytes** (bate com o `quota-used-bytes` da pasta 2026-10). Todos com `getlastmodified` em 13/10/2026 entre 22:00 e 22:09 GMT. Velocidade medida de download: cerca de 4,2 MB/s, então o mês inteiro leva perto de 30 min numa conexão como a de hoje (estimativa a partir de uma única medição).

### A8. Checksum / hash publicado

- **A Receita não publica checksum.** Nas pastas 2026-10 e na raiz do compartilhamento só há os `.zip` (e o `cnpj.tar.gz`); não há `.md5`, `.sha256` nem arquivo de manifesto. A propriedade `oc:checksums` do Nextcloud volta 404 (não existe).
- O `ETag` do WebDAV (ex.: Motivos.zip `316cb8cf396e749f726cb991cd60be6a`) **não é hash do conteúdo**: o MD5 real do Motivos.zip é `c61eb44149f8cdfb445d5ad265c8cc30`. O ETag é um identificador de versão do Nextcloud; serve para detectar que o arquivo mudou, não para validar a integridade.
- Validação possível: o CRC-32 de cada membro do zip (está no próprio zip) e o tamanho do `getcontentlength`. O hash do projeto (`_hash_arquivo`) tem de ser calculado pela ingestão.

### A9. Quantidade de linhas

A fonte oficial **não publica** a contagem de linhas (nem o layout nem o dados.gov.br). Os números abaixo são **medidos** por mim no mês 2026-10, contando as linhas físicas descompactadas (separadas por `\n`):

| Grupo | Linhas físicas por arquivo | Total de linhas físicas | Observação |
|---|---|---|---|
| Empresas | 0: 30.063.698; 1–9: 4.494.860 cada | **70.517.438** | 1 linha = 1 registro nos arquivos 1–9 (conferido pelo início de registro); no 0 só contei as linhas |
| Estabelecimentos | 0: 31.028.468; 1, 2, 4, 6–9: 4.753.435 cada; 3: 4.753.436; 5: 4.753.437 | **73.809.386** | nos arquivos 1–9 são 4.753.435 registros cada; as linhas a mais (1 no arquivo 3, 2 no 5 e pelo menos 1 no 0) são quebras de linha dentro de campo. Registros ≈ 73,8 milhões |
| Socios | 0: 10.323.611; 1–9: 2.019.150 cada | **28.495.961** | 1 linha = 1 registro nos arquivos 1–9 |
| Simples | 50.806.102 | **50.806.102** | 1 linha = 1 registro |

Os arquivos 1–9 de cada grupo têm o mesmo número de registros, o que reforça a leitura de que a Receita corta em blocos fixos e deixa o resto no arquivo 0 (inferência). Volume descompactado: não somei; o zip comprime cerca de 4–5 vezes nas amostras, então são algumas dezenas de GB em texto (**estimativa**, não medida).

### A10. Nomes das colunas exatamente como o layout oficial escreve

Os arquivos não têm cabeçalho; a ordem abaixo é a do layout e bate com o número de campos medido em cada arquivo. Os nomes estão como no PDF, em maiúsculas e com acento; onde o PDF quebra o nome em várias linhas, juntei com espaço.

**EMPRESAS** (7):
1. CNPJ BÁSICO
2. RAZÃO SOCIAL / NOME EMPRESARIAL
3. NATUREZA JURÍDICA
4. QUALIFICAÇÃO DO RESPONSÁVEL
5. CAPITAL SOCIAL DA EMPRESA
6. PORTE DA EMPRESA
7. ENTE FEDERATIVO RESPONSÁVEL

**ESTABELECIMENTOS** (30):
1. CNPJ BÁSICO
2. CNPJ ORDEM
3. CNPJ DV
4. IDENTIFICADOR MATRIZ/FILIAL
5. NOME FANTASIA
6. SITUAÇÃO CADASTRAL
7. DATA SITUAÇÃO CADASTRAL
8. MOTIVO SITUAÇÃO CADASTRAL
9. NOME DA CIDADE NO EXTERIOR
10. PAIS
11. DATA DE INÍCIO ATIVIDADE
12. CNAE FISCAL PRINCIPAL
13. CNAE FISCAL SECUNDÁRIA
14. TIPO DE LOGRADOURO
15. LOGRADOURO
16. NÚMERO
17. COMPLEMENTO
18. BAIRRO
19. CEP
20. UF
21. MUNICÍPIO
22. DDD 1
23. TELEFONE 1
24. DDD 2
25. TELEFONE 2
26. DDD DO FAX
27. FAX
28. CORREIO ELETRÔNICO
29. SITUAÇÃO ESPECIAL
30. DATA DA SITUAÇÃO ESPECIAL

**DADOS DO SIMPLES** (7):
1. CNPJ BÁSICO
2. OPÇÃO PELO SIMPLES
3. DATA DE OPÇÃO PELO SIMPLES
4. DATA DE EXCLUSÃO DO SIMPLES
5. OPÇÃO PELO MEI
6. DATA DE OPÇÃO PELO MEI
7. DATA DE EXCLUSÃO DO MEI

**SÓCIOS** (11):
1. CNPJ BÁSICO
2. IDENTIFICADOR DE SÓCIO
3. NOME DO SÓCIO (NO CASO PF) OU RAZÃO SOCIAL (NO CASO PJ)
4. CNPJ/CPF DO SÓCIO
5. QUALIFICAÇÃO DO SÓCIO
6. DATA DE ENTRADA SOCIEDADE
7. PAIS
8. REPRESENTANTE LEGAL
9. NOME DO REPRESENTANTE
10. QUALIFICAÇÃO DO REPRESENTANTE LEGAL
11. FAIXA ETÁRIA

**Tabelas de domínio** (PAÍSES, MUNICÍPIOS, QUALIFICAÇÕES DE SÓCIOS, NATUREZAS JURÍDICAS, CNAEs), 2 colunas cada:
1. CÓDIGO
2. DESCRIÇÃO

MOTIVOS não aparece no layout; o arquivo tem as mesmas 2 colunas.

Observações para a bronze:
- Os nomes do layout têm espaço, acento, barra e parênteses, e "PAIS" se repete entre tabelas. Para virar nome de coluna no padrão do projeto é preciso uma conversão determinística (minúsculas, sem acento, `_`), registrada como decisão. Os nomes que a comunidade costuma usar (`cnpj_basico`, `razao_social`, `natureza_juridica`, `qualificacao_responsavel`, `capital_social`, `porte_empresa`, `ente_federativo_responsavel`, ...) **não são oficiais**: o documento da Receita só traz os nomes acima.
- Nomes curtos que o projeto usar no `fontes.yml` devem guardar o nome do layout como descrição, para manter a rastreabilidade à origem.

## Parte B — Referências: URL oficial e se a cópia num repositório público é permitida

| Referência | URL oficial | Situação de licença (verificada) | Veredito |
|---|---|---|---|
| Kimball Group — técnicas de modelagem dimensional | Índice: https://www.kimballgroup.com/data-warehouse-business-intelligence-resources/kimball-techniques/dimensional-modeling-techniques/ · junk: `.../junk-dimension/` · conformed: `.../conformed-dimension/` · role-playing: `.../role-playing-dimension/` · degenerate: `.../degenerate-dimension/` · surrogate key: `.../dimension-surrogate-key/` (todas responderam 200) | Rodapé: "The Kimball Group. All Rights Reserved." Não há licença aberta. | **Só nota com link** (citação curta com fonte, no máximo) |
| Microsoft Learn — "Understand star schema and the importance for Power BI" | https://learn.microsoft.com/en-us/power-bi/guidance/star-schema (ms.date 2024-12-30; updated_at 2026-04-01) | A fonte da página está no repositório **privado** `MicrosoftDocs/powerbi-docs-pr` (meta `original_content_git_url`); `MicrosoftDocs/powerbi-docs` responde 404 no GitHub, então não há LICENSE público (CC BY 4.0) que eu possa verificar para esta página. Os Termos de Uso (https://learn.microsoft.com/en-us/legal/termsofuse) dizem que, salvo indicação em contrário, os serviços são para uso pessoal e não comercial e proíbem copiar e distribuir sem consentimento. | **Só nota com link** |
| dbt — "How we structure our dbt projects" e "Analyses" | https://docs.getdbt.com/best-practices/how-we-structure/1-guide-overview (e `2-staging`, `4-marts`, que traz "storage is cheap and compute is expensive") · https://docs.getdbt.com/docs/build/analyses | Repositório público `dbt-labs/docs.getdbt.com`, licença **Apache-2.0** (`License.md`); as páginas estão nele (`website/docs/best-practices/how-we-structure/*.md`, `website/docs/docs/build/analyses.md`). | **Cópia permitida** (Apache 2.0: incluir a licença, manter os avisos e marcar o que foi alterado) |
| CDC, Lei 8.078/1990, arts. 42 e 71 | https://www.planalto.gov.br/ccivil_03/leis/l8078compilado.htm | Texto de lei: não é protegido por direito autoral (Lei 9.610/1998, art. 8º, IV: "os textos de tratados ou convenções, leis, decretos, regulamentos, decisões judiciais e demais atos oficiais", verificado em https://www.planalto.gov.br/ccivil_03/leis/l9610.htm). Arts. 42 e 71 conferidos na página. | **Cópia permitida** (art. 8º, IV) |
| LGPD, Lei 13.709/2018, arts. 6º e 7º | https://www.planalto.gov.br/ccivil_03/_ato2015-2018/2018/lei/l13709compilado.htm | Idem; arts. 6º (princípios) e 7º (bases legais, incl. IX legítimo interesse e X proteção do crédito) conferidos. | **Cópia permitida** (art. 8º, IV) |
| Lei estadual SP 17.832/2023, art. 51 | https://www.al.sp.gov.br/repositorio/legislacao/lei/2023/compilacao-lei-17832-01.11.2023.html (original: `.../lei-17832-01.11.2023.html`) | Lei estadual é ato oficial (art. 8º, IV). Art. 51, conferido: telefonemas de cobrança "de segunda a sexta-feira, das 8h00 (oito horas) às 20h00 (vinte horas), e aos sábados, das 8h00 (oito horas) às 14h00 (catorze horas), excetuando-se os feriados, casos em que tais telefonemas são vedados." Sem nota de alteração no art. 51. A página registra uma ADI no TJSP (nº 2342591-64.2023.8.26.0000) e a suspensão do art. 195; se a ADI alcança o art. 51: não verificado. | **Cópia permitida** (art. 8º, IV) |
| Febraban — Normativo SARB nº 27/2023 (CNRC), art. 32 | Página: https://www.autorregulacaobancaria.com.br/pagina/17/16/pt-br/normativos · PDF vigente: https://cmsarquivos.autorregulacaobancaria.com.br/Arquivos/documentos/PDF/Normativo%2027-2023%20-%20CNRC%20(alterado%20pelas%20Delibera%C3%A7%C3%B5es%2068%20e%2069%2C%20de%202026).pdf | Rodapé do site: "© FEBRABAN - Todos os Direitos Reservados". É norma privada de autorregulação, não ato oficial; o art. 8º, IV não se aplica (**interpretação minha**). Art. 32, redação da Deliberação nº 55/2024, conferido: contatos ativos "exclusivamente segunda-feira a sexta-feira, entre 07h e 21h; e aos sábados, entre 09h e 16h, salvo legislação específica"; contato digital a qualquer dia e hora; horários alternativos só com agendamento ou autorização prévia comprovada; vale também para a cobrança feita pela própria instituição. Art. 32-A (Deliberação nº 61/2024): proíbe ligações para cobrar dívidas vencidas há mais de 5 anos. | **Só nota com link** |
| Lei 662/1949, com a redação da Lei 10.607/2002 (feriados nacionais) | https://www.planalto.gov.br/ccivil_03/leis/l0662.htm | Ato oficial (art. 8º, IV). Art. 1º, conferido: "São feriados nacionais os dias 1º de janeiro, 21 de abril, 1º de maio, 7 de setembro, 2 de novembro, 15 de novembro e 25 de dezembro." **Atenção:** a Lei 662 não lista todos os feriados nacionais. A Lei 6.802/1980 (https://www.planalto.gov.br/ccivil_03/leis/l6802.htm) declara feriado nacional o 12 de outubro, e a Lei 14.759/2023 (https://www.planalto.gov.br/ccivil_03/_ato2023-2026/2023/lei/l14759.htm, de 21/12/2023) declara o 20 de novembro. Ambas conferidas. | **Cópia permitida** (art. 8º, IV) |

Notas da Parte B:
- O art. 8º, IV cobre o **texto** da lei. A página do Planalto ou da Alesp como um todo (layout, notas editoriais) não foi avaliada; copiar só o texto dos artigos usados, com URL e data de acesso, é o caminho seguro.
- Para Microsoft Learn: se o projeto quiser uma cópia, seria preciso achar a página num repositório público com LICENSE CC BY 4.0. Para esta página, não encontrei.
