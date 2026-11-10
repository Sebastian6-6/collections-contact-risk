# Análises

Respostas aos itens da "Análise de Dados" do enunciado (p. 1–2). Cada número sai de uma consulta de `analyses/`, rodada com `dbt show --select <consulta>` depois de `python pipeline.py`, e vem com a quantidade de casos ao lado da taxa. Os dados são sintéticos (p. 2) e cobrem um mês.

## O que a base de CNPJ agrega

O enunciado pede para "demonstrar o que a base de CNPJ agrega à esteira de cobrança" (p. 2). O cruzamento está na seção 10 de [decisoes-de-modelagem.md](decisoes-de-modelagem.md); aqui fica o que ele mostra.

**Cobertura** (`cnpj_cobertura_empregadores`). Dos 13 CNPJs de empregador recebidos, 8 existem como estabelecimento na Receita e 10 têm a raiz (os 8 primeiros caracteres) registrada. Os 5 não encontrados são:

- os 3 alfanuméricos (`3RT8XB51000136`, `A7K2M9Q4000140`, `Z0P4LC22000124`), cuja raiz não existe na base;
- `04182736500157` e `51930487200150`, cuja raiz existe, mas não com essa ordem e esse dígito.

**Situação do empregador** (`cnpj_taxas_por_situacao`). Cada devedor tem no máximo um vínculo atual:

| Situação do empregador atual | Devedores | Tentativas em setembro | Terceiro | Contato confirmado |
|---|---|---|---|---|
| ativa na Receita | 10.770 (53%) | 7.991 | 326 (4,08% ± 0,43) | 961 (12,03% ± 0,71) |
| CNPJ não encontrado | 6.628 (33%) | 5.056 | 187 (3,70% ± 0,52) | 633 (12,52% ± 0,91) |
| sem vínculo atual | 2.783 (14%) | 2.006 | 76 (3,79% ± 0,84) | 250 (12,46% ± 1,45) |

A margem é a meia largura do intervalo de 95% (aproximação normal). Os 8 empregadores encontrados estão todos `ATIVA` e com porte `DEMAIS`: nenhum devedor tem vínculo com empresa baixada, inapta ou suspensa. As taxas das três situações cabem nas margens umas das outras, então a situação do empregador não separa o risco de falar com terceiro nem a chance de confirmar o contato.

**Setor e porte** (`cnpj_cobertura_empregadores`). Os 8 encontrados são 4 instituições financeiras (CNAE 6421200, 6422100 e 6423900), petróleo, minério de ferro, cerveja e lojas de departamento. Cada empregador tem de 1.296 a 1.423 devedores e de 943 a 1.095 tentativas; o terceiro vai de 2,94% a 4,66% (margens de ±1,1 a ±1,3 p.p.) e o contato confirmado, de 11,24% a 13,57% (±1,9 a ±2,1 p.p.). O porte é o mesmo para todos. A ordem dos canais também não muda com o empregador: em cada situação, ligação e WhatsApp confirmam mais (16,5% a 18,4%) e o e-mail menos (5,5% a 6,3%). A estratégia de canal segue o nível de risco, e não o setor ou o porte.

**O que agrega, então:**

1. **Qualidade cadastral.** 6.628 devedores (33%) têm como empregador atual um CNPJ que não existe como estabelecimento. É um achado para devolver aos provedores que o dígito verificador não pega, porque ele é válido nos 13.
2. **Empregador confirmado.** Para 10.770 devedores (53%), a operação sabe que o empregador existe e está ativo, com razão social, CNAE e município, onde antes havia só um número.
3. **Um sinal pronto para quando aparecer.** A `dim_empregador` já traz a situação cadastral, a data e o motivo. Um empregador baixado ou inapto pode indicar renda em risco e mudar a prioridade da cobrança, mas é uma hipótese: nestes dados não há nenhum, e o efeito não pode ser medido.

Limites: a base da Receita é a de 2026-10, uma só; o vínculo atual é o registro mais recente do devedor, não necessariamente o que valia no dia da tentativa; a distribuição quase uniforme dos devedores entre os 13 empregadores parece própria de dados sintéticos e não deve ser generalizada.
