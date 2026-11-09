# SQLFluff 4.5.0 — rules used by this project

Source: rule docstrings and default configuration of SQLFluff 4.5.0 (the rule reference at
https://docs.sqlfluff.com/en/stable/reference/rules/ is generated from these docstrings).
Files: https://github.com/sqlfluff/sqlfluff/tree/4.5.0/src/sqlfluff/rules and
https://github.com/sqlfluff/sqlfluff/blob/4.5.0/src/sqlfluff/core/default_config.cfg
Accessed 2026-11-09. License: MIT (see _licencas/sqlfluff-MIT.md). Only the rules the project
configures are kept: CP01, CP03, CP04, CP05, LT02, ST05, CV11, AM04.

## CP01 — capitalisation.keywords

Config keywords: capitalisation_policy, ignore_words, ignore_words_regex

Inconsistent capitalisation of keywords.

**Anti-pattern**

In this example, ``select`` is in lower-case whereas ``FROM`` is in upper-case.

.. code-block:: sql

    select
        a
    FROM foo

**Best practice**

Make all keywords either in upper-case or in lower-case.

.. code-block:: sql

    SELECT
        a
    FROM foo

    -- Also good

    select
        a
    from foo

## CP03 — capitalisation.functions

Config keywords: extended_capitalisation_policy, ignore_words, ignore_words_regex

Inconsistent capitalisation of function names.

.. note::
   This rule is disabled for ClickHouse because its function names are
   case-sensitive.

**Anti-pattern**

In this example, the two ``SUM`` functions don't have the same capitalisation.

.. code-block:: sql

    SELECT
        sum(a) AS aa,
        SUM(b) AS bb
    FROM foo

**Best practice**

Make the case consistent.

.. code-block:: sql

    SELECT
        sum(a) AS aa,
        sum(b) AS bb
    FROM foo

## CP04 — capitalisation.literals

Inconsistent capitalisation of boolean/null literal.

**Anti-pattern**

In this example, ``null`` and ``false`` are in lower-case whereas ``TRUE`` is in
upper-case.

.. code-block:: sql

    select
        a,
        null,
        TRUE,
        false
    from foo

**Best practice**

Ensure all literal ``null``/``true``/``false`` literals are consistently
upper or lower case

.. code-block:: sql

    select
        a,
        NULL,
        TRUE,
        FALSE
    from foo

    -- Also good

    select
        a,
        null,
        true,
        false
    from foo

## CP05 — capitalisation.types

Config keywords: extended_capitalisation_policy, ignore_words, ignore_words_regex

Inconsistent capitalisation of datatypes.

**Anti-pattern**

In this example, ``int`` and ``unsigned`` are in lower-case whereas
``VARCHAR`` is in upper-case.

.. code-block:: sql

    CREATE TABLE t (
        a int unsigned,
        b VARCHAR(15)
    );

**Best practice**

Ensure all datatypes are consistently upper or lower case

.. code-block:: sql

    CREATE TABLE t (
        a INT UNSIGNED,
        b VARCHAR(15)
    );

## LT02 — layout.indent

Incorrect Indentation.

**Anti-pattern**

The ``•`` character represents a space and the ``→`` character represents a tab.
In this example, the third line contains five spaces instead of four and
the second line contains two spaces and one tab.

.. code-block:: sql
   :force:

    SELECT
    ••→a,
    •••••b
    FROM foo


**Best practice**

Change the indentation to use a multiple of four spaces. This example also
assumes that the ``indent_unit`` config value is set to ``space``. If it
had instead been set to ``tab``, then the indents would be tabs instead.

.. code-block:: sql
   :force:

    SELECT
    ••••a,
    ••••b
    FROM foo

## ST05 — structure.subquery

Config keywords: forbid_subquery_in

Join/From clauses should not contain subqueries. Use CTEs instead.

By default this rule is configured to allow subqueries within ``FROM``
clauses but not within ``JOIN`` clauses. If you prefer a stricter lint
then this is configurable.

.. note::
   Some dialects don't allow CTEs, and for those dialects
   this rule makes no sense and should be disabled.

**Anti-pattern**

.. code-block:: sql

    select
        a.x, a.y, b.z
    from a
    join (
        select x, z from b
    ) using(x)


**Best practice**

.. code-block:: sql

    with c as (
        select x, z from b
    )
    select
        a.x, a.y, c.z
    from a
    join c using(x)

## CV11 — convention.casting_style

Config keywords: preferred_type_casting_style

Enforce consistent type casting style.

.. note::
    This is only compatible with 2-arguments CONVERT as
    some dialects allow an optional 3rd argument e.g TSQL,
    which cannot be rewritten into CAST.
    This rule is disabled by default for Teradata because it supports different
    type casting apart from CONVERT and ::
    e.g DATE '2007-01-01', '9999-12-31' (DATE).

.. note::
    MySQL and the dialects that inherit it (MariaDB, Doris, StarRocks) take
    ``CONVERT(expr, type)``, the opposite way round from the
    ``CONVERT(type, expr)`` in T-SQL. The rule handles this dialect-specific
    order appropriately when converting between styles.
    ``CONVERT(expr USING transcoding_name)`` is character set transcoding,
    not a type cast, and is left untouched.

**Anti-pattern**

Using mixture of CONVERT, :: and CAST when ``preferred_type_casting_style``
config is set to ``consistent`` (default).

.. code-block:: sql

    SELECT
        CONVERT(int, 1) AS bar,
        100::int::text,
        CAST(10 AS text) AS coo
    FROM foo;

**Best practice**

Use consistent type casting style.

.. code-block:: sql

    SELECT
        CAST(1 AS int) AS bar,
        CAST(CAST(100 AS int) AS text),
        CAST(10 AS text) AS coo
    FROM foo;

## AM04 — ambiguous.column_count

Query produces an unknown number of result columns.

**Anti-pattern**

Querying all columns using ``*`` produces a query result where the number
or ordering of columns changes if the upstream table's schema changes.
This should generally be avoided because it can cause slow performance,
cause important schema changes to go undetected, or break production code.
For example:

* If a query does ``SELECT t.*`` and is expected to return columns ``a``, ``b``,
  and ``c``, the actual columns returned will be wrong/different if columns
  are added to or deleted from the input table.
* ``UNION`` and ``DIFFERENCE`` clauses require the inputs have the same number
  of columns (and compatible types).
* ``JOIN`` queries may break due to new column name conflicts, e.g. the
  query references a column ``c`` which initially existed in only one input
  table but a column of the same name is added to another table.
* ``CREATE TABLE (<<column schema>>) AS SELECT *``


.. code-block:: sql

    WITH cte AS (
        SELECT * FROM foo
    )

    SELECT * FROM cte
    UNION
    SELECT a, b FROM t

**Best practice**

Somewhere along the "path" to the source data, specify columns explicitly.

.. code-block:: sql

    WITH cte AS (
        SELECT * FROM foo
    )

    SELECT a, b FROM cte
    UNION
    SELECT a, b FROM t

## Default configuration of these rules (default_config.cfg)

```ini
[sqlfluff:indentation]
# See https://docs.sqlfluff.com/en/stable/perma/indent_locations.html
indent_unit = space
tab_space_size = 4
indented_joins = False
indented_ctes = False
indented_using_on = True
indented_using_on_newline = False
indented_on_contents = True
indented_then = True
indented_then_contents = True
implicit_indents = forbid
template_blocks_indent = True
# This is a comma separated list of elements to skip
# indentation edits to.
skip_indentation_in = script_content
# When implicit_indents = require, this comma separated list of
# elements will be excluded from enforcing implicit indents.
# e.g. "case_expression" keeps CASE/WHEN on separate lines
# while other clauses (like WHERE) are still collapsed.
skip_implicit_indents_in = case_expression
# If comments are found at the end of long lines, we default to moving
# them to the line _before_ their current location as the convention is
# that a comment precedes the line it describes. However if you prefer
# comments moved _after_, this configuration setting can be set to "after".
trailing_comments = before
# When a long list (e.g. of columns or arguments) is split across
# lines, the default puts each element on its own line. Set this to
# "fill" to put as many elements on each line as fit in the line length.
list_wrapping = one_per_line
# To exclude comment lines from indentation entirely set this to "True".
ignore_comment_lines = False

# Layout configuration
# See https://docs.sqlfluff.com/en/stable/perma/layout_spacing.html

[sqlfluff:templater:jinja]
apply_dbt_builtins = True

# Some rules can be configured directly from the config common to other rules

[sqlfluff:rules:capitalisation.keywords]
# Keywords
capitalisation_policy = consistent
# Comma separated list of words to ignore for this rule
ignore_words = None
ignore_words_regex = None

[sqlfluff:rules:capitalisation.functions]
# Function names
extended_capitalisation_policy = consistent
# Comma separated list of words to ignore for this rule
ignore_words = None
ignore_words_regex = None

[sqlfluff:rules:capitalisation.literals]
# Null & Boolean Literals
capitalisation_policy = consistent
# Comma separated list of words to ignore for this rule
ignore_words = None
ignore_words_regex = None

[sqlfluff:rules:capitalisation.types]
# Data Types
extended_capitalisation_policy = consistent
# Comma separated list of words to ignore for this rule
ignore_words = None
ignore_words_regex = None

[sqlfluff:rules:convention.casting_style]
# SQL type casting
preferred_type_casting_style = consistent

[sqlfluff:rules:structure.subquery]
# By default, allow subqueries in from clauses, but not join clauses
forbid_subquery_in = join

```
