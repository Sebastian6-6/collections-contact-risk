# G3a′ — who enters dim_devedor and how noisy documents are linked

Approved by the owner in the stage-6 design session (2026-11-10). Supersedes G3a (option B as first decided) only where stated below. Source of truth for the execution step and for the matching section of `docs/decisoes-de-modelagem.md` (write that section in pt-BR, citing the brief pages).

## 1. Decision

`dim_devedor` has one row per **person identified by a CPF**. Every received document reaches the gold, but a noisy document is **linked to an existing debtor** when the evidence is strong, instead of becoming a second person:

| Case | Rule | Measured (raw files, 2026-11-10) | Result |
|---|---|---|---|
| 1. Invalid CPF (check digit fails), not all zeros | Same normalized name **and** same birth date as **exactly one** valid CPF **and** differs from it in **exactly one digit** | 372 documents | Linked to that valid CPF's debtor |
| 2. Document labeled `RG` by beta | Same normalized name **and** same birth date as **exactly one** valid CPF (no digit test possible) | 30 documents | Linked to that debtor (weaker evidence, flagged separately) |
| 3a. Invalid CPF not linked (about 100, plus 9 tie cases) | No link | — | Own row in `dim_devedor` with `flag_cpf_valido = false` (decision G3a/B); it is still a CPF, so the natural key stays `cpf` |
| 3b. `RG` not linked (12 without a candidate, 1 tie) | No link | 13 documents | Not a debtor (owner, 2026-11-10): same rule as records without a document, contacts in `dim_contato` with `sk_devedor` NULL, blocked. Keeps `dim_devedor` as "one row per person identified by a CPF" and the key a single `cpf` column |
| Valid CPF | Natural key | 20,106 distinct documents | Own row, `flag_cpf_valido = true` |
| Records with an empty or all-zero document (ingestion R3) | Not a debtor | 124 source lines | Contacts in `dim_contato` with `sk_devedor` NULL, blocked (G2c′) |

A linked record contributes its contacts, addresses and employment records to the debtor it was linked to. Its attributes take part in the G3b choice rules like any other record of that debtor.

## 2. Why (brief)

- p. 1: "base cadastral **única**": a noisy copy of a person must not become a second person.
- p. 1: the central risk is contacting the wrong person; merging two different people is the worst error, so the rule is deterministic and demands several independent agreements.
- p. 3: evaluation of "consistência no tratamento de **deduplicações**, conflitos cadastrais e dados incompletos ou **ruidosos**".
- p. 4: "transparência quanto aos **limites das inferências**": the rule, the counts and the residual risk go to the README.
- Case convention "no rows that do not exist in the source": nothing is invented; a linked record is a received record attached to a received debtor.
- Cross-source matching belongs to the gold (silver decision C3).

## 3. Evidence (how it was measured)

Throwaway DuckDB script in the session scratchpad, reading `contact_data/` in memory (all historical and daily files of the three providers). Normalization used for the measurement:

- document: digits only, left-padded to 11;
- CPF check digit: standard mod-11 on both digits, all-equal-digit sequences rejected;
- name: `UPPER(strip_accents(TRIM(name)))`;
- birth date: `dd/mm/yyyy` converted to ISO, otherwise the first 10 characters.

| Group | Documents | Same name + birth as a valid CPF | Exactly one candidate | Digit distance to the matched CPF |
|---|---|---|---|---|
| Invalid CPF | 481 | 381 (79%) | 372 (9 have 2) | 381 pairs at exactly 1 digit; a handful of other pairs at 7-11 digits |
| beta `RG` | 42 (9 characters, mask `NN.NNN.NNN-D`; none appears as a CPF in alfa/gama) | 31 (74%) | 30 (1 has 2) | n/a |
| Control: valid CPF vs another valid CPF | about 20,100 | 415 (about 2%) | — | — |

Reading: an invalid CPF is almost always a **one-digit typo** of a person already in the registry. A single wrong digit is the error class the check digit is designed to catch. The 79% vs 2% control rate shows the name + birth agreement is not chance.

Not verified: the official RG format of any state (no official source consulted); that the RG numbers are valid (no national check digit). Numbers must be re-measured on the silver during execution, and the commit body must state the final counts.

## 4. Matching rule, precisely (to implement in the gold)

1. Candidates are valid CPFs (`flag_cpf_valido = true`) from any provider.
2. Name and birth date are compared after the same standardization the silver applies. If the silver normalization differs from the measurement above, use the silver one and re-measure.
3. Case 1 requires all three: same name, same birth date, Hamming distance 1 between the 11-digit strings.
4. Case 2 requires same name and same birth date.
5. Both cases require **exactly one** candidate CPF. Ties are never resolved; they fall into case 3.
6. The window functions allowed by the case (`ROW_NUMBER`, `SUM` with `ROWS BETWEEN`) are enough: count candidates with `SUM(1)` per noisy document, and keep only the rows where the count is 1.

## 5. Columns it adds — SUPERSEDED by PLAN.md §3 (2026-11-10)

Approved columns: `dim_devedor.situacao_cpf` (`valido`, `invalido`) instead of `flag_cpf_valido`, `dim_devedor.qt_documentos_vinculados`, and on `dim_contato` `situacao_documento` (`cpf_valido`, `cpf_corrigido`, `rg_por_nome_nascimento`, `cpf_invalido`, `sem_documento`) plus `documento_original`. Wherever this note says `flag_cpf_valido = false`, read `situacao_cpf = 'invalido'`. The original proposal follows for the record.

Approved so far: "a flag for a corrected document and the lineage of where it came from". The column set below is a proposal to confirm with G3b.

- On `dim_devedor`: `flag_cpf_valido`, plus `qt_documentos_vinculados` (number of noisy documents linked to this debtor).
- On the rows that carry a linked record's contribution (contacts, addresses, employment records): the original document as received (`documento_original`) and a type of link (`tipo_vinculo_documento`: `cpf_corrigido` or `rg_por_nome_nascimento`), so every linked contribution is traceable and can be excluded in one filter. Exact placement is settled with G3b.
- Lineage (`_arquivo`, `_linha`, `_hash_arquivo`) stays on every row, as in R1.

## 6. Tests the execution must include

- Unit test (dbt unit test) for each rule: one-digit typo with a unique candidate is linked; two-digit difference is not linked; two candidates is not linked; RG with a unique name + birth match is linked; RG with no match stays apart.
- Every linked document points to a debtor with `flag_cpf_valido = true`.
- No valid CPF is ever linked to another document.
- Count test (warn): linked documents per case and per provider, reported in the commit body and the README.

## 7. Risks and limits (README)

- Two different people with the same name, the same birth date and CPFs one digit apart would be merged. This is considered unlikely given the unique-candidate requirement, but **the probability was not measured**.
- Case 2 has no digit check, so it is weaker evidence. Its contributions carry `tipo_vinculo_documento = rg_por_nome_nascimento`, so the risk scale can treat them more strictly (decision pending in the scale stage).
- Synthetic data: the name + birth collision rate among valid CPFs (about 2%) shows names repeat in the data. Real data could differ.
- Evolution with more time: probabilistic record linkage (name similarity, address, contact overlap) instead of exact equality.
