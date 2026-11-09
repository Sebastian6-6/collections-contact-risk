# Industry patterns behind the ingestion and silver decisions — facts used by this project

Sources accessed 2026-11-09 (current pages at that date). This is a note, not a copy:
these vendors' documentation has no open license declared (Airbyte's repository license
is reported as NOASSERTION by the GitHub API), so only the facts the project relies on
are recorded here, in my own words. Openly licensed pages are kept as copies instead:
dbt snapshots (Markdown), dbt intermediate layer (HTML) and dlt destination tables (PDF),
all Apache 2.0.

## 1. Loaders track files and only append; dedup is downstream (decisions I1, C3)

- Databricks Auto Loader, FAQ and options
  (https://docs.databricks.com/aws/en/ingestion/cloud-object-storage/auto-loader/faq,
  https://docs.databricks.com/aws/en/ingestion/cloud-object-storage/auto-loader/options):
  by default each file is ingested exactly once, tracked by path in the checkpoint;
  with `cloudFiles.allowOverwrites` a changed file is reprocessed whole and duplicates
  are the consumer's problem; Databricks recommends ingesting immutable files only.
- Snowflake COPY INTO and load metadata
  (https://docs.snowflake.com/en/user-guide/data-load-considerations-load,
  https://docs.snowflake.com/en/sql-reference/sql/copy-into-table): the table keeps load
  metadata per file (name, size, ETag/checksum); already loaded files are skipped unless
  `FORCE = TRUE`, which can duplicate rows.
- Medallion (Azure Databricks: https://learn.microsoft.com/en-us/azure/databricks/lakehouse/medallion;
  Fabric MDW: https://learn.microsoft.com/en-us/azure/architecture/databases/architecture/dataops-mdw;
  healthcare data solutions: https://learn.microsoft.com/en-us/industry/healthcare/healthcare-data-solutions/data-architecture-and-management):
  bronze is typically append-only/immutable and keeps invalid records; silver is where
  data is cleansed, normalized and deduplicated; business aggregates belong to gold.

## 2. Lineage columns are a two-part universal pattern (decision I3)

- Per row, origin + position + content key:
  - Snowflake staged-file metadata (https://docs.snowflake.com/en/user-guide/querying-metadata):
    `METADATA$FILENAME`, `METADATA$FILE_ROW_NUMBER`, `METADATA$FILE_CONTENT_KEY` (file checksum).
  - Fivetran file connectors (https://fivetran.com/docs/connectors/files,
    https://fivetran.com/docs/core-concepts/system-columns-and-tables): `_file`, `_line`
    (physical position), `_modified`, `_fivetran_synced`.
  - Databricks file metadata column (https://docs.databricks.com/aws/en/ingestion/file-metadata-column):
    `_metadata.file_path`, `file_name`, `file_size`, `file_modification_time`, `file_block_start`.
- Per load, a load register referenced from every row (works for APIs too):
  - dlt (copy kept: `dlt/destination-tables.pdf`): `_dlt_load_id` on rows -> `_dlt_loads`; `_dlt_id` per row.
  - Airbyte (https://docs.airbyte.com/platform/understanding-airbyte/airbyte-metadata-fields):
    `_airbyte_raw_id` (random UUID), `_airbyte_extracted_at`, `_airbyte_meta` (with `changes`:
    what the loader could not fit into the schema).
- Not adopted, on purpose: load time, file modification time and random ids, because they
  change on every run and would break identical executions (brief p. 2).

## 3. History grain (decision S4) and multivalued attributes (decision S5)

- Full-record history = SCD type 2: dbt snapshots (copy kept: `dbt/snapshots.md`), Data Vault
  satellites with a hashdiff (secondary sources, e.g.
  https://www.varigence.com/blog/the-other-hash-in-your-data-vault-satellite-hashdiff-change-detection).
  Rejected here: no brief question needs it, and snapshots need persisted state.
- Relationship history = Data Vault effectivity satellite on a link (secondary:
  https://www.wikiwand.com/en/Data_vault_modeling). Closest to `devedores_contatos`.
- Multivalued attribute = bridge table (Kimball Group:
  https://www.kimballgroup.com/data-warehouse-business-intelligence-resources/kimball-techniques/dimensional-modeling-techniques/multivalued-dimension-bridge-table/;
  Design Tip #166 https://www.kimballgroup.com/2014/05/design-tip-166-potential-bridge-table-detours/
  warns about double counting (unless the bridge carries an allocation/weighting factor)
  and mentions compromises such as keeping the primary value (e.g. the primary account
  holder) as a dimension attribute to avoid navigating the bridge in every query; Design Tip #142 https://www.kimballgroup.com/2012/02/design-tip-142-building-bridges/
  builds the bridge by unpivoting). Columns per value (phone1, phone2 / one boolean per
  provider) are a repeating group, the classic 1NF violation (e.g.
  https://help.hcl-software.com/onedb/current/ddi/ids_ddi_188.html).

## 4. What belongs to silver (decision C3)

- dbt staging (copy kept: `dbt/how-we-structure-2-staging.md`): renaming, type casting,
  basic computations, categorizing; no aggregations, no joins.
- dbt intermediate (copy kept: `dbt/how-we-structure-3-intermediate.html`): re-graining
  (fan out or collapse) and isolating complex logic; add a primary key test to re-grained models.
- The brief names only "bronze, staging/silver, marts/gold" (p. 3), so this project's silver
  = dbt staging + intermediate work inside ONE source; anything crossing sources is gold.
