# Plano — enriquecimento por CNPJ (etapa 7, aprovado em 2026-11-10)

Decisões fechadas com o dono na rodada de fechamento (2026-11-10). Pesquisa das fontes oficiais: `pesquisa-receita.md` neste tópico.

## 1. Objetivo e base no enunciado
Cruzar os empregadores recebidos com os dados abertos do CNPJ da Receita Federal (dados.gov.br) e mostrar o que isso agrega à cobrança (p. 1, "Enriquecer vínculos empregatícios"; p. 2, "Enriquecimento cadastral e valor de negócio").

## 2. Decisões
- **C1. A Receita é uma fonte, `receita`,** com o mesmo padrão das outras: `bronze_receita.<entidade>` → `silver_receita.<entidade>` → gold. Bronze e silver mantêm os nomes de coluna do layout oficial (`cnpj-metadados.pdf`, 02/12/2021) e os valores como vieram. Os nomes das colunas vêm do layout, porque os arquivos não têm cabeçalho: escritos em minúsculas, com `_` entre as palavras e sem acento, exatamente na ordem do layout. A regra de transcrição fica documentada.
- **C2. O conector `receita`** (`@conector("receita")` em `ingestion/conectores.py`) usa o WebDAV público do compartilhamento oficial da Receita, com o mês 2026-10 fixado em `ingestion/fontes.yml`. Ele baixa os 37 arquivos (7,8 GB) para um cache local fora do git, calcula o sha256 de cada um (a Receita não publica checksum) e grava em `external_data/receita/2026-10/`, a pasta versionada:
  - as 6 tabelas de domínio inteiras: `cnaes`, `motivos`, `municipios`, `naturezas`, `paises`, `qualificacoes`;
  - das tabelas `empresas`, `estabelecimentos`, `simples` e `socios`, as linhas das empresas recebidas (raiz de 8 caracteres dos CNPJs da silver);
  - `ORIGEM.md`, com a URL, o mês, os bytes e o sha256 de cada arquivo baixado, a lista de raízes e o hash dela.
  O conector roda só quando chamado (`python -m ingestion.main --baixar receita` ou equivalente, desenhado no passo 7.1). A pipeline e o CI leem só a pasta versionada (offline e reprodutível). Mesma origem e mesmo mês dão os mesmos arquivos.
- **C3. Leitor.** O `csv` existente passa a aceitar, por configuração, a lista de colunas para arquivo sem cabeçalho, o encoding (`latin-1`) e o separador (`;`); as aspas seguem o CSV, inclusive a quebra de linha dentro de campo de Estabelecimentos. Um formato novo só entra se o existente não couber.
- **C4. Silver.** Tipos (datas AAAAMMDD, "00000000" como `NULL`, capital social com vírgula decimal), CNPJ completo montado de raiz + ordem + DV, validado pela regra do DV alfanumérico (valor = ASCII − 48), deduplicação pela chave de cada tabela com teste de chave primária.
- **C5. Gold.** A `dim_empregador` recebe da silver da Receita: razão social, natureza jurídica (código e descrição), porte, situação cadastral (código, descrição, data e motivo), CNAE principal e descrição, UF, município, data de início da atividade e opção pelo Simples/MEI. CNPJ ausente da Receita: `situacao_receita = 'nao_encontrado'` e os atributos `NULL`. Os nomes seguem as colunas da gold do AGENTS.md (`cnae`, `desc_cnae`, `situacao_cadastral`, `desc_situacao_cadastral`, ...).
- **C6. Achado esperado.** São 13 CNPJs recebidos, todos com DV válido, 3 deles alfanuméricos. A base de 2026-10 tem um único CNPJ alfanumérico, e ele não é nenhum dos três, então eles vão aparecer como `nao_encontrado`. Isso vai para o README como achado sobre os dados sintéticos.

## 3. Sequência
Branch `feat/enriquecimento-cnpj` a partir da `develop`, num worktree próprio (banco DuckDB próprio). Os passos 7.1 a 7.3 não dependem da gold e correm em paralelo com ela. O 7.4 começa depois do merge da gold: `git merge develop` no branch antes.

### 7.1 Conector e extrato
- **Quem:** `engenheiro-python` (Sonnet 5.5 · high). Teste primeiro, com pytest e um servidor WebDAV falso, sem rede; skill qualidade-python.
- **Fazer:** C2 e C3; rodar o download real uma vez, gerar o extrato e o `ORIGEM.md`; o cache dos zips fica no `.gitignore`.
- **Commits:** `feat: conector da Receita grava extrato versionado dos dados abertos do CNPJ`; `feat: extrato de 2026-10 dos dados abertos do CNPJ` (só os arquivos da pasta versionada e o `ORIGEM.md`).

### 7.2 Bronze
- **Quem:** `engenheiro-sql` (Sonnet 5.5 · medium).
- **Fazer:** as entidades em `ingestion/fontes.yml` e o contrato em `models/bronze/receita/_fontes.yml`, com descrição e testes.
- **Commit:** `feat: bronze da Receita com as tabelas do CNPJ`.

### 7.3 Silver
- **Quem:** `engenheiro-sql` (Sonnet 5.5 · high).
- **Fazer:** C4, uma tabela por entidade.
- **Commit:** `feat: silver da Receita com tipos, CNPJ completo e deduplicação`.

### 7.4 Gold
- **Quem:** `engenheiro-sql` (Sonnet 5.5 · medium).
- **Fazer:** C5 na `dim_empregador`, com `LEFT JOIN`, e um teste de que todo CNPJ recebido tem linha.
- **Commit:** `feat: empregadores enriquecidos com os dados abertos da Receita`, com quantos CNPJs foram encontrados no corpo.

### 7.5 Documentação do componente
- **Quem:** `analista-dados` (Opus 5.5 · medium).
- **Fazer:** a seção do componente de ingestão em `docs/` (conector, leitor, configuração, como trazer uma fonte nova, exemplo da Receita como API) e a seção da Receita em `docs/decisoes-de-modelagem.md` (C1–C6, opções descartadas e medidas da pesquisa). O componente é um dos diferenciais do projeto.
- **Commit:** `docs: componente de ingestão multi-fonte e a fonte da Receita`.

### 7.6 Verificação em bloco e merge
- `verificador` APROVADO (pipeline do zero, execuções idênticas, lint, pytest) e `revisor` sem achado que bloqueie. Cada achado vira um commit próprio. Depois, merge `--no-ff` na `develop` com `chore: integra enriquecimento-cnpj na develop`.

## 4. Quando chamar o dono
Só quando um número medido contradiz uma decisão aprovada, quando uma regra do enunciado ou do AGENTS.md não cabe no decidido, quando uma verificação falha sem correção óbvia ou quando aparece uma ação externa fora deste plano. O download do 7.1 já está autorizado.

## 5. Regras de commit
Identidade Sebastian6-6, sem Co-Authored-By, mensagem com assunto e até 3 linhas de porquê, 1ª pessoa do singular ou impessoal, nenhum caminho absoluto, nunca `--no-verify`.
