<!-- page 1 -->
## Case Técnico de Dados

## Contato Seguro em Cobrança

## Problema

Você recebe dados cadastrais dos devedores todos os dias, de três provedores diferentes, cada um no seu próprio formato. O time de Cobranças precisa de uma base cadastral única e confiável para fazer o contato com o devedor.

O risco não é apenas não encontrar o devedor, mas também contatar quem não deve. Um número errado, o telefone de um parente, um número que mudou de dono ou um contato ligado a vários CPFs expõem a dívida a um terceiro, geram reclamação e risco jurídico, além de gerar um custo à operação.

## O que você deve fazer

## Tratamento de Dados

Você deve estruturar uma pipeline de dados e as análises para suportar a tomada de decisão da operação:

- Ingerir os dados dos três provedores: a carga histórica até 31/08/2026 e os dados diários incrementais de setembro/2026;
- Construir uma base cadastral única de devedores: consolidar identificação, endereço, contatos e vínculo empregatício em uma camada confiável para uso operacional em cobrança;
- Criar uma régua de risco de contato: definir níveis de risco (por exemplo: liberado, atenção, bloqueado — a granularidade e os critérios ficam a seu critério), aplicável a cada telefone e e-mail de cada devedor;
- Validar a régua com o histórico de acionamentos: confrontar com os contatos já realizados para evidenciar acertos, erros e pontos cegos da sua classificação;
- Enriquecer vínculos empregatícios: cruzar as informações de empregador com os dados abertos do CNPJ da Receita Federal (utilize dados públicos disponíveis em dados.gov.br);
- Desenhar o ERD das tabelas: representar o diagrama entidade-relacionamento das camadas de dados desenhadas;
- Documentar e justificar decisões técnicas: explicar as escolhas de modelagem, tipos de dados adotados e eventuais trade-offs;
- Manter o AGENTS.md atualizado: registrar as convenções, regras de arquitetura e padrões operacionais adotados no repositório.

## Análise de Dados

- Detecção de anomalias e qualidade na ingestão: Investigar se houve problema de ingestão em algum dia específico e desenvolver uma estratégia de normalização. Se aplicável, desenvolva a arquitetura de um monitoramento automatizado diário capaz

<!-- page 2 -->
de alertar possíveis problemas na ingestão. Uma das formas para fazer isso é usar uma média móvel.

- Enriquecimento cadastral e valor de negócio: Demonstrar o que a base de CNPJ agrega à esteira de cobrança;
- Política de salvaguardas e lista de não-contatar: Defini, se aplicável, as regras de exclusão de contatos, justificando quais sinais acionam o bloqueio;
- Desenho e avaliação analítica da régua de cobrança: Estruturar a segmentação dos devedores elegíveis e a estratégia de canais/mensagens por nível de acionamento. Em seguida, avalie a acurácia e a calibração da régua com base no histórico de contatos, identificando as variáveis com maior peso preditivo, os principais padrões de erro e propostas de ajuste.

## Requisitos

## Desenvolvimento

- Código reprodutível: a execução da pipeline a partir do estado inicial deve produzir exatamente os mesmos resultados a cada rodada;
- Stack aberta: sinta-se livre para adotar as ferramentas e frameworks com os quais você produz com mais eficiência e robustez (ex.: SQL, dbt/Dataform, Python, Pandas/Polars, DuckDB, Spark, etc.).

## Desenvolvimento

- README principal: deve conter a visão geral do projeto, premissas adotadas, raciocínio das transformações, conclusões das análises, limites das respostas e o que você priorizaria construir com mais tempo.
- Diagrama de Entidade-Relacionamento (ERD): documentação visual clara do modelo de dados gerado, em formato acessível (imagem, Mermaid ou link para dbdiagram).
- Justificativas técnicas: detalhar os tipos de dados atribuídos a cada coluna e os ganhos de integridade ou eficiência obtidos.

## Dados

Os dados fornecidos são sintéticos e cada provedor fornece o que tem disponível.

| Arquivo           | Formato   | Conteúdo                                        |
|-------------------|-----------|-------------------------------------------------|
| provedor_alfa.csv | CSV       | Carga histórica até 31/08/2026 (~10.000 linhas) |

<!-- page 3 -->

| provedor_beta.jsonl           | JSON Lines        | Carga histórica até 31/08/2026 (~10.000 linhas)                                                                    |
|-------------------------------|-------------------|--------------------------------------------------------------------------------------------------------------------|
| provedor_gama.csv             | CSV               | Carga histórica até 31/08/2026 (~10.000 linhas)                                                                    |
| entregas_diarias/<provedor>/ | CSV ou JSON Lines | Entregas incrementais de setembro/2026, um arquivo por provedor e por dia (com a data expressa no nome do arquivo) |
| contatos_realizados.csv      | CSV               | Tentativas de contato efetuadas durante setembro/2026 e seus respectivos desfechos operacionais                    |
| AGENTS.md                     | Markdown          | Convenções, diretrizes de arquitetura e instruções do repositório                                                  |

## Prazo e entrega

- Prazo: 7 dias corridos a partir do recebimento. Esperamos entre 8 e 12 horas de trabalho.
- Entrega: um repositório público no GitHub.
- Uso de IA: você pode usar ferramentas de IA, inclusive para gerar código. A solução será apresentada em uma conversa, explicando as decisões tomadas e a arquitetura utilizada. Use apenas o que você consegue explicar.

## Como será avaliado

- Modelagem e engenharia de dados: clareza da arquitetura das camadas (bronze, staging/silver, marts/gold), integridade referencial e eficiência do modelo relacional.
- Qualidade e confiabilidade: consistência no tratamento de deduplicações, conflitos cadastrais e dados incompletos ou ruidosos.

<!-- page 4 -->
- Régua de risco de contato: consistência analítica dos critérios, equilíbrio entre efetividade de cobrança e proteção a terceiros (LGPD/risco reputacional).
- Documentação e raciocínio crítico: clareza das respostas, profundidade das justificativas técnicas e transparência quanto aos limites das inferências realizadas.
- Criatividade e pragmatismo: soluções elegantes para monitoramento volumétrico e tratamento de anomalias sem complexidade desnecessária.
