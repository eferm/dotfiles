# Technical Patterns Reference

This document contains modeling, pipeline, and design patterns for analytics engineering work.
Read this file when producing tactical specs, technical guidance, or scoping data warehouse changes.

All patterns assume BigQuery as the warehouse and dbt as the modeling layer.

---

## Table of Contents

1. [Source Integration Patterns](#source-integration-patterns)
2. [Historization Patterns](#historization-patterns)
3. [Deduplication Patterns](#deduplication-patterns)
4. [Dimensional Modeling Patterns](#dimensional-modeling-patterns)
5. [Metric Definition Patterns](#metric-definition-patterns)
6. [Testing Patterns](#testing-patterns)
7. [Pipeline Design Patterns](#pipeline-design-patterns)
8. [The Spec Template](#the-spec-template)

---

## Source Integration Patterns

Every new data source entering the warehouse must be classified and handled accordingly.

### Classification: Entity vs. Event

**Entity (mutable, has a primary key).** Represents a business object: a user, a product, an order,
a company. The source system mutates these records in place (updates, deletes). Examples: customers
table in a CRM, products table in an ERP.

**Event (immutable, has a timestamp).** Represents a business activity: a page view, a transaction,
a support ticket created. These are append-only in nature. Examples: web analytics events, payment
transactions, audit logs.

This classification determines everything downstream: ingestion strategy, historization approach,
testing strategy, and how downstream models consume the data.

### Ingestion Decision Tree

```
New data source arrives
├── Is it a SaaS tool with a Fivetran connector?
│   ├── Is it Netsuite or a CSV upload? → Use Fivetran
│   └── Otherwise → Prefer Airbyte (check connector quality first)
├── Is it a database (Postgres, MySQL, etc.)?
│   ├── Does it support CDC (logical replication)? → Use Airbyte with CDC
│   └── No CDC? → Use Airbyte with full refresh or cursor-based incremental
├── Is it a spreadsheet or CSV from a human?
│   ├── One-time? → Upload to GCS, load to BigQuery, model in dbt
│   └── Recurring? → Set up Fivetran CSV connector or a Google Sheet → BigQuery flow
├── Is it an API with no existing connector?
│   └── Build a Modal script to extract and load to BigQuery on a schedule
└── Is it a file drop (SFTP, S3, email)?
    └── Build a Modal script or Cloud Function to detect and load
```

### Questions to Answer for Every New Source

These come from hard-won experience. Don't skip them.

1. **What is the grain of each table?** One row = one what?
2. **What are the primary keys?** Are they stable? Are they actually unique?
3. **Does the source support CDC?** If not, how do we detect changes?
4. **What column types are used?** Do they all have BigQuery analogs? Watch for: PostGIS types,
   arrays-of-arrays, custom enums, timezone-naive timestamps.
5. **What happens when schema changes?** New columns, removed columns, type changes. Does Airbyte/
   Fivetran handle this gracefully, or will it break?
6. **How do we detect deletes?** Soft deletes with a flag? Hard deletes that just disappear?
   Do we care about tracking deletions?
7. **What is the data volume?** How much for the initial load? How much incremental per day?
8. **What is the latency requirement?** Hourly? Daily? Near-real-time? Default to daily unless
   there's a strong business reason for faster.
9. **Is there PII?** What needs to be masked, hashed, or excluded?
10. **Who owns this source?** When it breaks (and it will), who do we talk to?

### The Staging Layer in dbt

All raw data from Airbyte/Fivetran lands in source schemas in BigQuery. The first dbt layer
(staging) performs only:
- Renaming columns to match conventions
- Casting types consistently (especially timestamps to UTC)
- Basic deduplication if the source produces duplicates
- Filtering out test/internal records if obvious

No business logic in staging. That comes in intermediate and marts layers.

---

## Historization Patterns

How do we track changes to entity data over time?

### Pattern 1: Daily Full Snapshots (preferred default)

Take a complete snapshot of the entity table every day. Each snapshot is a partition.

```sql
-- In dbt, this is a snapshot or a partitioned incremental model
-- Result: one partition per day, each containing the full state of the entity

-- To query current state:
SELECT * FROM entity WHERE _snapshot_date = CURRENT_DATE()

-- To query state at any point in time:
SELECT * FROM entity WHERE _snapshot_date = '2025-06-15'

-- To find what changed:
SELECT * FROM entity WHERE _snapshot_date = '2025-06-16'
EXCEPT DISTINCT
SELECT * FROM entity WHERE _snapshot_date = '2025-06-15'
```

**When to use:** Default for any entity table that is small-to-medium (under ~10M rows per snapshot).
Storage is cheap. Simplicity and explainability are expensive.

**Tradeoffs:** Duplicates a lot of data. For very large dimensions, consider Pattern 2 or 3.

### Pattern 2: dbt Snapshots (SCD Type 2 via dbt)

dbt's built-in snapshot functionality tracks changes using `dbt_valid_from` and `dbt_valid_to`
columns. It uses either a `check` strategy (compares column values) or a `timestamp` strategy
(uses an `updated_at` column).

```sql
-- dbt snapshot config
{% snapshot customers_snapshot %}
{{
    config(
      target_schema='snapshots',
      unique_key='customer_id',
      strategy='timestamp',
      updated_at='updated_at',
    )
}}
SELECT * FROM {{ source('crm', 'customers') }}
{% endsnapshot %}
```

**When to use:** When full daily snapshots are too expensive (very large tables) or when you need
row-level change tracking with valid-from/valid-to semantics.

**Tradeoffs:** More complex to query. Requires understanding SCD Type 2 semantics. The `check`
strategy can miss changes if it doesn't check all columns. The `timestamp` strategy requires a
reliable `updated_at` column.

### Pattern 3: Append-Only Event Log + Latest View

If the source provides a change stream (CDC, event sourcing, audit log), store every change event
as an immutable append-only record. Derive the current state with a latest-value query.

```sql
-- Raw change events (append-only)
-- Each row: entity_id, field_changed, old_value, new_value, changed_at

-- Current state derived as a view:
SELECT
  entity_id,
  -- Use LAST_VALUE or array aggregation to get current state
  ARRAY_AGG(STRUCT(field, new_value) ORDER BY changed_at DESC LIMIT 1)[OFFSET(0)].*
FROM change_events
GROUP BY entity_id
```

**When to use:** When a change stream is available and you need both current state and full
change history. Common with CDC from Postgres via Airbyte.

**Tradeoffs:** Complex to query for current state. Great for auditing and time-travel.

### Pattern 4: Nested History Columns

Store historical values as STRUCT or ARRAY columns within the entity record.

```sql
-- Example: customer with address history
SELECT
  customer_id,
  current_address,
  address_history  -- ARRAY<STRUCT<address STRING, effective_from DATE, effective_to DATE>>
FROM customers
```

**When to use:** When you need history for specific attributes but don't want to change the grain
of the table (unlike SCD Type 2). Works well in BigQuery which handles nested types natively.

**Tradeoffs:** Harder to JOIN on historical values. Query syntax for nested types is less intuitive.

### Choosing a Historization Pattern

```
Is the table small enough for daily full snapshots? (<10M rows)
├── Yes → Pattern 1 (daily full snapshots). Done.
└── No
    ├── Does the source provide CDC/change stream?
    │   ├── Yes → Pattern 3 (append-only event log + latest view)
    │   └── No → Pattern 2 (dbt snapshots with timestamp strategy)
    └── Do you only need history for a few specific columns?
        └── Yes → Consider Pattern 4 (nested history columns)
```

---

## Deduplication Patterns

Duplicates are inevitable. They come from: CDC replay, at-least-once delivery in event streams,
Airbyte re-syncs, source systems that don't enforce uniqueness, and human error.

### The Three Questions

1. **What is the expected grain?** (One row per what?)
2. **What is the natural primary key?** (What combination of columns should be unique?)
3. **Are the duplicates exact or partial?** (Same PK, different values = conflict resolution needed)

### Pattern: Dedup in Staging with ROW_NUMBER

The workhorse pattern. Use `ROW_NUMBER()` to keep the most recent or most complete record.

```sql
WITH ranked AS (
  SELECT
    *,
    ROW_NUMBER() OVER (
      PARTITION BY primary_key_column
      ORDER BY _airbyte_extracted_at DESC  -- or updated_at, or _fivetran_synced
    ) AS row_num
  FROM {{ source('raw', 'table') }}
)
SELECT * FROM ranked WHERE row_num = 1
```

**Tie-breaking column choice matters.** Prefer, in order:
1. `updated_at` from the source (if reliable)
2. `_airbyte_extracted_at` or `_fivetran_synced` (ingestion timestamp)
3. If still tied, add a secondary sort column

### Pattern: Dedup Events by Event ID

For event streams where each event has a unique ID but duplicates can arrive:

```sql
SELECT DISTINCT event_id, * EXCEPT(event_id)
FROM {{ source('events', 'raw_events') }}
```

Or if `DISTINCT` is too expensive on wide tables, use the ROW_NUMBER pattern keyed on `event_id`.

### Pattern: Merge-Dedup for Incremental Models

In dbt incremental models, use a merge key to upsert and deduplicate in one step:

```sql
{{
  config(
    materialized='incremental',
    unique_key='primary_key_column',
    merge_update_columns=['col1', 'col2', 'updated_at']
  )
}}
```

### When Duplicates Signal a Deeper Problem

If you're deduplicating the same table repeatedly and the volume of duplicates is growing, the
problem is upstream. Investigate: Is CDC replaying on restart? Is Airbyte doing full re-syncs
unexpectedly? Is the source system creating duplicate records? Fix the cause, not just the symptom.

---

## Dimensional Modeling Patterns

Following Kimball's methodology as the team's agreed convention.

### Facts and Dimensions

**Fact tables** record business events at a specific grain. Each row is a measurement.
- Order line items, transactions, page views, support tickets
- Contain foreign keys to dimensions, and numeric measures (amount, quantity, duration)
- Usually partitioned by date

**Dimension tables** provide context for facts. Each row is an entity.
- Customers, products, employees, locations, dates
- Contain descriptive attributes (name, category, region)
- Relatively slowly changing

### Naming Conventions (enforce in dbt)

```
stg_<source>__<table>          -- staging layer (light cleaning only)
int_<domain>__<description>    -- intermediate transformations
fct_<verb/event>               -- fact tables (fct_orders, fct_page_views)
dim_<entity>                   -- dimension tables (dim_customers, dim_products)
rpt_<domain>__<description>    -- report-level aggregations for Metabase
metrics_<metric_name>          -- metric definitions (if using dbt metrics)
```

### The Date Dimension

Always have one. It costs nothing and saves endless `DATE_TRUNC` / `EXTRACT` gymnastics.

```sql
-- dim_dates should include:
-- date_key, full_date, day_of_week, day_name, week_start, month_start,
-- quarter_start, year, fiscal_quarter, fiscal_year, is_weekend, is_holiday
```

### Handling NULLs in Joins

When a fact record has a NULL foreign key (e.g., an order with no assigned sales rep), the
dimension should have a "Not Applicable" or "Unknown" row that the JOIN resolves to. This
prevents silent row loss from inner joins and makes reports consistent.

```sql
-- In dim_customers:
-- customer_id = -1, customer_name = 'Unknown', ...
-- All NULLs in the fact table's customer_id get coalesced to -1 before joining
```

### Consistent Grain Documentation

Every model in dbt should have a description that states its grain:

```yaml
models:
  - name: fct_orders
    description: "One row per order line item. Grain: order_id + product_id."
```

---

## Metric Definition Patterns

### The Metric Contract

Every business metric must have:
1. **Name**: Clear, unambiguous (e.g., "Monthly Active Users," not "MAU" without definition)
2. **Definition**: Precise SQL-level logic. What counts, what doesn't, what's excluded.
3. **Grain**: What is being counted? Users? Sessions? Transactions?
4. **Time grain**: Daily? Weekly? Monthly?
5. **Known caveats**: What inflates it? What deflates it? What's approximate?
6. **Owner**: Who is responsible for this definition?

### Time-Grain Selection

- **Daily**: Noisy (weekends, holidays). Good for operational monitoring.
- **Weekly**: Smooths out day-of-week effects. Good default for most business metrics.
- **Monthly**: Smooth but delayed — you wait 20 days to find out something broke on the 10th.

Pick the grain that balances signal-to-noise with actionability. Default to weekly.

### Net-New vs. Total vs. Active

These are different metrics. Be explicit:
- **Total users**: All users ever created. This number only goes up.
- **Active users**: Users who did [specific action] in [specific time window]. Define both.
- **Net-new users**: Users whose first [specific action] occurred in [specific time window].

The "counting users" problem: `COUNT(DISTINCT anonymous_id)` overcounts because one person
can have multiple anonymous IDs (cleared cookies, multiple devices, private browsing).
Document this limitation. Use authenticated user IDs wherever possible.

```sql
-- Net-new users by week
WITH first_events AS (
  SELECT
    user_id,
    MIN(event_date) AS first_event_date
  FROM fct_events
  GROUP BY user_id
)
SELECT
  DATE_TRUNC(first_event_date, WEEK) AS week,
  COUNT(*) AS new_users
FROM first_events
GROUP BY 1
```

---

## Testing Patterns

### Minimum Viable Tests for Every Model

Every dbt model should have at minimum:

1. **Primary key uniqueness**: `unique` test on the primary key
2. **Primary key not-null**: `not_null` test on the primary key
3. **Row count sanity**: A custom test that alerts if row count drops by >X% from the previous run
4. **Freshness**: Source freshness checks (dbt source freshness)

### Additional Tests by Model Type

**Staging models:**
- Accepted values for enum/status columns
- Not-null on critical business columns

**Fact models:**
- Referential integrity: foreign keys exist in their dimension tables
- Numeric range checks (amounts > 0, quantities >= 0)
- Date sanity (event_date not in the future, not before company founding)

**Dimension models:**
- Uniqueness of the natural key
- Completeness of the "Unknown" placeholder row
- No orphaned foreign keys from fact tables

### When Tests Fail

Pipeline jobs must not fail silently. When a test fails:
1. The pipeline stops (or the model is flagged, depending on severity)
2. An alert fires (Slack, email)
3. The data team investigates before downstream consumers are affected
4. The resolution is documented

---

## Pipeline Design Patterns

### The Layer Cake

```
Sources (Airbyte, Fivetran) → Raw schemas in BigQuery
    ↓
Staging (dbt) → stg_ models: rename, cast, dedup, filter
    ↓
Intermediate (dbt) → int_ models: joins, business logic building blocks
    ↓
Marts (dbt) → fct_ and dim_ models: the dimensional model
    ↓
Reports (dbt) → rpt_ models: pre-aggregated for Metabase dashboards
    ↓
Metabase → Dashboards consuming rpt_ or marts models
```

### Incremental vs. Full Refresh

**Default to full refresh (table materialization)** unless the table is too large. In BigQuery,
full refreshes of tables up to ~100M rows are usually fast enough. This is the safest option:
no accumulated state, no drift, fully reproducible.

**Use incremental materialization** when:
- The table is very large (>100M rows or slow to rebuild)
- The source provides a reliable watermark column (event_timestamp, updated_at)
- You schedule periodic full refreshes (weekly or monthly) to reset accumulated drift

**Use ephemeral materialization** for lightweight intermediate transformations that don't need
to be persisted.

### One DAG

All dbt models live in one DAG. No separate orchestration for different domains. This ensures:
- Dependencies are explicit and visible
- There's no hidden ordering assumption
- `dbt build` runs everything in the right order
- Lineage is traceable end-to-end

---

## The Spec Template

Use this template when scoping any new data work. Fill in every section. If a section doesn't
apply, write "N/A" and explain why.

```markdown
# Spec: [Name of the Work]

## Business Context
- What decision does this enable?
- Who is the decision-maker?
- What does success look like 30 days after delivery?

## Current State
- What exists today? (spreadsheet, manual process, nothing)
- What's broken about the current state?

## Proposed Design
- What is the grain? (one row = one what?)
- What is the primary key?
- Entity or event?
- Source system(s) and ingestion method (Airbyte/Fivetran/Modal/manual)
- Historization strategy (snapshots/CDC/append-only/none)
- Deduplication strategy
- dbt layer placement (staging/intermediate/marts/reports)

## Schema
- Column definitions with types and descriptions
- Known type-mapping issues

## Testing Plan
- Primary key tests
- Business rule assertions
- Row count / freshness checks

## Blast Radius
- What downstream models are affected?
- What dashboards need to be updated?
- What stakeholders need to be notified?

## Tech Debt Acknowledged
- What shortcuts are we taking and why?
- When will we revisit them?

## Open Questions
- What do we still need to resolve?
- Who can answer these questions?
```
