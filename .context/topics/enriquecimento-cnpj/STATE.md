---
topic: enriquecimento-cnpj
status: active
created: 2026-11-10
updated: 2026-11-10 04:42
scope:
  - scripts/extrair_receita_cnpj.py
  - dados_externos/
  - models/gold/devedores/dim_empregador.sql
  - .context/raw/referencias/receita/
---
# enriquecimento-cnpj

## Goal
Stage 7: enrich every CNPJ received (dim_empregador) with Receita Federal open data (company name, CNAE, situation, size, UF) through a reproducible, versioned extract, so the pipeline stays offline (brief p. 1-2).

## Plan
<!-- "- [ ]" todo · "- [x]" done · "- [~]" dropped (add " — reason"). Done and dropped items move to HISTORY.md on save. -->
- [ ] _first step_

## Where we stopped
_Nothing yet._

## Pending
<!-- Unconfirmed questions: "- [?] question (where it came up, date)". Never treat them as a standard until the user answers. -->

## Decisions
<!-- Local to this topic, append-only: "- YYYY-MM-DD decision". -->
- 2026-11-10 Owner 2026-11-10 (closing round): Receita CNPJ open data is ingested UNFILTERED and reproducibly through the project's multi-source ingestion component (connector in ingestion/conectores.py + entry in ingestion/fontes.yml), as a source of its own with the same bronze/silver pattern: schemas bronze_receita/silver_receita, source column names and values kept; gold crosses those tables with dim_empregador. The multi-source ingestion component is a key differentiator and must be well documented. Download authorized.
- 2026-11-10 Owner 2026-11-10 (after measuring: 2026-10 release = 37 zips, 7.8 GB, ~223M rows; no official checksum, no open official API): new connector 'receita' (official Receita Nextcloud WebDAV, month 2026-10 pinned in fontes.yml) downloads the 37 files, computes and records the sha256 of each, and writes into the versioned folder the 6 domain tables complete (cnaes, motivos, municipios, naturezas, paises, qualificacoes) plus, from empresas/estabelecimentos/simples/socios, the rows of the received companies. Pipeline and CI read only the versioned folder (offline). Same bronze/silver per source, column names from the official layout (cnpj-metadados.pdf 2021-12-02). README documents the component and how to download everything. Research note: pesquisa-receita.md in this topic.

## Documents in use
<!-- "- doc-id (p.10-14): why it matters". Ids come from .context/index.md. -->
