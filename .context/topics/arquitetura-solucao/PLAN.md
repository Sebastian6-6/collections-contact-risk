# Plano mestre de execução

Este arquivo amarra a execução do projeto. O desenho foi feito neste tópico (`arquitetura-solucao`); a construção acontece em cinco tópicos, cada um com o próprio `PLAN.md` detalhado. Aqui ficam o que vale para todos: a ordem, os agentes, como eles são orquestrados, a política de commits e a tabela que garante que nenhuma decisão do desenho se perdeu.

As regras do repositório estão no `AGENTS.md`, que todo agente carrega automaticamente. Este plano não repete essas regras: aponta para elas.

## 1. Ordem dos tópicos

| # | Tópico | Etapas do desenho | Entrega | Branch |
|---|---|---|---|---|
| 1 | [`fundacao-do-repositorio`](../fundacao-do-repositorio/PLAN.md) | 3, CI, testes das skills | git, dependências, esqueleto dbt, ferramentas de qualidade, skills testadas, agentes, CI | `chore/fundacao-do-repositorio` |
| 2 | [`ingestao-e-padronizacao`](../ingestao-e-padronizacao/PLAN.md) | 4 e 5 | ingestão por configuração com manifesto, bronze fiel à origem, silver por fonte | `feat/ingestao-e-padronizacao` |
| 3 | [`modelo-gold-e-regua`](../modelo-gold-e-regua/PLAN.md) | 6 e 7 | star schema, cadastro único, régua de risco, lista de não-contatar, enriquecimento por CNPJ | `feat/modelo-gold-e-regua` |
| 4 | [`monitoramento-e-analises`](../monitoramento-e-analises/PLAN.md) | 8 e 9 | monitoramento diário por média móvel, validação e calibração da régua, valor do CNPJ | `feat/monitoramento-e-analises` |
| 5 | [`documentacao-e-entrega`](../documentacao-e-entrega/PLAN.md) | 10 | ERD, dicionário com tipos justificados, README, AGENTS.md final, publicação | `docs/documentacao-e-entrega` |

Cada tópico depende do anterior e roda sozinho, do primeiro passo ao merge. O tópico seguinte só começa depois do merge do anterior na `develop`.

**Orçamento.** O enunciado espera de 8 a 12 horas de trabalho (p. 3). O caminho crítico é o que responde ao enunciado; três passos ficam fora dele e podem ser encurtados se o tempo apertar: a segunda rodada dos testes das skills (1.6), a avaliação de bibliotecas (2.7, já limitada a nome e telefone) e as regras de branch no GitHub (5.6).

## 2. Pontos de pausa

O dono do projeto aprova o pacote de planos uma vez, depois da revisão (seção 7). A execução só para em quatro situações:

1. **Visualizador dos testes das skills** (tópico 1): o retorno dele orienta os ajustes nas skills.
2. **Ações externas**: criar o repositório no GitHub, push, regras de branch. Nada sai da máquina sem confirmação.
3. **Bloqueio**: um resultado que contradiz o enunciado, um teste que não fecha depois de duas tentativas de correção, ou uma decisão de negócio que os dados não sustentam.
4. **Instalação na máquina**: o Python 3.14 e o `uv` não estão instalados. O passo 1.2 da fundação pede confirmação antes de instalar.

## 3. Agentes

As definições ficam em `.claude/agents/`, versionadas: quem abre o repositório vê quais agentes existem, com que modelo e com que skills.

A escolha de modelo segue o guia oficial da Anthropic (platform.claude.com/docs/en/models/overview, consultado em 2026-11-09):
- **Opus 5.5:** o ponto de partida para trabalho complexo; rende como o Fable 5.1 na maioria das tarefas, por menos.
- **Sonnet 5.5:** a melhor combinação de velocidade e inteligência, bom para código de escopo claro.
- **Haiku 5.5:** tarefas de alto volume e subagentes simples.

O mesmo guia recomenda **ajustar o esforço antes de trocar de modelo**. O Fable 5.1 fica reservado para o caso de o Opus falhar numa tarefa mesmo com esforço alto, o que não é esperado num projeto deste tamanho.

| Agente | Modelo · esforço padrão | Skills | Faz | Não faz |
|---|---|---|---|---|
| `engenheiro-python` | Sonnet 5.5 · medium | `qualidade-python`, `convencoes-codigo-pessoal` | ingestão, scripts, testes pytest, CI | modelos SQL |
| `engenheiro-sql` | Sonnet 5.5 · medium; high na silver beta e no cadastro único | `qualidade-sql`, as 4 da dbt Labs | modelos, macros, testes e documentação YAML do dbt | decisões de negócio da régua |
| `analista-dados` | Opus 5.5 · high | `qualidade-sql` | desenho da gold e da régua, análises, calibração, interpretação | código de produção extenso |
| `revisor` | Opus 5.5 · medium; high na revisão final | `qualidade-sql`, `qualidade-python` | lê o diff do tópico contra o enunciado e o AGENTS.md e devolve achados | editar arquivos |
| `verificador` | Haiku 5.5 · low | — | roda a pipeline do zero e todas as checagens e devolve um resumo curto | interpretar ou corrigir |

## 4. Como os agentes são orquestrados

O orquestrador é a sessão principal (Opus 5.5). Ele escreve o pedido de cada agente, confere o resultado, faz os merges, mantém os `STATE.md` e o documento de storytelling.

- **Pedido autocontido e curto.** Cada pedido traz:
  - o caminho relativo do `PLAN.md` do tópico e o número do passo;
  - os critérios de pronto;
  - as mensagens dos commits planejados;
  - a lembrança das duas regras que mais pesam: o AGENTS.md vale acima de tudo, e nenhum caminho absoluto entra em arquivo nem em commit.

  O pedido não cola contexto grande: o agente lê o que precisa.
- **Relato curto.** O agente devolve no máximo 15 linhas: o que mudou, os comandos rodados e o resultado, os hashes dos commits e as pendências. Log longo fica com o `verificador`, que devolve só o essencial.
- **Escrita em sequência, leitura em paralelo.** Dois agentes nunca escrevem ao mesmo tempo na mesma árvore. Assim não há worktrees nem merges extras, e o histórico fica limpo. Rodam em paralelo só as tarefas que não escrevem no repositório: testes das skills, revisões e pesquisas.
- **Correção no mesmo agente.** Ajuste depois da revisão vai por `SendMessage` ao agente que fez o trabalho, que ainda tem o contexto. Abrir um agente novo custa a releitura de tudo.
- **Plano B.** Se os agentes de `.claude/agents/` só forem reconhecidos depois de reiniciar a sessão, o orquestrador usa o tipo `general-purpose` com o mesmo modelo, o mesmo esforço e a instrução de carregar as mesmas skills.

## 5. Commits, branches e caminhos

As regras estão no `AGENTS.md`, nas seções "Commits e branches" e "Commits" do case. Na prática:

```
main ──●──●───────────────────────────────────────────────●  (merge final feito pelo dono)
        \                                                 /
develop  ●────●(1)────●(2)────●(3)────●(4)────●(5)───────●
               \      /\      /
                tópico  tópico ...   (cada tópico: branch próprio, merge --no-ff)
```

- `main` recebe só os três commits de ponto de partida e, no fim, a versão aprovada. O merge de `develop` para `main` é do dono do repositório.
- Cada tópico tem um branch, e o merge na `develop` usa `--no-ff` com a mensagem `chore: integra <tópico> na develop`, com o nome do tópico literal (ex.: `chore: integra fundacao-do-repositorio na develop`). O histórico fica lido em capítulos.
- **Correções da revisão.** O que o `revisor` apontar e for corrigido antes do merge entra como um commit próprio, também autorizado pelo plano: `fix:` quando corrige comportamento (com o ganho medido, se houver), `refactor:` quando só melhora o código e `docs:` quando é texto. A mensagem diz qual achado foi corrigido e por quê.
- **AGENTS.md acompanha a execução.** Quando um passo cria uma regra nova (o schema `landing`, o `fontes.yml`, o schema `analises`, uma pasta nova), o mesmo commit atualiza o AGENTS.md, como pede o enunciado (p. 1). O passo 5.4 só consolida.
- **Formato das mensagens** (pt-BR, claro, dizendo o porquê):

  ```
  <tipo>: <o que muda, em poucas palavras>

  <por que a mudança existe, em 1 a 3 frases>
  Ganho medido: <métrica> de <antes> para <depois> (<como foi medido>)
  ```

  A linha "Ganho medido" é obrigatória em `fix:` e `refactor:` que melhoram desempenho ou qualidade. Um número que não foi medido aparece como "Ganho estimado" e diz em que se baseia.
- **Autor:** a identidade global de git da máquina. Sem linha de coautoria.
- **Caminhos e termos privados.** Um hook de git privado, guardado fora do repositório e ligado só neste clone, roda em todo commit, de pessoa ou de agente. Ele bloqueia caminho absoluto da máquina, termos de uma lista privada e arquivos que não podem ser publicados (`.pdf`, `.pyc`, `.duckdb`, `.context/local/`).
- **Volume:** cerca de 32 commits planejados, mais um merge por tópico e os `fix:`/`refactor:` que a medição justificar. Um commit por mudança lógica, como pede o case: nem um commit por arquivo, nem um commit por tópico.

## 6. Documento de storytelling

Um documento em pt-BR simples, na primeira pessoa, guardado **fora do repositório**. Ele resume o processo de construção para a apresentação do case. O esqueleto nasce na revisão (seção 7), e o orquestrador escreve o capítulo de cada tópico logo depois do merge, enquanto o contexto está fresco. Estrutura:

1. **Resumo inicial**, respondendo ao que o enunciado pede:
   - visão geral, premissas, raciocínio das transformações, conclusões e limites (p. 2);
   - o que eu priorizaria com mais tempo e onde gastaria mais tempo;
   - as respostas da parte "Análise de Dados" (p. 1 e 2);
   - como a entrega atende aos cinco critérios de avaliação (p. 3 e 4).
2. **Como trabalhei com IA:** a memória de contexto, as skills e seus testes, os agentes com modelo e esforço, e o custo.
3. **Um capítulo por tópico:** o que foi feito, as decisões e os trade-offs, os ganhos medidos, os commits.
4. **O que faltou e o que eu faria.**

## 7. Revisão dos planos (último passo do desenho)

1. **Tabela de rastreio completa** (seção 8): toda decisão tem destino.
2. **Revisão a frio:** um `revisor` (Opus 5.5 · medium), sem o contexto da conversa, lê o enunciado, o AGENTS.md, este plano e os cinco `PLAN.md`. Ele procura:
   - pedido do enunciado sem passo ou sem commit;
   - nome pouco claro de tópico, passo, tabela ou coluna;
   - desvio dos padrões do projeto (pt-BR, voz no singular ou impessoal, Conventional Commits, ganho medido);
   - caminho absoluto.
3. **Correções:** o orquestrador aplica o que a revisão apontou.
4. **Aprovação única** do pacote, com as decisões abertas de cada tópico já com proposta.
5. **Encerramento:** fechar no `STATE.md` as pendências já resolvidas (nomes da etapa 3, testes das skills) e rodar `ctx.py complete arquitetura-solucao`, com o resumo final.

## 8. Rastreio das decisões do desenho

| Decisão (STATE.md deste tópico) | Onde vale | Onde é executada |
|---|---|---|
| Hierarquia de regras, modo de trabalho, pesquisa antes de afirmar | AGENTS.md | todos |
| Documentação de referência na versão atual | AGENTS.md | 1 (referências novas), 3 (layout do CNPJ) |
| `requirements.in` + `requirements.txt` gerado com `uv pip compile --universal` | AGENTS.md | 1 · passo 1.3 |
| DuckDB 2.0 embutido, banco recriado do zero; SQL no subconjunto PostgreSQL | AGENTS.md | 1 · passo 1.4; 2, 3, 4 |
| dbt Core 1.12 + dbt-duckdb 1.11; manter portável para o v2 | AGENTS.md | 1 · passo 1.4 (`dbt parse --use-v2-parser` no CI) |
| Python 3.14; ingestão em Python (stdlib + duckdb); um comando de entrada | AGENTS.md (Stack) | 1 · passos 1.2 e 1.4; 2 · passo 2.1 |
| SQLFluff com dialeto postgres | skill qualidade-sql | 1 · passo 1.3 |
| Sem horário de execução nas tabelas; rastreabilidade por arquivo e hash | AGENTS.md | 2 · passo 2.1; texto em 5 (README e decisões) |
| Sem tabela de log de execução; Dagster só como extra | — | 5 · "o que eu faria" |
| Um banco, um schema por camada (e por fonte) | AGENTS.md | 1 · passo 1.4 |
| Sem painel nem gráficos; conclusões no README | — | 4 e 5 |
| Nomes com um `_`, `dim_` e `ft_` na gold, arquivo com camada e fonte | AGENTS.md | 1 · passo 1.4; 2, 3 |
| Silver só por fonte; união e conflitos na gold | AGENTS.md | 2 e 3 |
| Python segue `convencoes-codigo-pessoal` | AGENTS.md | todos os passos Python |
| CI no GitHub Actions; main + develop; PR de terceiros aprovado pelo dono | AGENTS.md | 1 · passo 1.7; 2 · passo 2.8; 5 · passo 5.6 |
| Skills combinadas instaladas e testadas no começo do desenvolvimento | — | 1 · passos 1.5 e 1.6 |
| Regra de entrada de bibliotecas (offline, determinística, muda decisão, ganho medido) | STATE deste tópico (só tratamento) | 2 · passo 2.7 |
| Prefixos e ordem das colunas da gold; coluna de origem nas dimensões unidas | AGENTS.md | 3 |
| Chave ausente fica `NULL`, sem linha "desconhecido" | AGENTS.md | 3; texto em `docs/decisoes-de-modelagem.md` |
| Commits sem coautoria; nenhum caminho pessoal | AGENTS.md + hook privado | todos |
| Perfil das fontes publicado em `docs/perfil-das-fontes.md` | — | 4 regenera os números com SQL; 5 revisa |
| README com selo do LinkedIn, origem neutra, voz no singular | — | 5 · passo 5.3 |
| Aviso de caminho longo no Windows ao instalar o dbt | — | 1 · passo 1.2; README em 5 |
| Plano B: DuckDB 1.5 LTS se o dbt-duckdb quebrar no 2.0 | STATE deste tópico | 1 · riscos do passo 1.3 |
| Coorte de ~370 linhas por fonte com data padrão 2025-09-01 | — | 2 · D5 (data sentinela); 4 · passo 4.2 |
| Beta de 29/09 repete 353 linhas do dia 28 sem `_reenvio` no nome | — | 2 · D6 (hash por registro); 4 · passo 4.1 |

| Pendência aberta no desenho | Tópico que decide |
|---|---|
| Regras de horário de contato (lei de SP e autorregulação dos bancos): confirmar os textos originais | 3 · passo 3.1 |
| Onde bibliotecas Python rodariam (UDF, modelo Python, etapa antes da silver ou nada) | 2 · passo 2.7 |
| Star schema: fatos, dimensões, sem dimensão de calendário gerada | 3 · passo 3.1 |
| Regra de janela: média móvel com `SUM/SUM(1)`, detecção de buracos sem `LAG` | 4 · passo 4.1 |
| Nomes da etapa 3 (schemas por camada e fonte, macros, `ft_devedor_contato`) | já no AGENTS.md; fecha na aprovação única; 1 · passo 1.4 |
| Gold híbrida: estrela + datasets de análise como views (schema `analises`) | 3 · passos 3.1 e 3.5 |
| Script de perfil: consultar a própria silver | 4 · passo 4.5 |
