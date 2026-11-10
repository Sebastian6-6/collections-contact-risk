# Plano mestre — uma sessão por etapa

Substitui o plano de 5 tópicos, escrito sem aprovação em 2026-11-09. As regras do repositório estão no `AGENTS.md`; este plano não as repete.

## 1. O fluxo

Cada etapa do desenho tem uma sessão própria, sempre neste ciclo:

1. **Abrir:** `/c <tópico>`. Carrega a memória do tópico; o `AGENTS.md` entra sozinho.
2. **Decidir:** uma decisão por vez com o autor, com as opções, os trade-offs, uma recomendação, a página do enunciado e as fontes conferidas. Nada é afirmado sem fonte ou medição; o que não foi verificado é dito.
3. **Escrever o `PLAN.md` do tópico** só com as decisões aprovadas, e mostrar ao autor antes de salvar.
4. **Executar no fim da sessão**, com os agentes (seção 3), passo a passo.
5. **Revisar e verificar:** `revisor` e `verificador`; as correções viram commits próprios. Um resultado que contradiga uma decisão volta para o autor como pendência, nunca muda em silêncio.
6. **Fechar:** `/c save`, o capítulo do storytelling (fora do repositório), o merge `--no-ff` na `develop` quando não houver pendência que mude código, e o prompt da próxima sessão.

Uma sessão de desenho pode rodar em paralelo com uma de execução, desde que só edite a memória do próprio tópico e não faça commit (seção 4).

## 2. As etapas

| # | Etapa | O que o enunciado pede (página) | Tópico | Situação em 2026-11-09 |
|---|---|---|---|---|
| 0 | Regras, enunciado anonimizado, política de publicação | AGENTS.md atualizado (p. 1) | `arquitetura-solucao` | feita |
| 1 | Perfil das fontes | base para "dados incompletos ou ruidosos" (p. 3) | `arquitetura-solucao` | feita (`docs/perfil-das-fontes.md`) |
| 2 | Stack: DuckDB, dbt Core, Python | stack aberta, código reprodutível (p. 2) | `arquitetura-solucao` | feita |
| 3 | Estrutura do repositório, CI, agentes | camadas claras (p. 3) | `fundacao-do-repositorio` | feita e integrada |
| 4 | Ingestão até a bronze | carga histórica e diários de setembro (p. 1) | `ingestao-e-padronizacao` | feita; merge depende da 2ª rodada de correções |
| 5 | Silver por fonte | deduplicação, conflitos, dados ruidosos (p. 3) | `ingestao-e-padronizacao` | feita junto com a 4 |
| 6 | Gold e régua: base única (identificação, endereço, contatos, vínculo), régua por telefone e e-mail, salvaguardas e lista de não contatar, segmentação dos elegíveis e estratégia de canais e mensagens por nível | p. 1–2; integridade referencial e eficiência do modelo (p. 3); equilíbrio entre efetividade e proteção a terceiros/LGPD (p. 4) | `modelo-gold-e-regua` | sessão de desenho aberta |
| 7 | Enriquecimento por CNPJ com dados abertos (dados.gov.br) e o valor que ele agrega à cobrança | p. 1–2 | `modelo-gold-e-regua` | a desenhar, sessão própria |
| 8 | Qualidade da ingestão: investigar o dia com problema, estratégia de normalização e monitoramento diário (média móvel), sem complexidade desnecessária | p. 1–2; criatividade e pragmatismo (p. 4) | `monitoramento-e-analises` | a desenhar |
| 9 | Avaliação da régua: acertos, erros e pontos cegos contra o histórico; acurácia, calibração, variáveis de maior peso preditivo, padrões de erro e propostas de ajuste | p. 1–2 | `monitoramento-e-analises` | a desenhar |
| 10 | Entrega: README (visão geral, premissas, raciocínio, conclusões, limites, o que priorizaria), ERD acessível, tipos de cada coluna com o ganho de integridade ou eficiência, AGENTS.md final, repositório público no GitHub | p. 1–3 | `documentacao-e-entrega` | a desenhar |
| — | Revisões finais: revisão a frio do repositório inteiro e checklist privado de publicação | "use apenas o que você consegue explicar" (p. 3) | `documentacao-e-entrega` | no fim |

**Orçamento:** o enunciado espera de 8 a 12 horas (p. 3). Cada sessão corta o que não responde ao enunciado; o que ficar de fora vai para "o que eu priorizaria" no README.

Os `PLAN.md` atuais de gold, monitoramento e entrega são rascunhos não aprovados: servem só como lista de ideias para a sessão da etapa.

## 3. Agentes

Definições em `.claude/agents/`. Modelo e esforço padrão de cada um estão no próprio arquivo; o `PLAN.md` do tópico pode pedir esforço alto num passo.

| Agente | Faz | Não faz |
|---|---|---|
| `engenheiro-python` | ingestão, scripts, testes pytest, CI | modelos SQL |
| `engenheiro-sql` | modelos, macros, testes e YAML do dbt | decisões de negócio |
| `analista-dados` | análises, medições, documentação das decisões | código de produção extenso |
| `revisor` | lê o diff contra o enunciado, o AGENTS.md e o plano | editar |
| `verificador` | roda tudo do zero e devolve aprovado/reprovado | interpretar ou corrigir |

## 4. Regras de orquestração (aprendidas na etapa 4)

- **Pedido autocontido:** caminho do `PLAN.md` e o passo, critérios de pronto, a mensagem do commit e as regras que mais pesam. Relato de no máximo 15 linhas.
- **Escrita em sequência, leitura em paralelo:** dois agentes nunca escrevem na mesma árvore ao mesmo tempo. Quem lê o banco enquanto outro o recria trabalha numa cópia.
- **`git add` só por caminho explícito**, nunca `-A`, `.` ou `.context/` dentro de um passo: outra sessão pode estar editando a memória.
- **Nada sem fonte ou medição.** Número do desenho é refeito na execução; quando não se reproduz, a correção é registrada e o número antigo deixa de ser citado. O console do Windows exibe acentos errado: conclusões sobre caracteres vêm de bytes.
- **Escolha que o plano não fixava** vira pendência para o autor confirmar; não vira regra.
- **Commits:** os planejados no `PLAN.md` e as correções da revisão. Mensagem como se fosse do autor, sem "o dono", sem Co-Authored-By; `fix:`/`refactor:` com o ganho medido. O hook privado bloqueia caminho pessoal, termos privados e arquivos não publicáveis (como `.pdf`).
- **Limite de uso:** um agente interrompido é retomado pelo `SendMessage`, nunca recriado, depois de conferir o que ficou pela metade.

## 5. Pontos de pausa

A execução para e pergunta ao autor quando: um resultado contradiz uma decisão; uma correção exige decidir regra de negócio; uma ação sai da máquina (GitHub, push); ou um teste não fecha depois de duas tentativas.

## 6. Pendências que atravessam etapas

- Regras de horário de contato: confirmar os textos originais da Lei SP 17.832/2023 e da SARB 27/2023 (etapa 6).
- Versões PostgreSQL das macros com `adapter.dispatch`: escritas só pela documentação; testar se houver uma instância (etapa 10 registra como limite).
- CI no GitHub Actions: rodar na primeira publicação (etapa 10).
