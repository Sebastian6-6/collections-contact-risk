# AGENTS.md

Regras do repositório para pessoas e agentes de IA. São duas partes: as convenções que vieram com o case, mantidas exatamente como foram recebidas, e as convenções que adotei neste projeto.

## Convenções do case (originais — não editar)

Recebidas junto com o case. O texto abaixo é idêntico ao original; só os títulos desceram um nível (`##` → `###`) para caber nesta seção.

### Estrutura

- `ingestion/`: leitura dos arquivos dos provedores, sem transformação.
- `models/`: transformações em SQL, organizadas por camada (`bronze/`, `silver/`, `gold/`).
- `docs/`: ERD, decisões de modelagem e dicionário de dados.

### SQL

- Dialeto padrão: PostgreSQL.
- Funções nativas e tipos de dado em UPPER CASE (`SELECT`, `COALESCE`, `NUMERIC`).
- Uma CTE por etapa lógica, com nome descritivo.
- Funções de janela: usar apenas `ROW_NUMBER()` e `SUM()`, sempre com o frame declarado em `ROWS BETWEEN`.
- Ausência de dado é `NULL`, nunca zero.
- Modelos não geram linhas que não existam na origem: cada linha corresponde a um registro recebido.
- Nunca usar `SELECT *` em modelos das camadas silver e gold.
- Indentação de 2 espaços.

### Commits

- Seguir Conventional Commits (`feat:`, `fix:`, `docs:`, `chore:`, `refactor:`).
- Um commit por mudança lógica. Mensagens descrevem o porquê, não só o quê.

## Convenções do projeto

Complementam as convenções do case acima e nunca as contradizem. Em caso de conflito, valem as do case.

### Hierarquia de regras

Em caso de conflito, a regra de nível mais alto prevalece:

1. **Enunciado do case** (`.context/converted/`, ver `.context/index.md`). Toda decisão se apoia nele e segue os seus direcionamentos; ao justificar uma escolha, cite a página.
2. **Este AGENTS.md**: é a fonte única das regras do repositório. As convenções do case (seção anterior) vêm antes das convenções do projeto. O `.claude/CLAUDE.md` só importa este arquivo e guarda as ferramentas do Claude; nenhuma regra do projeto fica lá nem no `.context/PROJECT.md`, que é só memória.
3. **Boas práticas de engenharia de dados**: soluções elegantes, análise explícita de trade-offs em cada decisão e o máximo de reprodutibilidade e resiliência na pipeline. Exemplo: se uma tabela nova entra numa fonte que já existe, a ingestão e o tratamento até a silver reaproveitam o componente dessa fonte, com configuração em vez de código novo.

Regras que valem só para uma etapa ou um tópico de trabalho não entram aqui: ficam registradas no próprio tópico, em `.context/topics/<tópico>/STATE.md`, e nunca contradizem este arquivo.

### Modo de trabalho

- **Decisões documentadas.** Cada decisão registra as opções consideradas, os trade-offs e a base no enunciado.
- **Pesquisar antes de afirmar.** Fazer várias buscas na web (documentação oficial primeiro) e afirmar só o que estiver apoiado em contexto real e verificado. Na dúvida, dizer que não foi verificado em vez de supor.
- **Documentação de referência.** Documentação externa usada no projeto (APIs, ferramentas, layouts oficiais) fica em `.context/raw/referencias/`, só nas seções usadas, com URL, versão e data de acesso na origem. Antes de tomá-la como base, confirmar na fonte oficial que ela é a versão mais atual; se houver versão nova, atualizar a cópia ou registrar por que o projeto segue na anterior. A versão documentada é sempre a mesma usada no projeto. Ela embasa as decisões, mas não entra na hierarquia de regras.
- **Dependências.** As dependências Python diretas ficam em `requirements.in`, na raiz. O `requirements.txt` é gerado a partir dele com `uv pip compile --universal`, com todas as versões fixas (inclusive as indiretas), e é o único arquivo usado na instalação, para a execução ser reprodutível.

### Stack

- Motor: DuckDB, embutido; o banco é recriado do zero a cada execução da pipeline.
- Transformações em dbt Core, com o adaptador dbt-duckdb.
- O SQL dos modelos fica no subconjunto compatível com PostgreSQL, como pede a convenção do case. As diferenças entre DuckDB e PostgreSQL a evitar estão em `.context/converted/referencias-duckdb-postgresql-compatibility-2-0.md`.
- As versões exatas ficam só no `requirements.txt`.
- Todo código Python e SQL segue as convenções de `.claude/skills/convencoes-codigo-pessoal/SKILL.md`, com as adaptações da seção "Estilo do código".
- Reprodutibilidade: nenhuma tabela guarda horário de execução (como um `process_time`). A rastreabilidade de cada linha vem do nome, do número da linha e do hash do arquivo de origem, de modo que duas execuções a partir do mesmo estado inicial produzem exatamente o mesmo resultado.

### Estilo do código

As skills de qualidade (`.claude/skills/qualidade-sql` e `qualidade-python`) são genéricas; as regras deste projeto chegam a elas pela configuração da raiz (`.sqlfluff`, `ruff.toml` e as seções `[tool.*]` do `pyproject.toml`). O mapa entre cada regra e a checagem que a garante está em `docs/qualidade-e-convencoes.md`.

- **SQL:** o estilo pessoal, adaptado ao case.
  - Recuo de 2 espaços, como pede a convenção do case. Por isso o alinhamento em colunas do estilo pessoal (vírgulas alinhadas, `FROM` à direita, `AS` numa coluna fixa) não se aplica aqui.
  - A 1ª coluna vai na linha de baixo do `SELECT`: a regra do SQLFluff que verifica os 2 espaços do case exige essa quebra.
  - Vírgula no começo da linha; `WHERE 1 = 1` seguido de um `AND` por predicado.
  - `AS` só quando a coluna muda de nome ou é uma expressão; coluna repassada sem mudança não leva `AS`.
  - CTEs no padrão `tNomeCte` (`tBase`, `tDevedoresValidos`). O case pede só um nome descritivo para cada CTE, e o PostgreSQL aceita o nome sem aspas; é a única exceção ao snake_case.
  - Valem as demais regras do estilo pessoal: linha em branco entre grupos de colunas, `UNION ALL` sozinho na linha, `CAST(NULL AS TIPO)` nos `UNION`, nenhuma vírgula sobrando.
  - O SQLFluff, com o templater do dbt, aplica essas regras.
- **Python:** o estilo pessoal, inclusive o alinhamento vertical de atribuições e argumentos relacionados, com uma adaptação: linhas de até 99 colunas, que o `ruff check` cobra. Como o formatador desfaria o alinhamento, o projeto roda `ruff check`, e não `ruff format`.

### Ingestão

- **A ingestão grava a bronze.** `python -m ingestion.main` (ou `python pipeline.py`, que também recria o banco e roda o dbt) lê **todos** os arquivos recebidos a cada execução e grava uma linha por linha recebida em `bronze_<fonte>.<entidade>`, sem transformar. `contact_data/` é a zona bruta imutável. Não há cópia intermediária nem modos de carga: o banco é recriado do zero, então reler tudo é o que garante execuções idênticas.
- **Colunas.** No CSV, a união dos cabeçalhos de todos os arquivos da entidade, em texto (`NULL` onde o arquivo não tem a coluna); no JSON Lines, `registro` com o texto da linha. Em toda tabela: `_arquivo` (caminho relativo), `_linha`, `_hash_arquivo`, `_linha_original` e `_motivo_ilegivel`. O registro de cargas fica em `bronze_<fonte>.arquivos`.
- **Ilegível** é só a linha que o leitor não consegue separar em colunas; ela entra com o texto e o motivo, e nenhuma linha é descartada. Um byte fora do encoding interrompe a fonte, com o arquivo e a linha no erro.
- **Sem horário de execução, data de modificação ou id aleatório**: a rastreabilidade vem do arquivo, da linha e do hash.
- **Fonte nova.** Cada provedor ou sistema que produz dados é uma fonte. Para acrescentar:
  1. Formato e origem já existem: uma entrada em `ingestion/fontes.yml`.
  2. Formato novo: uma função em `ingestion/leitores.py` com `@leitor("nome")`.
  3. Origem nova (API, bucket): uma função em `ingestion/conectores.py` com `@conector("nome")`. Uma API grava a resposta como arquivo numa pasta versionada antes de ser lida.
  4. Declarar a tabela em `models/bronze/<fonte>/_fontes.yml`. O `main.py` não muda.
- Datas e horas que chegam sem fuso são tratadas como horário de Brasília; valores em epoch são convertidos para esse fuso (UTC−3, sem horário de verão desde o Decreto 9.772/2019).

### Camadas e nomes

- O banco tem três camadas:
  - **bronze:** tudo o que foi recebido, como veio, gravado pela ingestão. `models/bronze/` guarda o contrato dessas tabelas (fontes do dbt, com descrição e testes), sem SQL.
  - **silver:** trabalha dentro de uma fonte só: tipos, limpeza, normalização, listas abertas em linhas e deduplicação de cada tabela pela sua chave, com `ROW_NUMBER()`. Toda a padronização vem antes da deduplicação, e toda tabela que muda de grão tem teste de chave primária.
  - **gold:** une as fontes, resolve conflitos, aplica as regras de negócio e expõe o modelo dimensional.
- Cada provedor é uma fonte (`alfa`, `beta`, `gama`); o histórico de contatos é a fonte `cobranca`.
- Schemas no banco: `bronze_<fonte>`, `silver_<fonte>` e `gold`. A tabela leva só o nome da entidade (`bronze_alfa.devedores`).
- O dbt exige nomes de modelo únicos, por isso o arquivo leva camada e fonte (`models/silver/alfa/silver_alfa_devedores.sql`). Schema e nome da tabela saem da pasta, pelas macros `generate_schema_name` e `generate_alias_name`.
- Nomes de tabela, coluna e arquivo com um único `_` entre as palavras, sem prefixos de camada (`stg_`, `int_` e similares). As CTEs seguem o padrão `tNomeCte` (ver "Estilo do código").
- Na gold, só dois prefixos de tabela: `dim_` para dimensões e `ft_` para fatos.
- A bronze e a silver mantêm os nomes de coluna da origem; só a gold renomeia para o padrão de prefixos. Quando a silver une variantes de um campo, usa um dos nomes que a fonte usa.

### Colunas da gold

- Nomes em português, minúsculos, no formato prefixo de tipo + assunto:

  | Prefixo | Uso | Exemplo |
  |---|---|---|
  | `sk_` | chave substituta | `sk_devedor` |
  | `cod_` | código | `cod_cnae` |
  | `desc_` | descrição | `desc_cnae` |
  | `nome_` | nome | `nome_devedor` |
  | `num_` | número, numérico ou não | `num_cpf`, `num_telefone` |
  | `qt_` · `vl_` · `tx_` | quantidade · valor · taxa | `qt_tentativas`, `vl_renda` |
  | `tp_` · `sit_` · `sigla_` | tipo · situação · sigla | `tp_canal`, `sit_risco`, `sigla_uf` |
  | `flag_` | booleano | `flag_contato_compartilhado` |
  | `dt_` · `hr_` | data · hora | `dt_atualizacao` |

- Ordem das colunas nas dimensões: chave substituta → chave natural → atributos, com cada código seguido da própria descrição (`cod_x`, `desc_x`, `cod_y`, `desc_y`) → nomes → números e valores → flags → datas → rastreabilidade por último.
- Ordem das colunas nos fatos: chave substituta (se houver) → chaves das dimensões → identificadores da origem → medidas → flags → datas → rastreabilidade por último.
- Dimensões montadas a partir de várias fontes trazem uma coluna com os provedores que contribuíram para a linha (ex.: `desc_provedores_origem`).
- Quando um fato não encontra a dimensão correspondente, a chave fica `NULL`. Nenhuma dimensão ganha linha fictícia do tipo "desconhecido", porque os modelos não geram linhas que não existam na origem. A junção do fato com essas dimensões usa `LEFT JOIN`.

### Commits e branches

- `main` recebe só versões que funcionam; o trabalho acontece na `develop`, com um branch por tópico (`<tipo>/<tópico>`) integrado por merge `--no-ff`. Pull requests de terceiros vão para a `develop` e precisam de aprovação do dono do repositório e do CI verde.
- Commits só acontecem com autorização do dono do repositório. Na execução dos tópicos, a autorização está no `PLAN.md` de cada tópico: os agentes fazem os commits planejados ali, incluindo as correções apontadas na revisão do próprio tópico, e nenhum outro.
- Só os tipos listados nas convenções do case. Mensagens em português, claras, dizendo o porquê da mudança.
- Commits `fix:` e `refactor:` que melhoram desempenho ou qualidade trazem no corpo o ganho medido: o antes e o depois e como foi medido. Um número que não foi medido aparece rotulado como estimativa.
- Nenhum arquivo do repositório e nenhuma mensagem de commit leva caminho absoluto da máquina de quem desenvolve; só caminhos relativos ao repositório.
