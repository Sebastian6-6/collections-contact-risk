---
id: referencias-dlt-destination-tables
source: raw/referencias/dlt/destination-tables.pdf
origin: https://dlthub.com/docs/general-usage/destination-tables (fonte 3ec3cfc no repositório dlt-hub/dlt) · impresso em PDF · acesso 2026-11-09
sha256: 9e132f5078300dc178ff73340642972842e020ff48ea18d3f2acb22794006ae6
converter: docling 2.149.0
converted: 2026-11-09 18:46
pages: 13
kind: document
---
<!-- page 1 -->
Version: 1.32.0 (latest) View Markdown

## Destination tables

When you run a pipeline, dlt creates tables in the destination database and loads the data from your source into these tables. In this section, we will take a closer look at what destination tables look like and how they are organized.

We start with a simple dlt pipeline:

```
import dlt data = [ {'id': 1, 'name': 'Alice'}, {'id': 2, 'name': 'Bob'} ] pipeline = dlt.pipeline( pipeline_name='quick_start', destination='duckdb', dataset_name='mydata' ) load_info = pipeline.run(data, table_name="users")
```

<!-- image -->

Here we are using the DuckDb destination, which is an in-memory database. Other database destinations will behave similarly and have similar concepts.

Running this pipeline will create a database schema in the destination database (DuckDB) along with a table named users . Quick tip: you can use the show command of the dlt pipeline CLI to see the tables in the destination database. We use essential cookies to make our site work. With your consent, we may also use nonessential cookies to improve user experience and analyze website traffic. By clicking "Accept," you agree to our website's cookie use as described in our Cookie Policy and Privacy Policy. You can change your cookie settings at any time by clicking "Preferences."

Database schema Preferences Decline Accept Ask AI

<!-- page 2 -->
The database schema is a collection of tables that represent the data you loaded into the database. The schema name is the same as the dataset\_name you provided in the pipeline definition. In the example above, we explicitly set the dataset\_name to mydata . If you don't set it, it will be set to the pipeline name with a suffix \_dataset .

Be aware that the schema referred to in this section is distinct from the dlt Schema. The database schema pertains to the structure and organization of data within the database, including table definitions and relationships. On the other hand, the "dlt Schema" specifically refers to the format and structure of normalized data within the dlt pipeline.

## Tables

Each resource in your pipeline definition will be represented by a table in the destination. In the example above, we have one resource, users , so we will have one table, mydata.users , in the destination. Here, mydata is the schema name, and users is the table name. Here also, we explicitly set the table\_name to users . When table\_name is not set, the table name will be set to the resource name.

For example, we can rewrite the pipeline above as:

The result will be the same; note that we do not explicitly pass table\_name="users" to pipeline.run , and the table is implicitly named users based on the resource name (e.g., users() decorated with @dlt.resource ). @dlt.resource def users(): yield [ {'id': 1, 'name': 'Alice'}, {'id': 2, 'name': 'Bob'} ] pipeline = dlt.pipeline( pipeline\_name='quick\_start', destination='duckdb', dataset\_name='mydata' ) load\_info = pipeline.run(users) We use essential cookies to make our site work. With your consent, we may also use nonessential cookies to improve user experience and analyze website traffic. By clicking "Accept," you agree to our website's cookie use as described in our Cookie Policy and Privacy Policy. You can change your cookie settings at any time by clicking "Preferences."

<!-- page 3 -->
<!-- image -->

Special tables are created to track the pipeline state. These tables are prefixed with \_dlt\_ and are not shown in the show command of the dlt pipeline CLI. However, you can see them when connecting to the database directly.

## Nested tables

Now let's look at a more complex example:

```
import dlt data = [ { 'id': 1, 'name': 'Alice', 'pets': [ {'id': 1, 'name': 'Fluffy', 'type': 'cat'}, {'id': 2, 'name': 'Spot', 'type': 'dog'} ] }, { 'id': 2, 'name': 'Bob', 'pets': [ {'id': 3, 'name': 'Fido', 'type': 'dog'} ] }
```

Running this pipeline will create two tables in the destination, users (root table) and users\_\_pets (nested table). The users table will contain the top-level data, and the users\_\_pets table will contain the data nested in the Python lists. Here is what the tables may look like: ] pipeline = dlt.pipeline( pipeline\_name='quick\_start', destination='duckdb', dataset\_name='mydata' ) load\_info = pipeline.run(data, table\_name="users") We use essential cookies to make our site work. With your consent, we may also use nonessential cookies to improve user experience and analyze website traffic. By clicking "Accept," you agree to our website's cookie use as described in our Cookie Policy and Privacy Policy. You can change your cookie settings at any time by clicking "Preferences."

<!-- page 4 -->
|   id | name   | _dlt_id        |     _dlt_load_id |
|------|--------|----------------|------------------|
|    1 | Alice  | wX3f5vn801W16A | 1234562350.98417 |
|    2 | Bob    | rX8ybgTeEmAmmA | 1234562350.98417 |

mydata.users\_\_pets

|   id | name   | type   | _dlt_id        | _dlt_parent_id   |   _dlt_list_idx |
|------|--------|--------|----------------|------------------|-----------------|
|    1 | Fluffy | cat    | w1n0PEDzuP3grw | wX3f5vn801W16A   |               0 |
|    2 | Spot   | dog    | 9uxh36VU9lqKpw | wX3f5vn801W16A   |               1 |
|    3 | Fido   | dog    | pe3FVtCWz8VuNA | rX8ybgTeEmAmmA   |               0 |

When inferring a database schema, dlt maps the structure of Python objects (i.e., from parsed JSON files) into nested tables and creates references between them.

This is how it works:

1. Each row in all (root and nested) data tables created by dlt contains a unique column named \_dlt\_id (row key).
2. Each nested table contains a column named \_dlt\_parent\_id referencing a particular row ( \_dlt\_id ) of a parent table (parent key).

3. Rows in nested tables come from the Python lists: dlt stores the position of each item in the list in \_dlt\_list\_idx . 4. For nested tables that are loaded with the merge write disposition, we add a root key column \_dlt\_root\_id , which references the child table to a row in the root table. Learn more about nested references, row keys, and parent keys We use essential cookies to make our site work. With your consent, we may also use nonessential cookies to improve user experience and analyze website traffic. By clicking "Accept," you agree to our website's cookie use as described in our Cookie Policy and Privacy Policy. You can change your cookie settings at any time by clicking "Preferences."

Naming convention: tables and columns During a pipeline run, dlt normalizes both table and column names to ensure compatibility with the destination database's accepted format. All names from your source data will be transformed into snake\_case and will only include alphanumeric characters. Please be aware that the names in the destination database may differ somewhat from those in your original input.

<!-- page 5 -->
## Variant columns

If your data has inconsistent types, dlt will dispatch the data to several variant columns. For example, if you have a resource (i.e., a JSON file) with a field named answer and your data contains boolean values, you will get a column named answer of type BOOLEAN in your destination. If, for some reason, on the next load, you get integer and string values in answer , the inconsistent data will go to answer\_\_v\_bigint and answer\_\_v\_text columns respectively. The general naming rule for variant columns is &lt;original name&gt;\_\_v\_&lt;type&gt; where original\_name is the existing column name (with data type clash) and type is the name of the data type stored in the variant.

## Load packages and load IDs

Each execution of the pipeline generates one or more load packages. A load package typically contains data retrieved from all the resources of a particular source. These packages are uniquely identified by a load\_id . The load\_id of a particular package is added to the top data tables (referenced as \_dlt\_load\_id column in the example above) and to the special \_dlt\_loads table with a status of 0 (when the load process is fully completed).

To illustrate this, let's load more data into the same destination:

<!-- image -->

<!-- page 6 -->
|   id | name    | _dlt_id        |     _dlt_load_id |
|------|---------|----------------|------------------|
|    1 | Alice   | wX3f5vn801W16A | 1234562350.98417 |
|    2 | Bob     | rX8ybgTeEmAmmA | 1234562350.98417 |
|    3 | Charlie | h8lehZEvT3fASQ | 1234563456.12345 |

The \_dlt\_loads table will look like this:

mydata.\_dlt\_loads

|          load_id | schema_name   |   status | inserted_at                  | schema_version_hash   |
|------------------|---------------|----------|------------------------------|-----------------------|
| 1234562350.98417 | quick_start   |        0 | 2023-09-12 16:45:51.17865+00 | aOEb...Qekd/58=       |
| 1234563456.12345 | quick_start   |        0 | 2023-09-12 16:46:03.10662+00 | aOEb...Qekd/58=       |

The \_dlt\_loads table tracks complete loads and allows chaining transformations on top of them. Many destinations do not support distributed and long-running transactions (e.g., Amazon Redshift). In that case, the user may see the partially loaded data. It is possible to filter such data out: any row with a load\_id that does not exist in \_dlt\_loads is not yet completed. The same procedure may be used to identify and delete data for packages that never got completed.

For each load, you can test and alert on anomalies (e.g., no data, too much loaded to a table). There

are also some useful load stats in dashboard app mentioned above. You can add transformations and chain them together using the status column. You start the transformation for all the data with a particular load\_id with a status of 0 and then update it to 1. We use essential cookies to make our site work. With your consent, we may also use nonessential cookies to improve user experience and analyze website traffic. By clicking "Accept," you agree to our website's cookie use as described in our Cookie Policy and Privacy Policy. You can change your cookie settings at any time by clicking "Preferences."

The next transformation starts with the status of 1 and is then updated to 2. This can be repeated for

every additional transformation.

## Data lineage

<!-- page 7 -->
Data lineage can be super relevant for architectures like the data vault architecture or when troubleshooting. The data vault architecture is a data warehouse that large organizations use when representing the same process across multiple systems, which adds data lineage requirements. Using the pipeline name and load\_id provided out of the box by dlt , you are able to identify the source and time of data.

You can save complete lineage info for a particular load\_id including a list of loaded files, error messages (if any), elapsed times, schema changes. This can be helpful, for example, when troubleshooting problems.

## Staging dataset

So far, we've been using the append write disposition in our example pipeline. This means that each time we run the pipeline, the data is appended to the existing tables. When you use the merge write disposition, dlt creates a staging database schema for staging data. This schema is named &lt;dataset\_name&gt;\_staging by default and contains the same tables as the destination schema. When you run the pipeline, the data from the staging tables is loaded into the destination tables in a single atomic transaction.

Let's illustrate this with an example. We change our pipeline to use the merge write disposition:

```
import dlt @dlt.resource(primary_key="id", write_disposition="merge") def users(): yield [ {'id': 1, 'name': 'Alice 2'}, {'id': 2, 'name': 'Bob 2'} ]
```

pipeline = dlt.pipeline(

)

pipeline\_name='quick\_start', destination='duckdb', dataset\_name='mydata' We use essential cookies to make our site work. With your consent, we may also use nonessential cookies to improve user experience and analyze website traffic. By clicking "Accept," you agree to our website's cookie use as described in our Cookie Policy and Privacy Policy. You can change your cookie settings at any time by clicking "Preferences."

load\_info = pipeline.run(users)

<!-- page 8 -->
Running this pipeline will create a schema in the destination database with the name mydata\_staging . If you inspect the tables in this schema, you will find the mydata\_staging.users table identical to the mydata.users table in the previous example.

Here is what the tables may look like after running the pipeline:

mydata\_staging.users

|   id | name    | _dlt_id        |     _dlt_load_id |
|------|---------|----------------|------------------|
|    1 | Alice 2 | wX3f5vn801W16A | 2345672350.98417 |
|    2 | Bob 2   | rX8ybgTeEmAmmA | 2345672350.98417 |

## mydata.users

|   id | name    | _dlt_id        |     _dlt_load_id |
|------|---------|----------------|------------------|
|    1 | Alice 2 | wX3f5vn801W16A | 2345672350.98417 |
|    2 | Bob 2   | rX8ybgTeEmAmmA | 2345672350.98417 |
|    3 | Charlie | h8lehZEvT3fASQ | 1234563456.12345 |

Notice that the mydata.users table now contains the data from both the previous pipeline run and the current one.

Dev mode (versioned) datasets

When you set the dev\_mode argument to True in the dlt.pipeline call, dlt creates a versioned dataset. This means that each time you run the pipeline, the data is loaded into a new dataset (a new database schema). The dataset name is the same as the dataset\_name you provided in the pipeline We use essential cookies to make our site work. With your consent, we may also use nonessential cookies to improve user experience and analyze website traffic. By clicking "Accept," you agree to our website's cookie use as described in our Cookie Policy and Privacy Policy. You can change your cookie settings at any time by clicking "Preferences."

definition with a datetime-based suffix.

We modify our pipeline to use the dev\_mode option to see how this works:

<!-- page 9 -->
```
import dlt data = [ {'id': 1, 'name': 'Alice'}, {'id': 2, 'name': 'Bob'} ] pipeline = dlt.pipeline( pipeline_name='quick_start', destination='duckdb', dataset_name='mydata', dev_mode=True # <-- add this line ) load_info = pipeline.run(data, table_name="users")
```

Every time you run this pipeline, a new schema will be created in the destination database with a datetime-based suffix. The data will be loaded into tables in this schema. For example, the first time you run the pipeline, the schema will be named mydata\_20230912064403 , the second time it will be named mydata\_20230912064407 , and so on.

## dlt's internal tables

dlt automatically creates internal tables in the destination schema to track pipeline runs, support incremental loading, and manage schema versions. These tables use the \_dlt\_ prefix.

## \_dlt\_loads: Load history tracking

This table records each pipeline run. Every time you execute a pipeline, a new row is added to this table with a unique load\_id . This table tracks which loads have been completed and supports

chaining of transformations.

Column name Type Description load\_id STRING Unique identifier for the load job We use essential cookies to make our site work. With your consent, we may also use nonessential cookies to improve user experience and analyze website traffic. By clicking "Accept," you agree to our website's cookie use as described in our Cookie Policy and Privacy Policy. You can change your cookie settings at any time by clicking "Preferences."

schema\_name STRING

Name of the schema used during the load Only rows with status = 0 are considered complete. Other values represent incomplete or interrupted loads. The status column can also be used to coordinate multi-step transformations.

<!-- page 10 -->
| Column name         | Type      | Description                          |
|---------------------|-----------|--------------------------------------|
| schema_version_hash | STRING    | Hash of the schema version           |
| status              | INTEGER   | Load status. Value 0 means completed |
| inserted_at         | TIMESTAMP | When the load was recorded           |

## \_dlt\_pipeline\_state: Pipeline state and checkpoints

This table stores the internal state of the pipeline for each run. This state enables incremental loading and allows the pipeline to resume from where it left off if a previous run was interrupted.

| Column name    | Type           | Description                                    |
|----------------|----------------|------------------------------------------------|
| version        | INTEGER        | Version of this state entry                    |
| engine_version | INTEGER        | Version of the dlt engine used                 |
| pipeline_name  | STRING         | Name of the pipeline                           |
| state          | STRING or BLOB | Serialized Python dictionary of pipeline state |
| created_at     | TIMESTAMP      | When this state entry was created              |

version\_hash STRING Hash to detect changes in the state \_dlt\_load\_id STRING Reference to related load in \_dlt\_loads We use essential cookies to make our site work. With your consent, we may also use nonessential cookies to improve user experience and analyze website traffic. By clicking "Accept," you agree to our website's cookie use as described in our Cookie Policy and Privacy Policy. You can change your cookie settings at any time by clicking "Preferences."

\_dlt\_id STRING

Unique identifier for the pipeline state row

The state column contains a serialized Python dictionary that includes:

<!-- page 11 -->
- Incremental progress (e.g. last item or timestamp processed).
- Checkpoints for transformations.
- Source-specific metadata and settings.

This allows dlt to resume interrupted pipelines, avoid reloading already processed data, and ensure pipelines are idempotent and efficient.

The version\_hash is recalculated on each update. dlt uses this table to implement last-value incremental loading. If a run fails or stops, this table ensures the next run picks up from the correct checkpoint.

## \_dlt\_version: Schema version tracking

This table tracks the history of all schema versions used by the pipeline. Every time dlt updates the schema. For example, when new columns or tables are added, a new entry is written to this table.

| Column name    | Type      | Description                                 |
|----------------|-----------|---------------------------------------------|
| version        | INTEGER   | Numeric version of the schema               |
| engine_version | INTEGER   | Version of the dlt engine used              |
| inserted_at    | TIMESTAMP | Time the schema version entry was created   |
| schema_name    | STRING    | Name of the schema                          |
| version_hash   | STRING    | Unique hash representing the schema content |

schema STRING or JSON Full schema in JSON format

By keeping previous schema definitions, \_dlt\_version ensures that: Older data remains readable We use essential cookies to make our site work. With your consent, we may also use nonessential cookies to improve user experience and analyze website traffic. By clicking "Accept," you agree to our website's cookie use as described in our Cookie Policy and Privacy Policy. You can change your cookie settings at any time by clicking "Preferences."

New data uses updated schema rules

Backward compatibility is maintained This table also supports troubleshooting and compatibility checks. It lets you track which schema and engine version were used for any load. This helps with debugging and ensures safe evolution of your data model.

<!-- page 12 -->
## Loading data into existing tables not created by dlt

You can also load data from dlt into tables that already exist in the destination dataset and were not created by dlt . There are a few things to keep in mind when doing this: If you load data into a table that exists but does not contain any data, in most cases, your load will succeed without problems. dlt will create the needed columns and insert the incoming data. dlt will only be aware of columns that exist on the discovered or provided internal schema, so if you have columns in your destination that are not anticipated by dlt , they will remain in the destination but stay unknown to dlt . This generally will not be a problem. If your destination table already exists and contains columns that have the same name as columns discovered by dlt but do not have matching datatypes, your load will fail, and you will have to fix the column on the destination table first, or change the column name in your incoming data to something else to avoid a collision. If your destination table exists and already contains data, your load might also initially fail, since dlt creates special non-nullable columns that contain required mandatory metadata. Some databases will not allow you to create non-nullable columns on tables that have data, since the initial value for these columns of the existing rows cannot be inferred. You will have to manually create these columns with the correct type on your existing tables and make them nullable , then fill in values for the existing rows. Some databases may allow you to create a new column that is non-nullable and take a default value for existing rows in the same command. The columns you will need to create are: name type We use essential cookies to make our site work. With your consent, we may also use nonessential cookies to improve user experience and analyze website traffic. By clicking "Accept," you agree to our website's cookie use as described in our Cookie Policy and

Privacy Policy. You can change your cookie settings at any time by clicking "Preferences."

\_dlt\_load\_id text/string/varchar

\_dlt\_id text/string/varchar For nested tables, you may also need to create:

<!-- page 13 -->
| name           | type                |
|----------------|---------------------|
| _dlt_parent_id | text/string/varchar |
| _dlt_root_id   | text/string/varchar |

We use essential cookies to make our site work. With your consent, we may also use nonessential cookies to improve user experience and analyze website traffic. By clicking "Accept," you agree to our website's cookie use as described in our Cookie Policy and Privacy Policy. You can change your cookie settings at any time by clicking "Preferences."
