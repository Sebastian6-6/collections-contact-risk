# Plano — modelo gold, régua de risco e enriquecimento por CNPJ

## 1. Objetivo e base no enunciado

Unir as três fontes numa base cadastral única e confiável, num star schema. A base cobre:
- identificação;
- endereço;
- contatos;
- vínculo empregatício.

Sobre ela, aplicar a régua de risco a cada telefone e e-mail de cada devedor, montar a lista de não-contatar e
enriquecer o vínculo com os dados abertos do CNPJ.

Base no enunciado:
- **Base cadastral única** e **régua de risco "aplicável a cada telefone e e-mail de cada devedor"**, com níveis e
  critérios a meu critério (p. 1).
- **Enriquecimento com o CNPJ** a partir de dados.gov.br (p. 1).
- **Salvaguardas e lista de não-contatar**, justificando quais sinais acionam o bloqueio (p. 2).
- **Critérios de avaliação:**
  - "integridade referencial e eficiência do modelo relacional";
  - "equilíbrio entre efetividade de cobrança e proteção a terceiros (LGPD/risco reputacional)" (p. 3 e 4).
- **O risco central:** "contatar quem não deve", seja um número errado, o telefone de um parente, um número que mudou
  de dono ou um contato ligado a vários CPFs (p. 1).

## 2. Decisões herdadas

- `AGENTS.md`:
  - "Camadas e nomes";
  - "Colunas da gold": prefixos, ordem, coluna de origem, chave ausente `NULL`;
  - convenções SQL do case.
- `arquitetura-solucao/STATE.md`:
  - os sinais de risco medidos na etapa 1;
  - a pendência do star schema e dos datasets de análise como views;
  - a pendência das regras de horário de contato;
  - nenhuma dimensão de calendário gerada.
- Ingestão e padronização:
  - silver por fonte, com `devedores`, `telefones`, `emails`, `enderecos`, `vinculos` e `rejeitados`;
  - a decisão sobre similaridade de nomes (passo 2.7).

## 3. Decisões abertas (para a aprovação única)

| # | Decisão | Proposta | Por quê |
|---|---|---|---|
| D1 | Desenho da estrela | **Dimensões:** `dim_devedor`, `dim_contato` (um telefone ou e-mail normalizado por linha), `dim_empregador`, `dim_provedor`, `dim_canal` e `dim_desfecho`. **Fatos:** `ft_devedor_contato` (um par devedor × contato, onde vive a régua), `ft_devedor_vinculo` (devedor × empregador, com cargo, salário e início) e `ft_tentativa_contato` (uma tentativa do histórico). O endereço escolhido fica na `dim_devedor`, com o provedor de origem. `dim_provedor`, `dim_canal` e `dim_desfecho` saem de `SELECT DISTINCT` sobre a silver (nunca de seed ou lista fixa), e a classe do desfecho é um atributo calculado com `CASE` | O risco pertence ao **par** devedor × contato (o mesmo número pode estar ligado a vários CPFs), por isso a régua mora num fato de relacionamento. Datas ficam como colunas, porque a convenção proíbe gerar linhas, e portanto um calendário |
| D2 | Quem entra na `dim_devedor` | Só CPF com dígito verificador válido. RG e documentos inválidos ficam fora, contados e explicados nos limites | Juntar contatos de um documento duvidoso a um devedor é exatamente o risco de terceiro que o case quer evitar |
| D3 | Resolução de conflitos entre fontes | **Nome:** o que mais aparece entre os provedores; no empate, o mais recente. Quando a similaridade portável definida no passo 2.7 fica abaixo do limiar, `flag_conflito_identidade`, e os contatos do provedor divergente sobem de nível na régua. **Nascimento:** as sentinelas (1900-01-01, 2031-05-10) viram `NULL`; dia e mês trocados são detectados. **Endereço:** o mais recente. Cada atributo escolhido guarda o provedor de origem | Regra simples, explicável e rastreável. Os 91 CPFs com outra pessoa no mesmo documento viram sinal, em vez de um merge silencioso |
| D4 | Níveis e sinais da régua | Três níveis: `liberado`, `atencao` e `bloqueado`, com `desc_motivos`. Sinais propostos, com a taxa de contato errado medida na etapa 1: contato compartilhado entre CPFs (23,1% contra 1,4%); contato que passou para outro CPF (25,1%); visto em um só provedor (6,6% contra 1,1%); número-lixo (`0000000000`, números ligados a dezenas de CPFs); formato inválido; conflito de identidade (D3); opt-out e falecido no histórico. O analista define o peso de cada sinal e o nível resultante | Os critérios vêm de evidência medida, não de suposição. A calibração fina acontece no tópico 4 |
| D5 | Vazamento de informação na validação | Os sinais cadastrais vêm só das fontes cadastrais. Opt-out e falecido são pedidos explícitos e bloqueiam pela política, não pelo modelo. A validação no tópico 4 usa **um corte único**: sinais calculados só com registros recebidos até a data D, tentativas depois de D. A lógica da régua fica numa macro só, `regua_de_risco(data_corte)`: a `ft_devedor_contato` a chama sem corte e o tópico 4 a chama com o corte D, sem reimplementar os sinais | Sem corte, a régua seria avaliada com a mesma informação que a construiu, e a acurácia pareceria melhor do que é |
| D6 | Chave substituta | `INTEGER` por `ROW_NUMBER()` sobre a chave natural ordenada (com `ROWS BETWEEN`, como pede o case) | Compacta e determinística, porque o banco é recriado do zero a cada execução. Trade-off documentado: uma carga incremental precisaria de chave por hash |
| D7 | Lista de não-contatar e onde ficam os datasets | Os datasets derivados ficam num schema próprio, `analises`, a partir da pasta `models/analises/`, como views. O primeiro é `analises.lista_nao_contatar`: um par devedor × contato bloqueado e o motivo de cada bloqueio. O AGENTS.md ganha a regra no mesmo commit | A gold continua só com `dim_` e `ft_`, como diz o AGENTS.md, e os datasets largos que alimentam a operação e as análises ficam separados e sem duplicar dados |
| D8 | Como chega o CNPJ | Script `scripts/extrair_receita_cnpj.py`, fora da execução diária e fora de `ingestion/` (ele filtra, e a ingestão não transforma). Ele baixa a edição mensal fixada dos dados abertos da Receita, confere o hash, filtra só os CNPJs que aparecem nos dados e grava um extrato pequeno e versionado em `dados_externos/receita_cnpj/<AAAA-MM>/`. O `ORIGEM.md` guarda a URL, a edição, os hashes dos arquivos, a lista de CNPJs usada no filtro e o hash dessa lista. A pipeline lê o extrato como mais uma fonte de `fontes.yml` | A pipeline continua offline e reproduzível, e o extrato pode ser regenerado. É também a prova de que uma fonte nova entra por configuração |

## 4. Sequência de execução

### 3.1 Desenho da gold, da régua e das salvaguardas
- **Quem:** `analista-dados` (Opus 5.5 · high).
- **Ler:**
  - o enunciado (p. 1 a 4);
  - `docs/perfil-das-fontes.md`;
  - `docs/decisoes-de-modelagem.md`;
  - o `AGENTS.md`;
  - os dados da silver, consultados direto no banco.
- **Fazer:**
  1. Fechar D1 a D7 com os números da silver.
  2. Definir a régua: cada sinal, o nível resultante e o motivo em texto para a operação.
  3. **Salvaguardas de horário:** confirmar nos textos originais as regras de horário e dia de contato (a lei
     estadual de SP e a autorregulação bancária citadas no desenho) antes de citá-las. Se não for possível confirmar,
     registrar como premissa.
  4. Esboço do ERD em Mermaid.
  5. Em `docs/decisoes-de-modelagem.md`, a seção da gold, com:
     - como o projeto lê "cada linha corresponde a um registro recebido" diante de linhas agregadas: toda linha da
       gold e dos datasets deriva de pelo menos um registro recebido, e nenhuma é inventada (sem calendário, sem
       membro "desconhecido", sem lista fixa);
     - a chave ausente que fica `NULL`, a junção com `LEFT JOIN` e o teste de relacionamento que ignora `NULL`;
     - o corte temporal e a macro única da régua (D5).
- **Pronto quando:** cada nível tem critério explícito, cada critério tem a evidência que o sustenta e o rascunho do
  ERD mostra a granularidade de cada tabela.
- **Commit:** `docs: desenho do modelo gold, da régua de risco e das salvaguardas` — as regras que decidem quem pode
  ser contatado ficam escritas antes do código, para serem discutidas pelo que dizem.

### 3.2 Cadastro único de devedores
- **Quem:** `engenheiro-sql` (Sonnet 5.5 · **high**).
- **Fazer:** `dim_devedor` a partir das silvers, com:
  - a resolução de conflitos D3;
  - a coluna de origem;
  - a ordem de colunas do AGENTS.md;
  - o endereço escolhido.

  Testes: chave natural única, `sk_devedor` única e `not_null`, valores aceitos, e um teste unitário para cada regra
  de conflito.
- **Pronto quando:**
  - toda linha vem de pelo menos uma silver;
  - a contagem de devedores únicos e de conflitos resolvidos está registrada;
  - as convenções estão limpas.
- **Commit:** `feat: cadastro único de devedores com resolução de conflitos`, com o corpo dizendo quantos registros
  viraram quantos devedores e quantos conflitos foram resolvidos ou sinalizados.

### 3.3 Contatos, vínculo devedor-contato e régua
- **Quem:** `engenheiro-sql` (Sonnet 5.5 · **high**), com as regras do 3.1.
- **Fazer:**
  1. A macro `regua_de_risco(data_corte)` (D5), com teste.
  2. `dim_contato`, `dim_provedor` e `ft_devedor_contato` com os sinais de D4 como `flag_` e `qt_`, o `sit_risco` e o
     `desc_motivos`.
  3. Teste de relacionamento em todas as chaves estrangeiras. Elas aceitam `NULL`, como manda o AGENTS.md.
- **Pronto quando:**
  - a distribuição de pares por nível está registrada;
  - todo par bloqueado tem motivo;
  - as convenções estão limpas.
- **Commit:** `feat: contatos, vínculo devedor-contato e régua de risco` — o risco passa a ser medido no par devedor ×
  contato, que é onde o erro acontece: o mesmo número pode ser seguro para um CPF e expor a dívida de outro.

### 3.4 Tentativas de contato no modelo
- **Quem:** `engenheiro-sql` (Sonnet 5.5 · medium).
- **Fazer:**
  1. `dim_canal`, `dim_desfecho` e `ft_tentativa_contato`. O desfecho é classificado como, por exemplo, contato
     certo, terceiro, sem resposta ou pedido de exclusão.
  2. Uma tentativa cujo CPF ou destino não está no cadastro fica com a chave `NULL` e é contada.
- **Pronto quando:** toda tentativa da silver está no fato, e a contagem de chaves `NULL` por motivo está registrada.
- **Commit:** `feat: tentativas de contato ligadas ao cadastro e à régua` — sem ligar cada tentativa ao par devedor ×
  contato, não haveria como confrontar a régua com o que aconteceu de fato.

### 3.5 Lista de não-contatar
- **Quem:** `engenheiro-sql` (Sonnet 5.5 · medium).
- **Fazer:** `analises.lista_nao_contatar` (D7), com teste de que todo item tem motivo e de que nenhum par `liberado`
  entra. A regra do schema `analises` entra no AGENTS.md ("Camadas e nomes").
- **Commit:** `feat: lista de não-contatar com o motivo de cada bloqueio` — a operação recebe uma lista pronta para
  aplicar, e cada bloqueio pode ser explicado ao devedor ou a um auditor.

### 3.6 Extrato reproduzível do CNPJ
- **Quem:** `engenheiro-python` (Sonnet 5.5 · medium).
- **Ler:** a página oficial dos dados abertos do CNPJ (dados.gov.br e o repositório de arquivos da Receita). Antes,
  confirmar qual é a edição mais recente, o leiaute atual e como o CNPJ alfanumérico aparece. As seções usadas vão para
  `.context/raw/referencias/receita/`.
- **Fazer:**
  1. O script de D8: baixa os arquivos por streaming e confere o hash de cada arquivo baixado. Filtra pela raiz do
     CNPJ, a partir da lista tirada da silver. Grava o extrato e o `ORIGEM.md` com URL, edição, hashes e data.
  2. Testes com um zip mínimo de exemplo.
  3. A entrada `receita` no `fontes.yml`.
  4. As pastas `dados_externos/` e `scripts/` descritas no AGENTS.md.
- **Pronto quando:**
  - o extrato está versionado, pequeno e com origem documentada;
  - a pipeline roda sem rede;
  - a taxa de CNPJs encontrados está registrada. Os dados do case são sintéticos, então uma taxa baixa é um resultado
    válido e vai para os limites.
- **Commit:** `feat: extrato reproduzível do CNPJ da Receita Federal` — a pipeline continua rodando sem rede e com o
  mesmo resultado, e qualquer pessoa consegue regenerar o extrato e conferir o hash.

### 3.7 Vínculo empregatício enriquecido
- **Quem:** `engenheiro-sql` (Sonnet 5.5 · medium).
- **Fazer:**
  1. Bronze e silver da fonte `receita`, reaproveitando o mesmo componente das outras fontes.
  2. `dim_empregador`: CNPJ validado, razão social, situação cadastral e data da situação, CNAE com descrição, porte e
     UF.
  3. `ft_devedor_vinculo`.
- **Commit:** `feat: vínculo empregatício enriquecido com o CNPJ` — o vínculo deixa de ser só um número: passa a dizer
  se a empresa está ativa, em que setor atua e qual o porte, o que muda a estratégia de cobrança.

### 3.8 Otimização medida, revisão e fechamento
- **Quem:**
  - `engenheiro-sql`: `explicar_modelo.py` na `dim_devedor`, na `ft_devedor_contato` e na `ft_tentativa_contato`;
  - `revisor` (Opus 5.5 · medium);
  - `verificador` (Haiku 5.5 · low).
- **Fazer:**
  1. Um `refactor:` só para o que mudar o plano real, com o antes e o depois.
  2. Correções da revisão como commits próprios (plano mestre, seção 5).
  3. Merge `--no-ff` com `chore: integra modelo-gold-e-regua na develop`.
  4. `/c save` e capítulo 3 do storytelling.

## 5. Ganhos a medir

| O quê | Como | Onde entra |
|---|---|---|
| Registros recebidos → devedores únicos | contagem silver × `dim_devedor` | commit 3.2 |
| Conflitos de identidade sinalizados | `flag_conflito_identidade` | commit 3.2 e README |
| Pares por nível da régua e motivos mais frequentes | `ft_devedor_contato` | commit 3.3 e storytelling |
| Tentativas sem devedor ou contato conhecido | chaves `NULL` em `ft_tentativa_contato` | commit 3.4 e limites |
| CNPJs encontrados na Receita | extrato × silver | commit 3.6 e README |
| Tempo e plano dos modelos da gold | `explicar_modelo.py`, antes e depois | cada `refactor:` |

## 6. Riscos e plano B

| Risco | Plano B |
|---|---|
| Os arquivos da Receita são grandes (gigabytes) | streaming e filtro durante o download; o extrato fica pequeno |
| Os CNPJs sintéticos não existem na Receita | registrar a taxa, mostrar o valor com os que existirem e explicar nos limites |
| A régua bloqueia demais e a cobrança perde alcance | o equilíbrio é avaliado no tópico 4, e o ajuste vira um `fix:` com o ganho medido |
| Os textos legais de horário não podem ser confirmados | tratar como premissa explícita no README |

## 7. Pronto do tópico e capítulo do storytelling

**Pronto:**
- estrela completa, com testes de relacionamento;
- régua com motivo em todo bloqueio;
- lista de não-contatar;
- CNPJ enriquecido;
- `verificador` verde;
- merge na `develop`.

**Capítulo "Uma base única e uma régua que explica":**
- por que o risco mora no par devedor × contato;
- como os conflitos viraram sinais;
- o que a Receita acrescentou.
