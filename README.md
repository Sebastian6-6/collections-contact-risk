<a name="readme-top"></a>

<div align="center">

# 📞 collections-contact-risk

### Base cadastral única de devedores e régua de risco para não contatar quem não deve

Criado por **Pedro Alexandre Piassi Silva** · [![LinkedIn: Pedro Piassi](https://img.shields.io/badge/LinkedIn-Pedro_Piassi-0A66C2?logo=linkedin&logoColor=white)](https://www.linkedin.com/in/pedro-piassi6/)

![DuckDB](https://img.shields.io/badge/DuckDB-embutido-FFF000?logo=duckdb&logoColor=black)
![dbt Core](https://img.shields.io/badge/dbt_Core-dbt--duckdb-FF694B?logo=dbt&logoColor=white)
![Python 3.14](https://img.shields.io/badge/python-3.14-3776AB?logo=python&logoColor=white)
[![CI](https://github.com/Sebastian6-6/collections-contact-risk/actions/workflows/ci.yml/badge.svg)](https://github.com/Sebastian6-6/collections-contact-risk/actions/workflows/ci.yml)

[Visão geral](#-visão-geral) · [Como rodar](#-como-rodar) · [Estrutura](#-estrutura) · [Premissas](#-premissas) · [Transformações](#-raciocínio-das-transformações) · [Conclusões](#-conclusões-das-análises) · [Limites](#-limites-das-respostas) · [Com mais tempo](#-com-mais-tempo)

</div>

---

## 🧭 Visão geral

Solução de um case técnico de dados de cobrança (enunciado anonimizado). Três provedores mandam todo dia o cadastro dos devedores, cada um no seu formato, e o histórico de setembro/2026 traz as tentativas de contato. O risco central é "contatar quem não deve" (p. 1): expor a dívida a um terceiro.

A pipeline lê tudo, consolida uma base única por CPF, cruza o empregador com os dados abertos do CNPJ da Receita Federal e classifica cada par devedor × contato em `liberado`, `atencao` ou `bloqueado`. Os modelos não inventam linhas: cada uma corresponde a um registro recebido.

| 3.434 | 73,45% | 0,6871 |
|---|---|---|
| pares devedor × contato bloqueados: a lista de não-contatar | dos terceiros pegos no corte de 15/09 (202 de 275 tentativas) | de acurácia balanceada no corte de 15/09: a média de 50,22% dos riscos pegos e 87,21% dos confirmados liberados (0,7208 no controle de 22/09) |

**Arquitetura:** `contact_data/` e a Receita (`external_data/receita/`) → bronze, como veio → silver por fonte (`alfa`, `beta`, `gama`, `cobranca`, `receita`) → gold: `dim_devedor`, `dim_contato`, `dim_endereco`, `dim_empregador`, `ft_vinculo_empresa`, `ft_tentativa_contato` e `ft_entrega_diaria`. O ERD está em [docs/erd.md](docs/erd.md).

| Documento | O que tem |
|---|---|
| [docs/analises.md](docs/analises.md) | respostas da "Análise de Dados", com as consultas e a quantidade de casos |
| [docs/decisoes-de-modelagem.md](docs/decisoes-de-modelagem.md) | cada decisão, com as opções, os trade-offs e a página do enunciado |
| [docs/perfil-das-fontes.md](docs/perfil-das-fontes.md) | o que os arquivos recebidos contêm e os problemas de qualidade e de entrega |
| [docs/ingestao.md](docs/ingestao.md) | o componente de ingestão multi-fonte |
| [docs/monitoramento.md](docs/monitoramento.md) | os incidentes das entregas diárias, o alerta e o e-mail de falha |
| [docs/contratos-de-dados.md](docs/contratos-de-dados.md) | o que cada provedor entrega e o que a gold recebe da silver |
| [docs/erd.md](docs/erd.md) · [docs/dicionario-de-dados.md](docs/dicionario-de-dados.md) | o ERD em Mermaid e o dicionário com a justificativa de cada tipo |
| [docs/qualidade-e-convencoes.md](docs/qualidade-e-convencoes.md) | cada regra do repositório e a checagem que a garante |
| [AGENTS.md](AGENTS.md) | as regras do repositório: as convenções do case e as do projeto |

| Critério de avaliação (p. 3–4) | Onde está a resposta |
|---|---|
| Arquitetura das camadas | [Raciocínio das transformações](#-raciocínio-das-transformações); decisões, [seção 1](docs/decisoes-de-modelagem.md#1-camadas) e [9.1](docs/decisoes-de-modelagem.md#91-o-papel-da-gold-o-critério-é-o-grão) |
| Integridade referencial | 31 testes `relationships`, 10 deles na gold ([`_modelos.yml`](models/gold/devedores/_modelos.yml)); chave `NULL`, sem linha "desconhecido" ([ERD](docs/erd.md)) |
| Eficiência do modelo e tipos | [dicionário, ganhos medidos dos tipos](docs/dicionario-de-dados.md#ganhos-medidos-dos-tipos); materialização medida nas decisões, [seção 1](docs/decisoes-de-modelagem.md#1-camadas) |
| Deduplicação e conflitos cadastrais | decisões [5.3](docs/decisoes-de-modelagem.md#53-deduplicação-pela-chave-de-cada-tabela), [6](docs/decisoes-de-modelagem.md#6-mudança-de-rumo-histórico-de-versões-2026-11-10), [9.5](docs/decisoes-de-modelagem.md#95-quem-é-o-devedor-documentos-ruidosos-ligados-a-um-cpf) e [9.7](docs/decisoes-de-modelagem.md#97-escolha-de-atributos-e-conflitos) |
| Dados incompletos ou ruidosos | decisões [5.8](docs/decisoes-de-modelagem.md#58-linhas-sem-chave-e-documento-que-não-identifica-ninguém) e [9.5](docs/decisoes-de-modelagem.md#95-quem-é-o-devedor-documentos-ruidosos-ligados-a-um-cpf); [contratos de dados](docs/contratos-de-dados.md) |
| Régua: critérios e equilíbrio entre cobrança e proteção a terceiros | decisões [9.9](docs/decisoes-de-modelagem.md#99-régua-de-risco); análises, [régua de cobrança](docs/analises.md#régua-de-cobrança) e [ajustes](docs/analises.md#propostas-de-ajuste-e-o-loop-de-refinamento) |
| Limites das inferências | [Limites das respostas](#-limites-das-respostas); decisões [8](docs/decisoes-de-modelagem.md#8-o-que-não-foi-verificado), [9.12](docs/decisoes-de-modelagem.md#912-o-que-não-foi-verificado-na-gold) e [10.4](docs/decisoes-de-modelagem.md#104-o-que-não-foi-verificado) |
| Monitoramento volumétrico e anomalias | [docs/monitoramento.md](docs/monitoramento.md); análises, [anomalias na ingestão](docs/analises.md#anomalias-na-ingestão) |

| Termo | Significado |
|---|---|
| régua | a classificação de cada par em `liberado`, `atencao` ou `bloqueado`, feita pela macro `regua_de_risco()` |
| par devedor × contato | um telefone ou e-mail de um devedor: o grão da `dim_contato` e o que a régua classifica |
| contato migrado | contato que um CPF recebe depois da última entrega de outro CPF que o tinha |
| ponto cego | par `liberado` cuja tentativa terminou com um terceiro |
| acurácia balanceada | a média entre a fração dos desfechos de risco em `atencao` ou `bloqueado` e a fração dos contatos confirmados em `liberado` |
| loop de refinamento | cada ajuste aplicado à régua, medido nos cortes de 15/09 e 22/09 e revertido se rejeitado; para em 3 rejeições seguidas |

---

## 🚀 Como rodar

Requer o [uv](https://docs.astral.sh/uv/), que baixa o Python 3.14 se ele faltar. Com o Python 3.14 instalado, o `pip` comum também serve.

```bash
git clone https://github.com/Sebastian6-6/collections-contact-risk.git
cd collections-contact-risk
uv venv --python 3.14
source .venv/bin/activate            # Windows: .venv\Scripts\activate
uv pip install -r requirements.txt   # ou: pip install -r requirements.txt
python pipeline.py                   # recria o banco, grava a bronze e roda o dbt build
dbt show --select lista_nao_contatar # qualquer consulta de analyses/
```

**Resultado esperado:** cerca de 1 minuto do clone ao fim (57 s medidos num clone limpo em 2026-11-10), terminando em `PASS=608 WARN=9 ERROR=0` e `[OK] pipeline concluída`. Os 9 `WARN` são testes de aviso de propósito, que contam casos conhecidos em vez de falhar: linhas sem chave (alfa, beta e gama), cabeçalho repetido, contatos truncados da gama, um país que a tabela da Receita não tem, versões empatadas, documentos ligados por correção e tentativas sem par.

**Windows:** clone num caminho curto, perto da raiz do disco, ou [ative os caminhos longos](https://learn.microsoft.com/en-us/windows/win32/fileio/maximum-file-path-limitation). Um clone num caminho de cerca de 140 caracteres quebrou o dbt pelo limite de 260 caracteres do Windows.

`python pipeline.py` apaga `database/collections_contact_risk.duckdb`, lê todos os arquivos e roda o `dbt build` com os testes. Duas execuções a partir do mesmo estado dão o mesmo resultado (p. 2), e o CI confere isso rodando a pipeline duas vezes.

Se as variáveis `ALERTA_*` estiverem definidas, a pipeline manda um e-mail quando a ingestão ou o `dbt build` falham; sem elas, nada muda ([Alerta por e-mail](docs/monitoramento.md#4-alerta-por-e-mail)).

O download da Receita é opcional: o extrato usado já está versionado em `external_data/receita/2026-10/`. Para baixar de novo, `python -m ingestion.main --baixar receita` e depois `python pipeline.py` ([ingestao.md, seção 4](docs/ingestao.md#4-a-receita-como-exemplo-de-api)).

---

## 📁 Estrutura

| Pasta | O que tem |
|---|---|
| `ingestion/` | leitura dos arquivos das fontes para a bronze, sem transformação ([docs/ingestao.md](docs/ingestao.md)) |
| `models/` | o dbt por camada: `bronze/` (contrato das fontes, sem SQL), `silver/<fonte>/` e `gold/<domínio>/`. Em `gold/<domínio>/`, os modelos sem `dim_` ou `ft_` são etapas efêmeras e não viram tabela |
| `analyses/` | as consultas das análises, rodadas com `dbt show --select <consulta>` |
| `scripts/` | a medição da régua, a geração do dicionário, a checagem de execuções idênticas e o e-mail de alerta |
| `tests/` | os testes do pytest e os testes de dados do dbt |
| `macros/` | a padronização da silver e as regras da gold, como a régua e os alertas |
| `contact_data/` | os arquivos recebidos dos provedores e o histórico de contatos: a zona bruta imutável |
| `external_data/` | o extrato versionado dos dados abertos do CNPJ |
| `database/` | o banco DuckDB, criado pela pipeline a cada execução e fora do Git |
| `docs/` | os documentos da tabela da [Visão geral](#-visão-geral) |
| `.claude/` | a configuração do Claude Code: agentes e skills usados no desenvolvimento |
| `.context/` | a memória do projeto: o enunciado convertido, as referências e o estado de cada tópico |

---

## 🔌 Diferencial: um componente de ingestão para todas as fontes

A ingestão é um componente só para cinco fontes, em três formatos e duas origens: alfa (CSV), beta (JSON Lines), gama (CSV com JSON embutido), o histórico de cobrança e a Receita, que chega por API e é gravada como arquivo antes de ser lida. Uma fonte nova com formato e origem que já existem é uma entrada em `ingestion/fontes.yml`; um formato ou uma origem nova é uma função registrada por decorador, e o `main.py` não muda. Cada linha da bronze guarda o arquivo, a linha e o sha256 de origem, sem horário de execução. Detalhes em [docs/ingestao.md](docs/ingestao.md).

---

## 📌 Premissas

- **Os três provedores falam dos mesmos devedores, e a cobrança é uma operação só** (p. 1–2). 10.247 dos 20.103 CPFs válidos aparecem em dois ou mais provedores ([decisões, 9.4](docs/decisoes-de-modelagem.md#94-premissa-os-mesmos-devedores-uma-operação)).
- **Contato com terceiro** é a tentativa com resultado `numero_errado` ou `nao_conhece_devedor`.
- **Datas sem fuso** são horário de Brasília. É regra do projeto, não informação dos provedores ([decisões, 5.11](docs/decisoes-de-modelagem.md#511-fuso-horário-brasília)).
- **Documento ruidoso** (CPF com um dígito trocado, RG do beta) é ligado a um CPF existente só quando nome e nascimento coincidem com exatamente um CPF válido ([decisões, 9.5](docs/decisoes-de-modelagem.md#95-quem-é-o-devedor-documentos-ruidosos-ligados-a-um-cpf)).
- **Renda `0,00` do alfa** vira `NULL` na gold, como "não informada" ("ausência de dado é `NULL`, nunca zero", convenção do case); a silver guarda o valor recebido.
- **Empate entre versões** com as mesmas datas e o mesmo arquivo (208 documentos) se resolve pela última linha do arquivo, uma convenção arbitrária e determinística ([decisões, 6.5](docs/decisoes-de-modelagem.md#65-desempate-da-versão-atual-uma-convenção-arbitrária)).
- **Opt-out** bloqueia o contato para todos os CPFs ligados a ele; **falecido** bloqueia todos os pares do devedor ([decisões, 9.9](docs/decisoes-de-modelagem.md#99-régua-de-risco)).
- **Horário** diz quando, não com quem, e nunca muda o nível. A janela é a interseção da Lei SP 17.832/2023 com o SARB 27/2023: dias úteis das 8h às 20h, sábado das 9h às 14h, domingo e feriado proibidos, e-mail fora da regra ([decisões, 9.10](docs/decisoes-de-modelagem.md#910-horário-de-contato)).

---

## 🧱 Raciocínio das transformações

| Camada | O que faz | Por quê |
|---|---|---|
| bronze | uma linha por linha recebida, como veio, com a rastreabilidade | `contact_data/` é a zona bruta; nenhuma linha é descartada, nem a ilegível |
| silver | dentro de uma fonte: tipos, limpeza, histórico de versões e deduplicação por chave | a procedência é sinal de risco: depois do corte de 15/09, o contato de 2 ou 3 provedores deu terceiro em 1,37% das tentativas (41 de 2.986), contra 6,33% no de um só (234 de 3.695), e fundir antes apagaria isso ([decisões, seção 2](docs/decisoes-de-modelagem.md#2-fontes-base-única-não-é-fonte-única); [análises, peso dos sinais](docs/analises.md#peso-dos-sinais)) |
| gold | une as fontes, resolve conflitos e aplica a régua numa estrela (`gold_devedores`) e no fato de monitoramento (`gold_monitoramento`) | o critério é o grão: cada linha é uma entidade ou um evento recebido; os agregados ficam em `analyses/` ([decisões, 9.1](docs/decisoes-de-modelagem.md#91-o-papel-da-gold-o-critério-é-o-grão)) |

A régua é uma macro só, `regua_de_risco(data_corte)`: a `dim_contato` a chama sem corte, e a validação a chama com o corte de 15/09, então a régua validada é a que opera ([decisões, 9.9](docs/decisoes-de-modelagem.md#99-régua-de-risco)). Tudo é tabela, porque o banco é recriado a cada execução e a silver é lida por centenas de testes ([decisões, seção 1](docs/decisoes-de-modelagem.md#1-camadas), com a medição).

---

## 📊 Conclusões das análises

Os números, as consultas e as margens estão em [docs/analises.md](docs/analises.md).

- **Ingestão.** Seis incidentes em setembro (cabeçalho trocado, arquivo truncado e reenviado, dias sem entrega, dia repetido) geram 11 alertas em 5 entregas; nenhuma outra das 87 entregas gera alerta. A média por tipo de dia (útil ou fim de semana) é o que zera os alarmes falsos: a média simples daria 13, todos em fim de semana ([monitoramento.md](docs/monitoramento.md)).
- **CNPJ.** 8 dos 13 empregadores existem na Receita, todos ativos e do mesmo porte. O ganho é cadastral: 6.628 devedores (33%) têm como empregador um CNPJ que não existe como estabelecimento, e 10.770 (53%) passam a ter empregador confirmado. A situação do empregador não separa o risco de terceiro, e setor e porte não mudam a ordem dos canais.
- **Não-contatar.** 3.434 pares bloqueados, e 154 devedores com todos os pares bloqueados. No corte de 15/09, a régua põe em `atencao` ou `bloqueado` 202 de 275 tentativas que terminaram com terceiro (73,45%); o custo é 99 de 774 contatos confirmados (12,8%), dos quais 67 ainda recebem a mensagem neutra.
- **Sinais.** Contato compartilhado (32,2% de terceiro, 17,8 vezes o sem sinal, 506 tentativas), conflito de identidade (13,0 vezes, 49), quem disse não ser o devedor (12,5 vezes, 46) e contato migrado (7,3 vezes, 118) definem o nível.
- **Canais.** No `liberado`, WhatsApp e ligação confirmam 16%, e o e-mail 5,7%. No `atencao`, de 22% a 34% dos contatos são terceiros, por isso a mensagem é neutra; a ligação é indicada porque permite confirmar a identidade antes de falar da dívida.
- **Acurácia e calibração.** Acurácia balanceada de 0,6871 no corte de 15/09 e 0,7208 no controle de 22/09. O risco é 3,79% no `liberado`, 32,67% no `atencao` e 30,33% no `bloqueado`: a régua separa o `liberado`, mas não ordena os outros dois.
- **Erros e ajustes.** 73 pontos cegos (`liberado` que deu terceiro, todos sem sinal) e 99 falsos bloqueios. Quatro ajustes testados, nenhum aceito: mandar o contato de provedor único para `atencao` protege mais 40 terceiros e custa 377 confirmados. O maior espaço está fora da régua: 1.090 tentativas sem par no corte.
- **Horário.** Cerca de 20% das ligações, SMS e WhatsApp de setembro ficaram fora da janela adotada.

---

## 🚧 Limites das respostas

- **Dados sintéticos** (p. 2) e **um mês de histórico**: as taxas descrevem estes dados e não valem como estimativa para dados reais. A régua foi validada num corte (15/09) com um controle (22/09), e as hipóteses do loop foram formuladas olhando os dados depois do corte. A janela e o limite do alerta foram calibrados nos mesmos dados em que deram zero alarme falso.
- **PostgreSQL nunca foi executado.** O SQL segue o subconjunto compatível, e as versões PostgreSQL das macros foram escritas pela documentação, sem uma instância para rodar; os hashes de conteúdo podem diferir entre os motores ([decisões, seção 8](docs/decisoes-de-modelagem.md#8-o-que-não-foi-verificado)).
- **CI no GitHub:** o primeiro run no GitHub Actions, em 2026-11-10, passou em todas as etapas (pipeline do zero duas vezes com resultado idêntico, lint, pytest e parse do dbt). O CI não roda em PostgreSQL (ver acima).
- **As 5 versões a menos do beta** quando o texto passou para maiúscula (17.866 para 17.861): causa não isolada ([decisões, 6.4](docs/decisoes-de-modelagem.md#64-endereços-e-texto-em-maiúscula)).
- **Horário:** não verifiquei se SMS e WhatsApp contam como "telefonemas" na lei de SP, o alcance territorial da lei (a ADI 2342591-64.2023 do TJSP derrubou só os art. 194 e 195), se a operação é signatária da autorregulação da Febraban, nem os feriados estaduais e municipais ([decisões, 9.10](docs/decisoes-de-modelagem.md#910-horário-de-contato)).
- **A métrica não separa `atencao` de `bloqueado`:** os dois contam como risco pego, e mudar um sinal entre eles é decisão de política que o loop não julga.
- **O migrado depende das entregas parciais:** 94,7% dos pares não estavam na última entrega do provedor, e não verifiquei se as entregas são retratos completos ou atualizações.
- **O custo do `atencao` está superestimado:** o confirmado nesse nível conta como perdido, mas ainda recebe a mensagem neutra, cujo desfecho o histórico não tem.
- **CNPJ:** 8 dos 13 CNPJs foram encontrados; os 3 alfanuméricos não existem na base de 2026-10, que tem um único CNPJ alfanumérico. É uma base só, sem nenhum empregador baixado ou inapto, e o vínculo usado é o mais recente, não necessariamente o do dia da tentativa.
- **O que não foi verificado** em cada etapa está nas decisões, seções [8](docs/decisoes-de-modelagem.md#8-o-que-não-foi-verificado), [9.12](docs/decisoes-de-modelagem.md#912-o-que-não-foi-verificado-na-gold) e [10.4](docs/decisoes-de-modelagem.md#104-o-que-não-foi-verificado).

---

## 🔭 Com mais tempo

- **Um job de CI com serviço PostgreSQL**, para executar as versões PostgreSQL das macros e fechar o primeiro limite.
- **Uma tabela de presença por entrega** na silver, para saber se um par sumiu das entregas e avisar o dia perdido no próprio dia.
- **A régua como pontuação de 0 a 100 com faixas**, com os sinais que já estão em colunas, para usar o provedor único sem mandar 55% das tentativas para `atencao`; e cada tentativa avaliada com a régua de sete dias antes.
- **Banco persistido com carga incremental**, pulando o arquivo já carregado pelo caminho e pelo hash, quando reler tudo ficar caro ([decisões, seção 3](docs/decisoes-de-modelagem.md#3-ingestão)).

---

## 👤 Autor

Criado por **Pedro Alexandre Piassi Silva**.

[![LinkedIn: Pedro Piassi](https://img.shields.io/badge/LinkedIn-Pedro_Piassi-0A66C2?logo=linkedin&logoColor=white)](https://www.linkedin.com/in/pedro-piassi6/)

Dúvidas ou sugestões: me chame no [LinkedIn](https://www.linkedin.com/in/pedro-piassi6/).

<p align="right"><a href="#readme-top">↑ topo</a></p>
