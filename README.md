<a name="readme-top"></a>

<div align="center">

# 📞 collections-contact-risk

### Base cadastral única de devedores e régua de risco para não contatar quem não deve

Criado por **Pedro Alexandre Piassi Silva** · [![LinkedIn: Pedro Piassi](https://img.shields.io/badge/LinkedIn-Pedro_Piassi-0A66C2?logo=linkedin&logoColor=white)](https://www.linkedin.com/in/pedro-piassi6/)

![DuckDB](https://img.shields.io/badge/DuckDB-embutido-FFF000?logo=duckdb&logoColor=black)
![dbt Core](https://img.shields.io/badge/dbt_Core-dbt--duckdb-FF694B?logo=dbt&logoColor=white)
![Python 3.14](https://img.shields.io/badge/python-3.14-3776AB?logo=python&logoColor=white)
[![CI](https://github.com/Sebastian6-6/collections-contact-risk/actions/workflows/ci.yml/badge.svg)](https://github.com/Sebastian6-6/collections-contact-risk/actions/workflows/ci.yml)

[Como rodar](#-como-rodar) · [Premissas](#-premissas) · [Transformações](#-raciocínio-das-transformações) · [Conclusões](#-conclusões-das-análises) · [Limites](#-limites-das-respostas) · [Com mais tempo](#-com-mais-tempo)

</div>

---

## 🧭 Visão geral

Solução de um case técnico de dados de cobrança (enunciado anonimizado). Três provedores mandam todo dia o cadastro dos devedores, cada um no seu formato, e o histórico de setembro/2026 traz as tentativas de contato. O risco central é "contatar quem não deve" (p. 1): expor a dívida a um terceiro.

A pipeline lê tudo, consolida uma base única por CPF, cruza o empregador com os dados abertos do CNPJ da Receita Federal e classifica cada par devedor × contato em `liberado`, `atencao` ou `bloqueado`. Os modelos não inventam linhas: cada uma corresponde a um registro recebido.

| Documento | O que tem |
|---|---|
| [docs/analises.md](docs/analises.md) | respostas da "Análise de Dados", com as consultas e a quantidade de casos |
| [docs/decisoes-de-modelagem.md](docs/decisoes-de-modelagem.md) | cada decisão, com as opções, os trade-offs e a página do enunciado |
| [docs/ingestao.md](docs/ingestao.md) | o componente de ingestão multi-fonte |
| [docs/monitoramento.md](docs/monitoramento.md) | os incidentes das entregas diárias e o alerta |
| [docs/contratos-de-dados.md](docs/contratos-de-dados.md) | o que cada provedor entrega e o que a gold recebe da silver |
| [docs/erd.md](docs/erd.md) · [docs/dicionario-de-dados.md](docs/dicionario-de-dados.md) | o ERD em Mermaid e o dicionário com a justificativa de cada tipo |
| [docs/qualidade-e-convencoes.md](docs/qualidade-e-convencoes.md) | cada regra do repositório e a checagem que a garante |
| [AGENTS.md](AGENTS.md) | as regras do repositório: as convenções do case e as do projeto |

---

## 🚀 Como rodar

Da raiz do repositório, com Python 3.14:

```bash
uv pip install -r requirements.txt   # ou: pip install -r requirements.txt
python pipeline.py                   # recria o banco, grava a bronze e roda o dbt build
dbt show --select lista_nao_contatar # qualquer consulta de analyses/
```

`python pipeline.py` apaga `database/collections_contact_risk.duckdb`, lê todos os arquivos e roda o `dbt build` com os testes. Duas execuções a partir do mesmo estado dão o mesmo resultado (p. 2), e o CI confere isso rodando a pipeline duas vezes.

O download da Receita é opcional: o extrato usado já está versionado em `external_data/receita/2026-10/`. Para baixar de novo, `python -m ingestion.main --baixar receita` e depois `python pipeline.py` ([ingestao.md](docs/ingestao.md), seção 4).

---

## 🔌 Diferencial: um componente de ingestão para todas as fontes

A ingestão é um componente só para cinco fontes, em três formatos e duas origens: alfa (CSV), beta (JSON Lines), gama (CSV com JSON embutido), o histórico de cobrança e a Receita, que chega por API e é gravada como arquivo antes de ser lida. Uma fonte nova com formato e origem que já existem é uma entrada em `ingestion/fontes.yml`; um formato ou uma origem nova é uma função registrada por decorador, e o `main.py` não muda. Cada linha da bronze guarda o arquivo, a linha e o sha256 de origem, sem horário de execução. Detalhes em [docs/ingestao.md](docs/ingestao.md).

---

## 📌 Premissas

- **Os três provedores falam dos mesmos devedores, e a cobrança é uma operação só** (p. 1–2). 10.250 dos 20.106 CPFs válidos aparecem em dois ou mais provedores ([decisoes-de-modelagem.md](docs/decisoes-de-modelagem.md), 9.4).
- **Contato com terceiro** é a tentativa com resultado `numero_errado` ou `nao_conhece_devedor`.
- **Datas sem fuso** são horário de Brasília. É regra do projeto, não informação dos provedores (5.11).
- **Documento ruidoso** (CPF com um dígito trocado, RG do beta) é ligado a um CPF existente só quando nome e nascimento coincidem com exatamente um CPF válido (9.5).
- **Renda `0,00` do alfa** vira `NULL` na gold, como "não informada" ("ausência de dado é `NULL`, nunca zero", convenção do case); a silver guarda o valor recebido.
- **Empate entre versões** com as mesmas datas e o mesmo arquivo (208 documentos) se resolve pela última linha do arquivo, uma convenção arbitrária e determinística (6.5).
- **Opt-out** bloqueia o contato para todos os CPFs ligados a ele; **falecido** bloqueia todos os pares do devedor (9.9).
- **Horário** diz quando, não com quem, e nunca muda o nível. A janela é a interseção da Lei SP 17.832/2023 com o SARB 27/2023: dias úteis das 8h às 20h, sábado das 9h às 14h, domingo e feriado proibidos, e-mail fora da regra (9.10).

---

## 🧱 Raciocínio das transformações

| Camada | O que faz | Por quê |
|---|---|---|
| bronze | uma linha por linha recebida, como veio, com a rastreabilidade | `contact_data/` é a zona bruta; nenhuma linha é descartada, nem a ilegível |
| silver | dentro de uma fonte: tipos, limpeza, histórico de versões e deduplicação por chave | a procedência é sinal de risco: contato visto por 2 ou 3 provedores erra 1,1%, contra 6,6% no de um só, e fundir antes apagaria isso (seção 2) |
| gold | une as fontes, resolve conflitos e aplica a régua numa estrela (`gold_devedores`) e no fato de monitoramento (`gold_monitoramento`) | o critério é o grão: cada linha é uma entidade ou um evento recebido; os agregados ficam em `analyses/` (9.1) |

A régua é uma macro só, `regua_de_risco(data_corte)`: a `dim_contato` a chama sem corte, e a validação a chama com o corte de 15/09, então a régua validada é a que opera (9.9). Tudo é tabela, porque o banco é recriado a cada execução e a silver é lida por centenas de testes (seção 1, com a medição). O ERD está em [docs/erd.md](docs/erd.md).

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
- **PostgreSQL nunca foi executado.** O SQL segue o subconjunto compatível, e as versões PostgreSQL das macros foram escritas pela documentação, sem uma instância para rodar; os hashes de conteúdo podem diferir entre os motores ([decisoes-de-modelagem.md](docs/decisoes-de-modelagem.md), seção 8).
- **CI no GitHub:** o primeiro run no GitHub Actions, em 2026-11-10, passou em todas as etapas (pipeline do zero duas vezes com resultado idêntico, lint, pytest e parse do dbt). O CI não roda em PostgreSQL (ver acima).
- **As 5 versões a menos do beta** quando o texto passou para maiúscula (17.866 para 17.861): causa não isolada (6.4).
- **Horário:** não verifiquei se SMS e WhatsApp contam como "telefonemas" na lei de SP, o alcance territorial da lei (a ADI 2342591-64.2023 do TJSP derrubou só os art. 194 e 195), se a operação é signatária da autorregulação da Febraban, nem os feriados estaduais e municipais (9.10).
- **A métrica não separa `atencao` de `bloqueado`:** os dois contam como risco pego, e mudar um sinal entre eles é decisão de política que o loop não julga.
- **O migrado depende das entregas parciais:** 94,7% dos pares não estavam na última entrega do provedor, e não verifiquei se as entregas são retratos completos ou atualizações.
- **O custo do `atencao` está superestimado:** o confirmado nesse nível conta como perdido, mas ainda recebe a mensagem neutra, cujo desfecho o histórico não tem.
- **CNPJ:** 8 dos 13 CNPJs foram encontrados; os 3 alfanuméricos não existem na base de 2026-10, que tem um único CNPJ alfanumérico. É uma base só, sem nenhum empregador baixado ou inapto, e o vínculo usado é o mais recente, não necessariamente o do dia da tentativa.
- **O que não foi verificado** em cada etapa está nas seções 8, 9.12 e 10.4 de [decisoes-de-modelagem.md](docs/decisoes-de-modelagem.md).

---

## 🔭 Com mais tempo

- **Um job de CI com serviço PostgreSQL**, para executar as versões PostgreSQL das macros e fechar o primeiro limite.
- **Alerta por e-mail** quando a pipeline falha ou o teste de entrega dá aviso; hoje o aviso fica no `run_results.json` do dbt.
- **Uma tabela de presença por entrega** na silver, para saber se um par sumiu das entregas e avisar o dia perdido no próprio dia.
- **A régua como pontuação de 0 a 100 com faixas**, com os sinais que já estão em colunas, para usar o provedor único sem mandar 55% das tentativas para `atencao`; e cada tentativa avaliada com a régua de sete dias antes.
- **Banco persistido com carga incremental**, pulando o arquivo já carregado pelo caminho e pelo hash, quando reler tudo ficar caro (seção 3).

---

## 👤 Autor

Criado por **Pedro Alexandre Piassi Silva**.

[![LinkedIn: Pedro Piassi](https://img.shields.io/badge/LinkedIn-Pedro_Piassi-0A66C2?logo=linkedin&logoColor=white)](https://www.linkedin.com/in/pedro-piassi6/)

Dúvidas ou sugestões: me chame no [LinkedIn](https://www.linkedin.com/in/pedro-piassi6/).

<p align="right"><a href="#readme-top">↑ topo</a></p>
