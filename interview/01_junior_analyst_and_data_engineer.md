# 🎓 SQL Interview Guide — Tier 1: Junior Data Analyst & Engineer (Foundations)

> **Focus Areas**: ANSI Logical Execution Order, Three-Valued Logic & NULL Handling, SARGability, JOIN Mechanics (INNER, LEFT, FULL, CROSS), Aggregations & Grouping, Subqueries.
> **Target Audience**: Data Analysts, BI Developers, Junior Data Engineers

---

### Q1.1: SELECT, WHERE & ORDER BY Fundamentals (Query Basics)

**Question & Concept Overview:**  
The foundation of T-SQL — retrieving, filtering, and ordering data. Even expert engineers return to these fundamentals for readability-first query design, especially in Medallion Silver-layer validation queries.

**SQL Implementation & Query Plan:**
```sql
-- EU BFSI: Query transaction data from Silver layer
-- Always use schema prefix (dbo.) — avoids ambiguity in multi-schema databases

SELECT TOP 100
    t.transaction_id,
    t.amount_eur,
    t.currency,
    t.status,
    t.transaction_date,
    c.customer_name,
    c.country_code
FROM dbo.fact_transactions t
INNER JOIN dbo.dim_customers c ON t.customer_id = c.customer_id
WHERE
    t.transaction_date >= DATEADD(DAY, -30, GETUTCDATE())  -- last 30 days
    AND t.status IN ('SETTLED', 'REVERSED')
    AND t.amount_eur > 0
    AND t.is_flagged = 0
ORDER BY
    t.transaction_date DESC,
    t.amount_eur DESC;

-- Count by status with percentage
SELECT
    status,
    COUNT(*) AS txn_count,
    SUM(amount_eur) AS total_eur,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS pct_of_total
FROM dbo.fact_transactions
WHERE transaction_date >= '2024-01-01'
GROUP BY status
ORDER BY txn_count DESC;
```

**Enterprise Data Scenario:**  
Exploratory queries on the Azure SQL Silver layer transaction table for EU BFSI daily reconciliation reporting, used as basis for Power BI Direct Query semantic model views.

**Optimizer Invariants & Performance Traps:**
- Always use schema prefix (dbo.tablename) — prevents unintended resolution to temp tables
- TOP 100 for exploration — never run SELECT * on production tables without WHERE + TOP
- GETUTCDATE() not GETDATE() for EU compliance — all timestamps should be stored in UTC
- Column aliasing (AS) improves report readability — match column names to Power BI field names

---

### Q1.2: Aggregate Functions & GROUP BY (Aggregation)

**Question & Concept Overview:**  
GROUP BY with aggregate functions (SUM, COUNT, AVG, MIN, MAX) is the workhorse for financial KPI calculation — daily volumes, currency exposure, and transaction counts for BFSI reporting.

**SQL Implementation & Query Plan:**
```sql
-- Daily transaction volume by currency — Gold layer metric
SELECT
    CAST(transaction_date AS DATE) AS report_date,
    currency,
    COUNT(*) AS txn_count,
    SUM(amount_eur) AS total_volume_eur,
    AVG(amount_eur) AS avg_txn_eur,
    MIN(amount_eur) AS min_txn_eur,
    MAX(amount_eur) AS max_txn_eur,
    SUM(CASE WHEN is_high_value = 1 THEN 1 ELSE 0 END) AS high_value_count,
    SUM(CASE WHEN status = 'REJECTED' THEN 1 ELSE 0 END) AS rejected_count
FROM dbo.fact_transactions
WHERE transaction_date BETWEEN '2024-01-01' AND '2024-01-31'
GROUP BY
    CAST(transaction_date AS DATE),
    currency
HAVING
    COUNT(*) > 10          -- exclude low-volume currency/date combos
    AND SUM(amount_eur) > 0
ORDER BY report_date, total_volume_eur DESC;

-- Cross-tab: settled vs rejected count per country
SELECT
    c.country_code,
    COUNT(*) AS total_txns,
    SUM(CASE WHEN t.status = 'SETTLED'  THEN 1 ELSE 0 END) AS settled,
    SUM(CASE WHEN t.status = 'REJECTED' THEN 1 ELSE 0 END) AS rejected,
    ROUND(
        SUM(CASE WHEN t.status = 'REJECTED' THEN 1.0 ELSE 0 END) / COUNT(*) * 100, 2
    ) AS rejection_rate_pct
FROM dbo.fact_transactions t
JOIN dbo.dim_customers c ON t.customer_id = c.customer_id
GROUP BY c.country_code
ORDER BY rejection_rate_pct DESC;
```

**Enterprise Data Scenario:**  
Computing daily EU BFSI transaction KPIs for Azure Synapse SQL dedicated pool, feeding Power BI Direct Query reports with pre-aggregated Gold layer metrics.

**Optimizer Invariants & Performance Traps:**
- HAVING filters AFTER aggregation — use WHERE for row-level filters, HAVING for group-level filters
- CASE WHEN inside SUM() is the T-SQL equivalent of COUNT(IF) — compute conditional counts efficiently
- GROUP BY all non-aggregated SELECT columns — SQL Server raises error if any column is omitted
- Store amounts in EUR at landing time — avoids FX rate dependency in reporting queries

---

### Q1.3: JOINs: INNER, LEFT, RIGHT, FULL (Joins)

**Question & Concept Overview:**  
Understanding join types and their behavior on NULLs and unmatched rows is fundamental for correct financial data enrichment. A wrong join type can silently drop transactions or inflate row counts.

**SQL Implementation & Query Plan:**
```sql
-- INNER JOIN: only matching records (used for enriched reporting)
SELECT
    t.transaction_id,
    t.amount_eur,
    c.customer_name,
    cp.counterparty_name
FROM dbo.fact_transactions t
INNER JOIN dbo.dim_customers c     ON t.customer_id = c.customer_id
INNER JOIN dbo.dim_counterparties cp ON t.counterparty_id = cp.counterparty_id
WHERE t.transaction_date = '2024-01-15';

-- LEFT JOIN: all transactions, customer info where available
-- NULL customer_name → orphaned transactions (data quality issue)
SELECT
    t.transaction_id,
    t.amount_eur,
    c.customer_name,
    CASE WHEN c.customer_id IS NULL THEN 'ORPHANED' ELSE 'MATCHED' END AS match_status
FROM dbo.fact_transactions t
LEFT JOIN dbo.dim_customers c ON t.customer_id = c.customer_id
WHERE t.transaction_date = '2024-01-15';

-- FULL OUTER JOIN: find mismatches in both directions (reconciliation)
SELECT
    COALESCE(s.transaction_id, t.transaction_id) AS txn_id,
    s.amount AS source_amount,
    t.amount_eur AS target_amount,
    CASE
        WHEN s.transaction_id IS NULL THEN 'TARGET_ONLY'
        WHEN t.transaction_id IS NULL THEN 'SOURCE_ONLY'
        ELSE 'MATCHED'
    END AS reconciliation_status
FROM dbo.source_transactions s
FULL OUTER JOIN dbo.fact_transactions t
    ON s.transaction_id = t.transaction_id
    AND s.transaction_date = t.transaction_date
WHERE s.transaction_id IS NULL OR t.transaction_id IS NULL;  -- show mismatches only
```

**Enterprise Data Scenario:**  
Daily reconciliation between EU payment gateway source system and the Azure SQL Silver table, using FULL OUTER JOIN to identify missing or extra records before close-of-business.

**Optimizer Invariants & Performance Traps:**
- INNER JOIN drops rows with no match — use LEFT JOIN for transactions, INNER for lookups you know are complete
- FULL OUTER JOIN is the reconciliation pattern — identifies records in source not in target and vice versa
- Always check for NULL in LEFT JOIN results — IS NULL on right table columns = unmatched rows
- COALESCE(a.col, b.col) in FULL OUTER JOIN provides unified key from either side

---

### Q1.4: CASE Expressions & NULL Handling (Expressions)

**Question & Concept Overview:**  
CASE expressions implement conditional logic directly in SQL, replacing complex application-layer branching. Proper NULL handling with ISNULL/COALESCE/NULLIF is critical for financial calculations where NULL ≠ 0.

**SQL Implementation & Query Plan:**
```sql
-- CASE WHEN: classify transactions by risk tier
SELECT
    transaction_id,
    amount_eur,
    currency,
    -- Simple CASE
    CASE status
        WHEN 'SETTLED'  THEN 'Complete'
        WHEN 'REJECTED' THEN 'Failed'
        WHEN 'PENDING'  THEN 'In Progress'
        ELSE 'Unknown'
    END AS status_label,

    -- Searched CASE: range-based classification
    CASE
        WHEN amount_eur >= 100000 THEN 'TIER_1_LARGE'
        WHEN amount_eur >= 10000  THEN 'TIER_2_MEDIUM'
        WHEN amount_eur >= 1000   THEN 'TIER_3_SMALL'
        ELSE                           'TIER_4_MICRO'
    END AS transaction_tier,

    -- AML flag: combined conditions
    CASE
        WHEN amount_eur > 10000 AND is_cross_border = 1 THEN 1
        WHEN amount_eur > 50000 THEN 1
        ELSE 0
    END AS aml_review_flag

FROM dbo.fact_transactions;

-- NULL handling — critical for financial accuracy
SELECT
    transaction_id,
    ISNULL(amount_eur, 0) AS amount_eur_safe,      -- replace NULL with 0
    COALESCE(fx_rate, 1.0) AS fx_rate_safe,        -- first non-NULL from list
    NULLIF(quantity, 0) AS qty_safe,                -- return NULL if 0 (avoids divide-by-zero)
    amount_eur / NULLIF(quantity, 0) AS unit_price, -- safe division
    ISNULL(customer_name, 'UNKNOWN') AS customer_display
FROM dbo.fact_transactions;
```

**Enterprise Data Scenario:**  
Classifying EU BFSI transactions by risk tier and AML flags in the Silver layer view, used as input to the compliance reporting stored procedure for the regulatory reporting dashboard.

**Optimizer Invariants & Performance Traps:**
- NULLIF(x, 0) returns NULL when x=0 — the standard pattern for safe division (amount / NULLIF(qty,0))
- COALESCE evaluates left-to-right and returns first non-NULL — more flexible than ISNULL (2-arg only)
- Nested CASE expressions are valid but reduce readability — prefer IIF() for simple binary conditions
- Searched CASE (WHEN condition THEN) is evaluated top-to-bottom — most restrictive condition first

---

### Q1.5: INSERT, UPDATE, DELETE & Transactions (DML)

**Question & Concept Overview:**  
Proper DML with explicit transaction control and error handling is foundational for data integrity. In financial systems, every write operation must be wrapped in a transaction to prevent partial updates.

**SQL Implementation & Query Plan:**
```sql
-- Explicit transaction: all-or-nothing batch insert
BEGIN TRANSACTION;
BEGIN TRY

    -- Insert new transactions to Silver
    INSERT INTO dbo.fact_transactions (
        transaction_id, amount_eur, currency, status, transaction_date,
        customer_id, is_high_value, _load_ts
    )
    SELECT
        src.transaction_id,
        src.amount * ISNULL(fx.rate, 1.0) AS amount_eur,
        src.currency,
        src.status,
        src.transaction_date,
        src.customer_id,
        CASE WHEN src.amount * ISNULL(fx.rate, 1.0) > 10000 THEN 1 ELSE 0 END,
        GETUTCDATE()
    FROM dbo.stage_transactions src
    LEFT JOIN dbo.dim_fx_rates fx
        ON fx.currency = src.currency AND fx.rate_date = src.transaction_date
    WHERE NOT EXISTS (
        SELECT 1 FROM dbo.fact_transactions t
        WHERE t.transaction_id = src.transaction_id  -- dedup check
    );

    DECLARE @inserted INT = @@ROWCOUNT;

    -- Update status for reversed transactions
    UPDATE t
    SET t.status = 'REVERSED',
        t.reversed_ts = GETUTCDATE(),
        t.reversal_reason = s.reason
    FROM dbo.fact_transactions t
    INNER JOIN dbo.stage_reversals s ON t.transaction_id = s.original_txn_id;

    DECLARE @updated INT = @@ROWCOUNT;

    COMMIT TRANSACTION;
    PRINT FORMATMESSAGE('Success: %d inserted, %d updated', @inserted, @updated);

END TRY
BEGIN CATCH
    ROLLBACK TRANSACTION;
    THROW;  -- re-raise to calling ADF pipeline activity
END CATCH;
```

**Enterprise Data Scenario:**  
Loading daily transaction batch from staging table to Silver fact table in Azure SQL, with duplicate detection and transaction rollback on any failure, ensuring 100% data consistency for EU BFSI compliance.

**Optimizer Invariants & Performance Traps:**
- Always use BEGIN TRANSACTION + COMMIT/ROLLBACK for multi-statement DML — guarantees atomicity
- NOT EXISTS dedup check prevents duplicate inserts on pipeline retry — essential for idempotency
- @@ROWCOUNT must be captured immediately after the statement — next statement resets it
- THROW re-raises the original error with full context — ADF pipeline receives the error for retry logic

---

### Q1.6: CREATE TABLE, ALTER TABLE & Indexes (DDL)

**Question & Concept Overview:**  
Proper table design with correct data types, constraints, and indexes is foundational for Azure SQL performance. Financial data tables require specific design choices for GDPR compliance, audit trails, and query performance.

**SQL Implementation & Query Plan:**
```sql
-- Create Silver transactions table with proper constraints
CREATE TABLE dbo.fact_transactions (
    -- Surrogate key (auto-increment for internal joins)
    txn_sk           BIGINT IDENTITY(1,1) NOT NULL,

    -- Business key (natural key from source system)
    transaction_id   NVARCHAR(50)   NOT NULL,

    -- Financial fields — use DECIMAL not FLOAT for money
    amount           DECIMAL(18, 4) NOT NULL,
    amount_eur       DECIMAL(18, 2) NOT NULL,
    fx_rate          DECIMAL(10, 6) NULL,
    currency         CHAR(3)        NOT NULL,

    -- Categorization
    status           NVARCHAR(20)   NOT NULL,
    transaction_type NVARCHAR(50)   NULL,

    -- Date/time — store as DATE/DATETIME2, not DATETIME (more precise, smaller)
    transaction_date DATE           NOT NULL,
    transaction_ts   DATETIME2(7)   NULL,

    -- Foreign keys
    customer_id      NVARCHAR(50)   NULL,
    counterparty_id  NVARCHAR(50)   NULL,

    -- Flags
    is_high_value    BIT            NOT NULL DEFAULT 0,
    is_flagged       BIT            NOT NULL DEFAULT 0,

    -- Audit columns (GDPR requirement)
    _source          NVARCHAR(100)  NOT NULL,
    _load_ts         DATETIME2      NOT NULL DEFAULT GETUTCDATE(),
    _modified_ts     DATETIME2      NOT NULL DEFAULT GETUTCDATE(),

    -- Constraints
    CONSTRAINT PK_fact_transactions PRIMARY KEY CLUSTERED (txn_sk),
    CONSTRAINT UQ_transaction_id UNIQUE (transaction_id),
    CONSTRAINT CK_amount_positive CHECK (amount > 0),
    CONSTRAINT CK_currency_format CHECK (currency LIKE '[A-Z][A-Z][A-Z]')
);

-- Indexes — covering index for most common query pattern
CREATE NONCLUSTERED INDEX IX_fact_transactions_date_currency
ON dbo.fact_transactions (transaction_date, currency)
INCLUDE (amount_eur, status, customer_id)  -- covering columns
WHERE is_flagged = 0;  -- filtered index — smaller, faster for non-flagged queries

-- Add a column (zero-downtime on Azure SQL with online rebuild)
ALTER TABLE dbo.fact_transactions
ADD counterparty_country CHAR(2) NULL;
```

**Enterprise Data Scenario:**  
Designing the Azure SQL Silver layer fact_transactions table for TCS EU BFSI, with proper decimal types for GDPR-compliant financial records and covering indexes that reduce query latency for Power BI reports by 70%.

**Optimizer Invariants & Performance Traps:**
- Use DECIMAL(18,2) not FLOAT/MONEY for financial amounts — avoids floating-point rounding errors
- DATETIME2(7) has 100ns precision vs DATETIME's 3ms — required for high-frequency trading audit logs
- Filtered indexes (WHERE is_flagged=0) are dramatically smaller than full indexes — query optimizer prefers them
- INCLUDE columns in non-clustered indexes avoid key lookups — critical for covering common SELECT patterns

---

### Q1.7: Stored Procedures & User-Defined Functions (Programmability)

**Question & Concept Overview:**  
Stored procedures encapsulate business logic, enable parameterized execution from ADF, and reduce network overhead. Scalar and table-valued functions enable reusable logic in complex reporting queries.

**SQL Implementation & Query Plan:**
```sql
-- Stored procedure: parameterized Silver load (called from ADF pipeline)
CREATE OR ALTER PROCEDURE dbo.usp_load_silver_transactions
    @batch_date    DATE,
    @source_system NVARCHAR(100),
    @debug         BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;  -- auto-rollback on error

    DECLARE @rows_inserted INT = 0;
    DECLARE @rows_updated  INT = 0;

    BEGIN TRANSACTION;

    -- Upsert pattern using MERGE
    MERGE dbo.fact_transactions AS tgt
    USING (
        SELECT transaction_id, amount_eur, currency, status, transaction_date, customer_id 
        FROM dbo.stage_transactions
        WHERE batch_date = @batch_date AND source_system = @source_system
    ) AS src
    ON tgt.transaction_id = src.transaction_id
    WHEN MATCHED AND (tgt.status <> src.status OR tgt.amount_eur <> src.amount_eur) THEN
        UPDATE SET
            tgt.status = src.status,
            tgt.amount_eur = src.amount_eur,
            tgt._modified_ts = GETUTCDATE()
    WHEN NOT MATCHED BY TARGET THEN
        INSERT (transaction_id, amount_eur, currency, status, transaction_date,
                customer_id, _source, _load_ts)
        VALUES (src.transaction_id, src.amount_eur, src.currency, src.status,
                src.transaction_date, src.customer_id, @source_system, GETUTCDATE());

    SET @rows_inserted = @@ROWCOUNT;

    COMMIT TRANSACTION;

    IF @debug = 1
        SELECT @rows_inserted AS rows_affected;

    RETURN 0;
END;

-- Scalar UDF: risk tier classification (use inline TVF for performance)
CREATE OR ALTER FUNCTION dbo.fn_get_risk_tier(@amount_eur DECIMAL(18,2))
RETURNS NVARCHAR(20)
AS
BEGIN
    RETURN CASE
        WHEN @amount_eur >= 100000 THEN 'TIER_1'
        WHEN @amount_eur >= 10000  THEN 'TIER_2'
        WHEN @amount_eur >= 1000   THEN 'TIER_3'
        ELSE 'TIER_4'
    END;
END;

-- Execute from ADF: Stored Procedure activity
EXEC dbo.usp_load_silver_transactions @batch_date = '2024-01-15', @source_system = 'EU_GATEWAY';
```

**Enterprise Data Scenario:**  
ADF pipeline calls usp_load_silver_transactions as a Stored Procedure activity, passing batch_date and source_system as pipeline parameters, enabling zero-code daily batch loading with built-in upsert logic.

**Optimizer Invariants & Performance Traps:**
- SET XACT_ABORT ON auto-rolls back on any error — removes need for TRY/CATCH in simple procedures
- MERGE is the T-SQL upsert — handles INSERT, UPDATE, DELETE in one atomic statement
- Scalar UDFs prevent parallelism in execution plans — prefer inline table-valued functions (ITVF) for computed columns
- ADF Stored Procedure activity passes parameters by name — match @param names exactly to ADF parameter names

---

### Q1.8: Views & Schema Design Patterns (DDL)

**Question & Concept Overview:**  
Views provide a layer of abstraction over complex table structures, enabling GDPR data masking, simplified Power BI connections, and schema evolution without breaking downstream consumers.

**SQL Implementation & Query Plan:**
```sql
-- Gold view: pre-joined, pre-aggregated for Power BI Direct Query
CREATE OR ALTER VIEW dbo.vw_gold_transactions
WITH SCHEMABINDING  -- prevents underlying table changes without dropping view
AS
SELECT
    t.transaction_id,
    t.amount_eur,
    t.currency,
    t.status,
    t.transaction_date,
    t.is_high_value,
    -- GDPR: mask PAN/account numbers in view (show last 4 only)
    c.customer_name,
    REPLICATE('*', LEN(c.account_number) - 4) +
        RIGHT(c.account_number, 4) AS account_number_masked,
    c.country_code,
    cp.counterparty_name,
    cp.is_sanctioned,
    -- Derived columns for reporting
    DATENAME(MONTH, t.transaction_date) AS month_name,
    DATEPART(YEAR,  t.transaction_date) AS report_year,
    DATEPART(MONTH, t.transaction_date) AS report_month,
    DATEPART(WEEK,  t.transaction_date) AS report_week,
    t.is_high_value * t.amount_eur AS high_value_volume
FROM dbo.fact_transactions t
INNER JOIN dbo.dim_customers c      ON t.customer_id      = c.customer_id
INNER JOIN dbo.dim_counterparties cp ON t.counterparty_id = cp.counterparty_id
WHERE t.is_active = 1;
GO

-- Indexed view for pre-computed aggregations (materialized in Azure SQL)
CREATE OR ALTER VIEW dbo.vw_daily_volume_by_currency
WITH SCHEMABINDING
AS
SELECT
    transaction_date,
    currency,
    COUNT_BIG(*) AS txn_count,
    SUM(amount_eur) AS total_volume_eur
FROM dbo.fact_transactions
GROUP BY transaction_date, currency;
GO

-- Create unique clustered index to materialize the view
CREATE UNIQUE CLUSTERED INDEX IX_daily_volume
ON dbo.vw_daily_volume_by_currency (transaction_date, currency);
```

**Enterprise Data Scenario:**  
Creating GDPR-compliant Gold views on Azure SQL with built-in data masking for Power BI Direct Query connections, enabling real-time C-level dashboards without exposing raw financial data.

**Optimizer Invariants & Performance Traps:**
- WITH SCHEMABINDING prevents dropping underlying tables without first dropping the view — safety guard
- Indexed views (materialized views) store aggregation results physically — Power BI queries are instant
- GDPR masking in view layer: account numbers masked by default, DBA grants access to unmasked table separately
- Power BI Direct Query to views avoids importing data — always reflects current Silver layer state

---

### Q1.9: spark.sql() Basics – Running SQL in PySpark (Spark SQL Fundamentals)

**Question & Concept Overview:**  
spark.sql() allows you to execute SQL statements directly against the Spark session. It returns a DataFrame that can be further transformed or displayed. This is the entry point for all SQL-based interactions in Databricks notebooks.

**SQL Implementation & Query Plan:**
```sql
-- In a Databricks notebook cell (SQL mode)
-- Or via spark.sql() in PySpark:

-- 1. Simple query against an in-memory view
SELECT current_date() AS run_date, current_user() AS executed_by;

-- 2. Create a temp view from a DataFrame (PySpark interop)
-- df = spark.read.format('delta').load('/mnt/bronze/transactions')
-- df.createOrReplaceTempView('raw_transactions')

-- 3. Query the temp view via SQL
SELECT
    txn_id,
    account_id,
    txn_amount,
    txn_currency,
    txn_date
FROM raw_transactions
WHERE txn_amount > 10000
  AND txn_currency = 'EUR'
LIMIT 100;

-- 4. Set Spark SQL config within SQL
SET spark.sql.shuffle.partitions = 200;
SET spark.databricks.delta.optimizeWrite.enabled = true;

-- 5. Use spark.sql() result as DataFrame (PySpark)
-- result_df = spark.sql("""
--     SELECT account_id, SUM(txn_amount) AS total_amount
--     FROM raw_transactions
--     GROUP BY account_id
-- """)
-- result_df.display()
```

**Enterprise Data Scenario:**  
A TCS BFSI team running ad-hoc regulatory queries on Azure Databricks — analysts write SQL while engineers orchestrate via PySpark pipelines, using spark.sql() to bridge both worlds in multi-hop Medallion Architecture notebooks.

**Optimizer Invariants & Performance Traps:**
- spark.sql() returns a DataFrame — chain .display(), .show(), .write, etc.
- SQL cells in Databricks use %sql magic — no need to wrap in spark.sql()
- Temp views created via createOrReplaceTempView are session-scoped; Global temp views persist across sessions within the same app
- SET commands configure Spark session properties and can affect query performance significantly
- In Unity Catalog environments, always qualify table names: catalog.schema.table

---

### Q1.10: Creating and Using Databases/Schemas (Spark SQL Fundamentals)

**Question & Concept Overview:**  
In Spark SQL, databases and schemas are synonymous terms used to logically group tables. In Unity Catalog, the hierarchy is Catalog > Schema > Table, replacing the legacy two-level Hive metastore model. Proper namespace management is foundational for any enterprise data lake.

**SQL Implementation & Query Plan:**
```sql
-- =============================================
-- Database/Schema Management in Databricks SQL
-- Scenario: EU BFSI Medallion Architecture setup
-- =============================================

-- Create catalog (Unity Catalog only)
CREATE CATALOG IF NOT EXISTS eu_bfsi_prod
  COMMENT 'Production catalog for EU Banking, Financial Services & Insurance data';

-- Create schemas for each Medallion layer
CREATE SCHEMA IF NOT EXISTS eu_bfsi_prod.bronze
  COMMENT 'Raw ingestion layer — unprocessed data from source systems'
  MANAGED LOCATION 'abfss://bronze@euadlsprod.dfs.core.windows.net/';

CREATE SCHEMA IF NOT EXISTS eu_bfsi_prod.silver
  COMMENT 'Cleansed and conformed layer — validated, deduplicated data'
  MANAGED LOCATION 'abfss://silver@euadlsprod.dfs.core.windows.net/';

CREATE SCHEMA IF NOT EXISTS eu_bfsi_prod.gold
  COMMENT 'Aggregated business layer — KPIs, reports, ML features'
  MANAGED LOCATION 'abfss://gold@euadlsprod.dfs.core.windows.net/';

-- Set active catalog and schema for subsequent statements
USE CATALOG eu_bfsi_prod;
USE SCHEMA silver;

-- Verify current context
SELECT current_catalog(), current_database();

-- List all schemas in current catalog
SHOW SCHEMAS IN eu_bfsi_prod;

-- Drop schema (CASCADE drops all contained objects)
-- DROP SCHEMA IF EXISTS eu_bfsi_dev.temp CASCADE;
```

**Enterprise Data Scenario:**  
Setting up a new EU regulatory reporting workspace in Azure Databricks with Unity Catalog for a retail bank's AML (Anti-Money Laundering) compliance team — each Medallion layer gets its own schema, storage location, and access control boundary.

**Optimizer Invariants & Performance Traps:**
- Unity Catalog uses 3-level namespace: catalog.schema.table — always use fully qualified names in production
- MANAGED LOCATION specifies ADLS Gen2 path for all managed tables within the schema
- USE CATALOG and USE SCHEMA set the session context — subsequent unqualified table refs resolve to these
- Legacy Hive metastore uses hive_metastore as default catalog — migration to Unity Catalog is recommended
- Schema-level permissions in Unity Catalog cascade to all tables within — design schemas around access boundaries

---

### Q1.11: SELECT / WHERE / ORDER BY / LIMIT in Spark SQL (Spark SQL Fundamentals)

**Question & Concept Overview:**  
Foundational DQL (Data Query Language) operations in Spark SQL follow ANSI SQL syntax. Spark SQL supports predicate pushdown to optimize WHERE clause filtering, especially on partitioned Delta tables. ORDER BY in distributed systems is expensive — use SORT WITHIN PARTITIONS for better performance at scale.

**SQL Implementation & Query Plan:**
```sql
-- =============================================
-- DQL Fundamentals — EU Banking Transactions
-- =============================================

USE CATALOG eu_bfsi_prod;
USE SCHEMA silver;

-- Basic SELECT with column aliasing
SELECT
    txn_id                              AS transaction_id,
    account_id,
    UPPER(txn_type)                     AS transaction_type,
    txn_amount,
    txn_currency,
    ROUND(txn_amount * fx_rate, 2)      AS amount_in_eur,
    txn_timestamp                       AS transaction_ts,
    DATE(txn_timestamp)                 AS transaction_date
FROM silver_transactions
WHERE
    txn_date >= '2024-01-01'            -- Partition pruning benefit
    AND txn_date <  '2025-01-01'
    AND txn_currency IN ('EUR', 'GBP', 'USD')
    AND txn_amount   BETWEEN 1000 AND 1000000
    AND txn_status   != 'REVERSED'
    AND account_id   IS NOT NULL
ORDER BY txn_amount DESC
LIMIT 500;

-- DISTINCT values
SELECT DISTINCT txn_currency, txn_type
FROM silver_transactions
ORDER BY txn_currency;

-- Wildcard LIKE filter (AML keyword scan)
SELECT txn_id, merchant_name, txn_amount
FROM silver_transactions
WHERE merchant_name LIKE '%CRYPTO%'
   OR merchant_name LIKE '%OFFSHORE%'
ORDER BY txn_amount DESC;

-- NULL-safe comparisons
SELECT *
FROM silver_accounts
WHERE risk_score IS NULL
   OR credit_limit <=> 0;  -- <=> is NULL-safe equality
```

**Enterprise Data Scenario:**  
Compliance analysts at a European bank querying the silver transaction layer to identify high-value FX trades for regulatory EMIR reporting — partition pruning on txn_date dramatically reduces query cost on multi-billion-row Delta tables.

**Optimizer Invariants & Performance Traps:**
- Spark SQL supports ANSI SQL — use standard syntax; Spark-specific extensions are additive
- WHERE on partition columns (e.g. txn_date) triggers partition pruning — critical for Delta table performance
- ORDER BY is a full sort — it collects all data to a single partition; use only with LIMIT for large datasets
- BETWEEN is inclusive on both ends: BETWEEN 1000 AND 1000000 includes both boundary values
- The NULL-safe equality operator <=> returns true when both sides are NULL — unlike = which returns NULL

---

### Q1.12: CREATE TABLE USING DELTA (Delta Lake DDL)

**Question & Concept Overview:**  
Delta Lake is the default table format in Databricks. CREATE TABLE USING DELTA creates a versioned, ACID-compliant table backed by Parquet files and a Delta transaction log. Delta tables support schema enforcement, time travel, and DML operations unlike plain Parquet or CSV tables.

**SQL Implementation & Query Plan:**
```sql
-- =============================================
-- CREATE Delta Tables — EU BFSI Bronze Layer
-- =============================================

USE CATALOG eu_bfsi_prod;
USE SCHEMA bronze;

-- Managed Delta table (storage managed by Unity Catalog)
CREATE TABLE IF NOT EXISTS bronze_transactions (
    txn_id          STRING          NOT NULL COMMENT 'Unique transaction identifier from source',
    account_id      STRING          NOT NULL COMMENT 'Source account identifier',
    counterparty_id STRING                   COMMENT 'Beneficiary account or counterparty',
    txn_amount      DECIMAL(18, 4)  NOT NULL COMMENT 'Transaction amount in originating currency',
    txn_currency    STRING(3)       NOT NULL COMMENT 'ISO 4217 currency code',
    txn_type        STRING                   COMMENT 'CREDIT, DEBIT, FEE, REVERSAL',
    txn_status      STRING                   COMMENT 'PENDING, COMPLETED, REVERSED, FAILED',
    txn_timestamp   TIMESTAMP       NOT NULL COMMENT 'Transaction initiation timestamp (UTC)',
    value_date      DATE                     COMMENT 'Settlement date',
    source_system   STRING                   COMMENT 'Origin system: CORE_BANKING, SWIFT, SEPA',
    ingestion_ts    TIMESTAMP       NOT NULL COMMENT 'Databricks ingestion timestamp',
    batch_id        STRING                   COMMENT 'Pipeline run batch identifier',
    _rescued_data   STRING                   COMMENT 'Auto Loader rescued data column'
)
USING DELTA
PARTITIONED BY (txn_date DATE GENERATED ALWAYS AS (DATE(txn_timestamp)))
CLUSTER BY (account_id, txn_currency)       -- Liquid clustering (post-DBR 13.3)
COMMENT 'Raw transaction events ingested from Core Banking and SWIFT — Bronze layer'
TBLPROPERTIES (
    'delta.enableChangeDataFeed'            = 'true',
    'delta.autoOptimize.optimizeWrite'      = 'true',
    'delta.autoOptimize.autoCompact'        = 'true',
    'delta.columnMapping.mode'              = 'name',
    'delta.minReaderVersion'                = '2',
    'delta.minWriterVersion'                = '5',
    'pipelines.autoOptimize.zOrderCols'     = 'account_id',
    'quality.layer'                         = 'bronze',
    'data.owner'                            = 'data-engineering@bank.eu',
    'data.classification'                   = 'CONFIDENTIAL'
);

-- External Delta table (unmanaged — storage controlled externally)
CREATE TABLE IF NOT EXISTS bronze_swift_messages
USING DELTA
LOCATION 'abfss://bronze@euadlsprod.dfs.core.windows.net/swift/messages/'
COMMENT 'SWIFT MT messages — external Delta table';
```

**Enterprise Data Scenario:**  
A data engineering team at a European custodian bank creating the bronze layer for SWIFT and Core Banking ingestion — Delta's ACID guarantees mean concurrent Auto Loader streams can ingest safely without corrupting the table.

**Optimizer Invariants & Performance Traps:**
- USING DELTA is the default in Databricks — explicitly stating it is good practice for documentation clarity
- PARTITIONED BY on a GENERATED ALWAYS AS column avoids user error while enforcing partition consistency
- CLUSTER BY (Liquid Clustering) is the modern replacement for static partitioning — more flexible re-clustering without full rewrites
- TBLPROPERTIES stores metadata and enables features like CDF, column mapping, and auto-optimize
- Managed tables: Unity Catalog controls storage. External tables: you control storage but UC manages metadata

---

### Q1.13: INSERT INTO and INSERT OVERWRITE (Delta Lake DML)

**Question & Concept Overview:**  
INSERT INTO appends records to a Delta table atomically. INSERT OVERWRITE replaces table (or partition) data in a single atomic operation, making it ideal for idempotent batch loads. Delta's transaction log ensures both operations are ACID-compliant and recoverable.

**SQL Implementation & Query Plan:**
```sql
-- =============================================
-- INSERT Operations on Delta Tables
-- EU BFSI — Loading Reference Data
-- =============================================

USE CATALOG eu_bfsi_prod;
USE SCHEMA bronze;

-- 1. INSERT INTO — Append rows
INSERT INTO bronze_transactions
SELECT
    txn_id,
    account_id,
    counterparty_id,
    CAST(txn_amount AS DECIMAL(18,4)),
    txn_currency,
    txn_type,
    txn_status,
    CAST(txn_timestamp AS TIMESTAMP),
    CAST(value_date AS DATE),
    source_system,
    current_timestamp()                 AS ingestion_ts,
    '${batch_id}'                       AS batch_id,
    NULL                                AS _rescued_data
FROM bronze_transactions_staging
WHERE batch_id = '${batch_id}';

-- 2. INSERT OVERWRITE — Replace partition atomically
INSERT OVERWRITE eu_bfsi_prod.silver.silver_fx_rates
PARTITION (rate_date = '2024-12-31')
SELECT
    base_currency,
    target_currency,
    exchange_rate,
    source,
    current_timestamp() AS loaded_ts
FROM eu_bfsi_prod.bronze.bronze_fx_rates
WHERE rate_date = '2024-12-31'
  AND source = 'ECB';

-- 3. INSERT with VALUES (small reference loads)
INSERT INTO eu_bfsi_prod.silver.dim_currency
    (currency_code, currency_name, is_eu_currency, created_ts)
VALUES
    ('EUR', 'Euro',           true,  current_timestamp()),
    ('GBP', 'British Pound',  false, current_timestamp()),
    ('CHF', 'Swiss Franc',    false, current_timestamp()),
    ('DKK', 'Danish Krone',   false, current_timestamp()),
    ('SEK', 'Swedish Krona',  false, current_timestamp());

-- 4. INSERT OVERWRITE (full table replace — idempotent)
INSERT OVERWRITE eu_bfsi_prod.gold.gold_country_risk
SELECT country_code, risk_tier, updated_date
FROM eu_bfsi_prod.silver.silver_country_risk_staging;
```

**Enterprise Data Scenario:**  
Daily ECB FX rate refresh for a European investment bank — INSERT OVERWRITE on the rate_date partition ensures idempotent pipeline runs without risk of duplicate exchange rates corrupting downstream P&L calculations.

**Optimizer Invariants & Performance Traps:**
- INSERT INTO is idempotent only with deduplication logic — without it, rerunning adds duplicates
- INSERT OVERWRITE on Delta replaces entire table or specific partition atomically — safe for reruns
- Delta's transaction log records every INSERT as a new version — enabling time travel rollback
- Use INSERT OVERWRITE for daily/monthly partition refreshes; MERGE INTO for upsert patterns
- Schema validation is enforced on INSERT — column types must match or be castable to target schema

---

### Q1.14: DESCRIBE TABLE / DESCRIBE EXTENDED / SHOW TABLES (Metadata & Catalog)

**Question & Concept Overview:**  
DESCRIBE and SHOW commands are essential for understanding table schemas, metadata, storage locations, and table properties without opening external tools. In Unity Catalog environments, these commands expose catalog-level metadata including owner, creation time, and data classification tags.

**SQL Implementation & Query Plan:**
```sql
-- =============================================
-- Metadata Discovery Commands
-- EU BFSI Data Catalog Exploration
-- =============================================

USE CATALOG eu_bfsi_prod;
USE SCHEMA silver;

-- 1. Basic column schema
DESCRIBE TABLE silver_transactions;
-- Returns: col_name, data_type, comment

-- 2. Extended metadata (storage, properties, stats)
DESCRIBE TABLE EXTENDED silver_transactions;
-- Returns: schema + Table Type, Location, Provider,
--          Owner, Created Time, Table Properties, Statistics

-- 3. Describe specific partition
DESCRIBE TABLE EXTENDED silver_transactions
PARTITION (txn_date = '2024-06-01');

-- 4. Show all tables in current schema
SHOW TABLES IN eu_bfsi_prod.silver;

-- 5. Show tables matching a pattern
SHOW TABLES IN eu_bfsi_prod.bronze LIKE 'bronze_*';

-- 6. Show all schemas
SHOW SCHEMAS IN eu_bfsi_prod;

-- 7. Show all catalogs (Unity Catalog)
SHOW CATALOGS;

-- 8. Show columns
SHOW COLUMNS IN silver_transactions;

-- 9. Show create statement (DDL reverse engineering)
SHOW CREATE TABLE eu_bfsi_prod.silver.silver_transactions;

-- 10. Show table properties
SHOW TBLPROPERTIES eu_bfsi_prod.silver.silver_transactions;

-- 11. Show partitions
SHOW PARTITIONS eu_bfsi_prod.silver.silver_transactions;

-- 12. Delta-specific: table history
DESCRIBE HISTORY eu_bfsi_prod.silver.silver_transactions
LIMIT 20;
-- Returns: version, timestamp, userId, operation, operationParameters
```

**Enterprise Data Scenario:**  
A data governance team at a European insurance company auditing table ownership and storage locations before migrating from Hive Metastore to Unity Catalog — DESCRIBE EXTENDED and SHOW CREATE TABLE help automate the migration DDL generation.

**Optimizer Invariants & Performance Traps:**
- DESCRIBE EXTENDED is the go-to for debugging table issues — reveals location, format, owner, and properties
- DESCRIBE HISTORY is unique to Delta Lake — shows full audit trail of all DML/DDL operations with timestamps
- SHOW CREATE TABLE is invaluable for documentation and reproducing table DDL in new environments
- SHOW TBLPROPERTIES helps verify Delta features like CDF, column mapping, and optimize settings
- In Unity Catalog, DESCRIBE TABLE EXTENDED shows the securable object's owner and creation metadata

---

### Q1.15: Basic SQL Functions: CAST, COALESCE, NVL, ISNULL (Spark SQL Functions)

**Question & Concept Overview:**  
Type conversion and null-handling functions are the building blocks of data quality transformations in the silver layer. CAST enforces type safety, while COALESCE/NVL/ISNULL provide null-handling patterns that prevent downstream aggregation errors in financial reporting.

**SQL Implementation & Query Plan:**
```sql
-- =============================================
-- Type Conversion & NULL Handling
-- EU BFSI Silver Layer Data Cleansing
-- =============================================

USE CATALOG eu_bfsi_prod;
USE SCHEMA silver;

SELECT
    -- CAST: Explicit type conversion
    txn_id,
    CAST(txn_amount AS DECIMAL(18, 4))              AS txn_amount_decimal,
    CAST(txn_timestamp AS DATE)                     AS txn_date,
    CAST(txn_timestamp AS STRING)                   AS txn_ts_str,
    CAST('2024-12-31' AS DATE)                      AS end_date,
    CAST(is_international AS BOOLEAN)               AS international_flag,

    -- COALESCE: Returns first non-null value
    COALESCE(merchant_name, counterparty_name,
             beneficiary_name, 'UNKNOWN')           AS resolved_party_name,
    COALESCE(fx_rate, 1.0)                          AS fx_rate_with_default,
    COALESCE(credit_limit, overdraft_limit, 0.0)    AS effective_limit,

    -- NVL: Identical to COALESCE(expr, default) — Hive/Spark compatibility
    NVL(risk_score, 0)                              AS risk_score_safe,
    NVL(branch_code, 'ONLINE')                      AS branch_code_safe,

    -- ISNULL / ISNOTNULL / IFNULL
    ISNULL(reversal_reference)                      AS is_reversal,
    ISNOTNULL(settlement_date)                      AS is_settled,
    IFNULL(processing_fee, 0.00)                    AS processing_fee_safe,

    -- NVL2: NVL2(expr, if_not_null, if_null)
    NVL2(counterparty_country, 
         CONCAT('CROSS-BORDER:', counterparty_country), 
         'DOMESTIC')                                AS txn_geography,

    -- Combining CAST + COALESCE for safe numeric operations
    CAST(COALESCE(txn_amount, 0) AS DECIMAL(18,4))
        * CAST(COALESCE(fx_rate, 1.0) AS DECIMAL(10,6))  AS amount_eur,

    -- NULLIF: Returns NULL if two values are equal
    NULLIF(error_code, '')                          AS error_code_clean,  -- Empty string to NULL
    NULLIF(txn_count, 0)                            AS txn_count_nonzero  -- 0 to NULL (safe division)

FROM bronze_transactions
WHERE ingestion_date = current_date();
```

**Enterprise Data Scenario:**  
Silver layer data cleansing pipeline at a European payments processor — raw Core Banking data arrives with mixed types and nulls; CAST and COALESCE transforms ensure downstream gold layer aggregations produce accurate SEPA reporting figures.

**Optimizer Invariants & Performance Traps:**
- COALESCE is ANSI SQL and evaluates arguments left to right — use it over NVL for portability
- NULLIF(value, '') is the idiomatic way to convert empty strings to NULL in cleansing pipelines
- CAST is strict — use TRY_CAST to return NULL instead of throwing on invalid conversions
- DECIMAL(18,4) is the recommended type for financial amounts — avoids floating-point precision errors
- NVL is Hive-compatible syntax supported in Spark SQL; prefer COALESCE in new code for ANSI compliance

---

### Q1.16: Reading Files Directly with SQL (CSV, JSON, Parquet) (Spark SQL Fundamentals)

**Question & Concept Overview:**  
Spark SQL supports querying files directly without defining a table, using the `format.\`path\`` syntax. This is useful for data exploration, one-time loads, and Auto Loader alternative ingestion. Delta, Parquet, JSON, CSV, and Avro are all supported inline in SELECT statements.

**SQL Implementation & Query Plan:**
```sql
-- =============================================
-- Direct File Querying in Spark SQL
-- EU BFSI — Exploring Raw Ingestion Files
-- =============================================

-- 1. Read CSV directly (with inferred schema)
SELECT *
FROM csv.`abfss://raw@euadlsprod.dfs.core.windows.net/ecb_fx_rates/2024/12/31/`
LIMIT 100;

-- 2. Read CSV with explicit schema and options
SELECT *
FROM read_files(
    'abfss://raw@euadlsprod.dfs.core.windows.net/ecb_fx_rates/2024/',
    format => 'csv',
    header => 'true',
    inferSchema => 'true',
    sep => ','
);

-- 3. Read Parquet file/directory
SELECT
    account_id,
    balance,
    as_of_date
FROM parquet.`abfss://bronze@euadlsprod.dfs.core.windows.net/account_balances/year=2024/month=12/`
WHERE as_of_date >= '2024-12-01';

-- 4. Read JSON (SWIFT MT103 messages)
SELECT
    get_json_object(value, '$.MessageType')     AS msg_type,
    get_json_object(value, '$.TransactionRef')  AS txn_ref,
    get_json_object(value, '$.Amount.Value')    AS amount,
    get_json_object(value, '$.Amount.Currency') AS currency,
    get_json_object(value, '$.ValueDate')       AS value_date
FROM json.`abfss://raw@euadlsprod.dfs.core.windows.net/swift/mt103/2024/12/`
LIMIT 200;

-- 5. Read Delta files directly
SELECT * FROM delta.`abfss://bronze@euadlsprod.dfs.core.windows.net/transactions/`
LIMIT 50;

-- 6. Create a table from file (CTAS)
CREATE TABLE IF NOT EXISTS eu_bfsi_prod.bronze.bronze_ecb_fx
USING DELTA
AS
SELECT
    _metadata.file_path          AS source_file,
    _metadata.file_modification_time AS file_ts,
    *
FROM read_files(
    'abfss://raw@euadlsprod.dfs.core.windows.net/ecb_fx_rates/',
    format => 'csv',
    header => 'true',
    inferSchema => 'true'
);
```

**Enterprise Data Scenario:**  
A data engineer at a European asset manager exploring newly landed ECB exchange rate CSV files in ADLS Gen2 before defining the formal bronze table schema — direct SQL querying saves time compared to writing full PySpark read/display code.

**Optimizer Invariants & Performance Traps:**
- format.`path` syntax works for delta, parquet, json, csv, avro, orc — convenient for exploration
- read_files() is the modern Databricks SQL function with richer options including schema hints
- _metadata columns (file_path, file_size, file_modification_time) are auto-populated by Spark for traceability
- Direct file queries don't benefit from Delta optimizations — create a Delta table for production use
- CTAS (CREATE TABLE AS SELECT) is the fastest way to materialize exploratory queries into Delta tables

---

### Q1.17: Common Table Expressions (CTEs) & Modular SQL (Query Design)

**Question & Concept Overview:**  
How CTEs (`WITH` clauses) structure complex multi-stage transformations, improve readability, and optimize execution compared to nested subqueries.

**Detailed Technical Explanation:**  
Common Table Expressions (CTEs) provide temporary named result sets that exist only within the execution scope of a single SQL statement. Unlike inline subqueries, CTEs can be referenced multiple times, enable recursive tree traversal, and allow query optimizers to produce cleaner execution trees. In distributed engines like Databricks and Snowflake, CTEs are often inlined or materialized based on cost estimation.

**Production Code / SQL Implementation:**
```sql
-- Multi-tier customer spend tier calculation using CTEs
WITH customer_aggregates AS (
    SELECT
        customer_id,
        COUNT(order_id) AS total_orders,
        SUM(order_amount) AS lifetime_value,
        MAX(order_date) AS last_purchase_date
    FROM prod_catalog.gold.fact_orders
    WHERE order_status = 'COMPLETED'
    GROUP BY customer_id
),
customer_segments AS (
    SELECT
        customer_id,
        lifetime_value,
        CASE
            WHEN lifetime_value >= 10000 THEN 'VIP_TIER'
            WHEN lifetime_value >= 2500 THEN 'GROWTH_TIER'
            ELSE 'STANDARD_TIER'
        END AS loyalty_segment
    FROM customer_aggregates
)
SELECT
    loyalty_segment,
    COUNT(*) AS total_customers,
    ROUND(AVG(lifetime_value), 2) AS avg_segment_ltv
FROM customer_segments
GROUP BY loyalty_segment
ORDER BY avg_segment_ltv DESC;
```

**Key Invariants & Architectural Best Practices:**
- Use CTEs to avoid deeply nested subqueries and enhance code review maintainability.
- Be aware that in PostgreSQL <= 11, CTEs are optimization fences; modern engines (PG 12+, Spark, Snowflake) inline them automatically.
- Keep CTE logic focused on a single logical transformation step per block.

**Certification Alignment:** `Databricks Certified Data Engineer Associate / SQL Specialist`

---

### Q1.18: Set Operations: UNION, UNION ALL, INTERSECT, EXCEPT (Relational Algebra)

**Question & Concept Overview:**  
Differences in performance, deduplication overhead, and memory consumption between `UNION ALL` and `UNION`, plus `INTERSECT` and `EXCEPT`.

**Detailed Technical Explanation:**  
Set operations combine result sets from two or more queries. `UNION` performs an implicit `DISTINCT` operation across all returned columns, triggering an expensive distributed shuffle and sort/hash aggregation to eliminate duplicate rows. In contrast, `UNION ALL` simply concatenates partitions without inspecting row contents, executing at near zero CPU cost. `INTERSECT` returns rows present in both sets, while `EXCEPT` (or `MINUS`) returns rows in the first query not present in the second.

**Production Code / SQL Implementation:**
```sql
-- Fast union across regional order tables avoiding sort-deduplication
SELECT order_id, customer_id, order_amount, 'EMEA' AS region
FROM prod_catalog.silver.orders_emea
UNION ALL
SELECT order_id, customer_id, order_amount, 'APAC' AS region
FROM prod_catalog.silver.orders_apac
UNION ALL
SELECT order_id, customer_id, order_amount, 'NA' AS region
FROM prod_catalog.silver.orders_na;
```

**Key Invariants & Architectural Best Practices:**
- Always default to `UNION ALL` unless business logic strictly requires deduplicating entire rows.
- Ensure column count, ordering, and compatible data types align across all queries in the set union.
- In distributed engines, `UNION` triggers an expensive global shuffle; use explicit `GROUP BY` if you only need key deduplication.

**Certification Alignment:** `Databricks Certified Data Engineer Associate`

---

### Q1.19: String Manipulation & Pattern Matching: LIKE, REGEXP, SUBSTRING (Data Cleaning)

**Question & Concept Overview:**  
Extracting structured tokens, masking sensitive substrings, and validating format patterns using SQL string functions and regular expressions.

**Detailed Technical Explanation:**  
Data cleaning frequently requires string sanitization, token parsing, and regex pattern matching. Standard SQL provides `LIKE` and `ILIKE` for wildcard searches, while modern lakehouse engines (Spark SQL, Snowflake, BigQuery) support POSIX regular expressions (`REGEXP_EXTRACT`, `REGEXP_REPLACE`, `REGEXP_LIKE`). For high-throughput queries, native string slicing (`SUBSTRING`, `SPLIT`) is significantly faster than compiling regex engines per row.

**Production Code / SQL Implementation:**
```sql
-- Sanitizing, parsing and masking customer telemetry strings
SELECT
    raw_id,
    -- Extract domain from email using regex
    regexp_extract(email_address, '@([a-zA-Z0-9.-]+)', 1) AS email_domain,
    -- Mask credit card number preserving last 4 digits
    concat('XXXX-XXXX-XXXX-', substring(card_number, -4, 4)) AS masked_card,
    -- Parse structured JSON tokens
    get_json_object(metadata_payload, '$.device.os') AS client_os
FROM prod_catalog.bronze.user_sessions
WHERE email_address LIKE '%@%' AND card_number IS NOT NULL;
```

**Key Invariants & Architectural Best Practices:**
- Prefer `LIKE` with prefix wildcards (`val%`) over regex when searching indexed columns.
- Use `regexp_extract` with capture groups `( )` for precise token extraction.
- Leverage vectorized string functions (`split_part`, `substring`) over complex regular expressions in hot ETL paths.

**Certification Alignment:** `Databricks Certified Associate / Professional Data Engineer`

---

### Q1.20: Date & Time Manipulation: Intervals, Truncation & Timezones (Temporal Analysis)

**Question & Concept Overview:**  
Handling UTC normalization, timezone offsets, date truncation (`DATE_TRUNC`), and interval arithmetic for time-series analytics.

**Detailed Technical Explanation:**  
Temporal data must be normalized to UTC at the ingestion boundary to eliminate daylight saving ambiguities. Functions like `DATE_TRUNC('month', event_ts)` round timestamps down to the start of the specified interval, enabling clean time-grain grouping. Interval arithmetic (`CURRENT_TIMESTAMP() - INTERVAL 7 DAYS`) enables sliding lookback windows and automated data retention pruning without manual date calculation.

**Production Code / SQL Implementation:**
```sql
-- Rolling 7-day active user metric normalized to UTC
SELECT
    date_trunc('day', from_utc_timestamp(event_timestamp, 'America/New_York')) AS event_day_est,
    COUNT(DISTINCT user_id) AS daily_active_users,
    COUNT(event_id) AS total_events
FROM prod_catalog.silver.events_stream
WHERE event_timestamp >= current_timestamp() - INTERVAL 30 DAYS
GROUP BY 1
ORDER BY event_day_est DESC;
```

**Key Invariants & Architectural Best Practices:**
- Store all timestamps in UTC (`TIMESTAMP_NTZ` or UTC-normalized `TIMESTAMP`) in Bronze and Silver tiers.
- Convert to target business timezones only at the consumption / reporting layer via `from_utc_timestamp`.
- Use `date_trunc` instead of string formatting (`DATE_FORMAT`) to preserve native date types for downstream sorting.

**Certification Alignment:** `Databricks Certified Data Engineer Associate`

---

### Q1.21: Window Functions Foundations: ROW_NUMBER(), RANK(), DENSE_RANK() (Analytical SQL)

**Question & Concept Overview:**  
Differences in tie-breaking, rank gaps, and deduplication patterns among `ROW_NUMBER()`, `RANK()`, and `DENSE_RANK()`.

**Detailed Technical Explanation:**  
Window functions perform calculations across a set of rows related to the current row without collapsing them into a single aggregate row. `ROW_NUMBER()` assigns a unique, strictly sequential integer to every row regardless of ties. `RANK()` assigns identical ranks to tied rows and skips subsequent numbers (e.g. 1, 2, 2, 4). `DENSE_RANK()` assigns identical ranks to ties without skipping numbers (e.g. 1, 2, 2, 3). For deduplicating records by recency, `ROW_NUMBER() OVER (PARTITION BY id ORDER BY updated_at DESC)` is the standard industry pattern.

**Production Code / SQL Implementation:**
```sql
-- Deduplicating records by latest timestamp using ROW_NUMBER()
WITH ranked_records AS (
    SELECT
        account_id,
        account_status,
        balance_amount,
        updated_at,
        ROW_NUMBER() OVER (
            PARTITION BY account_id
            ORDER BY updated_at DESC, transaction_id DESC
        ) AS row_num
    FROM prod_catalog.silver.account_snapshots
)
SELECT account_id, account_status, balance_amount, updated_at
FROM ranked_records
WHERE row_num = 1;
```

**Key Invariants & Architectural Best Practices:**
- Include deterministic tie-breakers (e.g. `transaction_id DESC`) in `ORDER BY` when using `ROW_NUMBER()`.
- Filter `row_num = 1` inside an outer query or CTE; window functions are forbidden directly in the `WHERE` clause.
- Ensure the `PARTITION BY` column aligns with table clustering/partitioning keys to minimize shuffle data movement.

**Certification Alignment:** `Databricks Certified Data Engineer Professional`

---

### Q1.22: Handling NULLs: COALESCE, NULLIF, and NVL2 (Defensive SQL)

**Question & Concept Overview:**  
Preventing divide-by-zero crashes, replacing missing values, and handling three-valued logic (`TRUE`, `FALSE`, `UNKNOWN`) in SQL.

**Detailed Technical Explanation:**  
SQL utilizes three-valued logic where comparisons with `NULL` evaluate to `UNKNOWN`. Functions like `COALESCE(col1, col2, default_val)` evaluate arguments from left to right, returning the first non-null value. `NULLIF(a, b)` returns `NULL` if `a == b`, which is essential for preventing catastrophic `division by zero` runtime failures (e.g. `revenue / NULLIF(units, 0)`). `NVL2(expr, val_if_not_null, val_if_null)` provides concise ternary evaluation without verbose `CASE` expressions.

**Production Code / SQL Implementation:**
```sql
-- Defensive calculations preventing divide-by-zero and missing metrics
SELECT
    campaign_id,
    impressions,
    clicks,
    -- Prevent division by zero when impressions is 0
    ROUND(clicks * 100.0 / NULLIF(impressions, 0), 4) AS click_through_rate_pct,
    -- Fallback hierarchy for customer contact email
    COALESCE(primary_email, secondary_email, 'no-contact-email@domain.internal') AS active_email
FROM prod_catalog.gold.marketing_campaigns;
```

**Key Invariants & Architectural Best Practices:**
- Never use `= NULL` or `!= NULL`; always use `IS NULL` or `IS NOT NULL`.
- Always wrap divisors in `NULLIF(divisor, 0)` in production queries to guarantee pipeline resilience.
- When joining on nullable keys, use `colA <=> colB` (null-safe equality) in Spark SQL or coalesce keys with dummy values.

**Certification Alignment:** `Databricks Certified Data Engineer Associate`

---

### Q1.23: Temporary Views vs Global Temp Views vs Managed Tables (Persistence Tiers)

**Question & Concept Overview:**  
Scope, lifecycle, metadata catalog registration, and memory overhead differences across session-scoped views, cross-session temp views, and managed tables.

**Detailed Technical Explanation:**  
Modern SQL engines provide multiple tiers of persistence. A local Temporary View (`CREATE TEMP VIEW`) is scoped strictly to the current Spark session/notebook and destroyed upon session termination. A Global Temporary View (`CREATE GLOBAL TEMP VIEW`) is tied to a system-preserved `global_temp` database and accessible across all sessions on the same cluster until the cluster restarts. A Managed Table (`CREATE TABLE`) permanently registers schema and metadata in Unity Catalog and persists Parquet files in cloud object storage.

**Production Code / SQL Implementation:**
```sql
-- 1. Create a session-scoped temporary view
CREATE OR REPLACE TEMP VIEW v_daily_summary AS
SELECT date_trunc('day', order_ts) AS order_date, SUM(amount) AS daily_rev
FROM prod_catalog.silver.orders
GROUP BY 1;

-- 2. Create a permanent Unity Catalog managed Delta table
CREATE TABLE IF NOT EXISTS prod_catalog.gold.daily_financial_summary
USING DELTA
AS SELECT * FROM v_daily_summary;
```

**Key Invariants & Architectural Best Practices:**
- Use Temp Views for intermediate notebook prototyping to avoid cluttering production catalogs with throwaway tables.
- Global Temp Views require prefixing queries with `global_temp.<view_name>`.
- In Unity Catalog, managed tables own both metadata and physical data files; dropping a managed table purges underlying storage after retention expiration.

**Certification Alignment:** `Databricks Certified Data Engineer Associate`

---

### Q1.24: Delta Lake Time Travel & History Inspection in SQL (Data Auditing)

**Question & Concept Overview:**  
Executing audit queries, tracking who committed changes, and retrieving previous table states using `DESCRIBE HISTORY` and `VERSION AS OF`.

**Detailed Technical Explanation:**  
Because Delta Lake maintains an append-only transaction log (`_delta_log`), every committed transaction records who, when, and what operation modified the table (e.g. `WRITE`, `MERGE`, `OPTIMIZE`). Users can inspect this audit trail using `DESCRIBE HISTORY table_name`. Analysts can time-travel to any historical snapshot using `SELECT * FROM table_name VERSION AS OF <version>` or `TIMESTAMP AS OF '<timestamp>'`, enabling instant recovery from accidental deletions without restoring from backups.

**Production Code / SQL Implementation:**
```sql
-- 1. Inspect transaction history and audit metadata
DESCRIBE HISTORY prod_catalog.gold.dim_customer;

-- 2. Query historical state before an erroneous batch update
SELECT customer_id, email, updated_at
FROM prod_catalog.gold.dim_customer VERSION AS OF 14
WHERE customer_id = 99821;

-- 3. Restore table to previous known good state
RESTORE TABLE prod_catalog.gold.dim_customer TO VERSION AS OF 14;
```

**Key Invariants & Architectural Best Practices:**
- Time travel depends on historical files retained by the table's `delta.deletedFileRetentionDuration` (default 7 days).
- Running `VACUUM` with retention periods shorter than the requested time travel version causes `FileNotFoundException`.
- Use `RESTORE TABLE` for immediate disaster recovery rollback following a corrupt ETL run.

**Certification Alignment:** `Databricks Certified Data Engineer Professional`

---

### Q1.25: Storage Compaction & Hygiene: OPTIMIZE & VACUUM in SQL (Lakehouse Performance)

**Question & Concept Overview:**  
Bin-packing small files into optimal 1GB targets using `OPTIMIZE` and cleaning up obsolete historical files with `VACUUM`.

**Detailed Technical Explanation:**  
Frequent streaming ingestion or concurrent batch appends create thousands of small files (<10MB), causing severe metadata overhead and degrading query throughput. The `OPTIMIZE` SQL command compacts small files into uniform target files (typically 1GB). Co-locating related data along high-cardinality query predicate columns is achieved via `ZORDER BY`. To reclaim cloud object storage costs, `VACUUM` permanently deletes obsolete files no longer needed by the current snapshot or active retention window.

**Production Code / SQL Implementation:**
```sql
-- 1. Bin-pack small files and co-locate data by customer and date
OPTIMIZE prod_catalog.gold.fact_transactions
ZORDER BY (customer_id, transaction_date);

-- 2. Clean up obsolete files older than standard retention (7 days)
VACUUM prod_catalog.gold.fact_transactions RETAIN 168 HOURS;

-- 3. Check table file layout metrics
DESCRIBE DETAIL prod_catalog.gold.fact_transactions;
```

**Key Invariants & Architectural Best Practices:**
- Never run `VACUUM` with 0 hours retention in production without setting safety checks to false, as it crashes concurrent readers.
- Run `OPTIMIZE` on a scheduled maintenance cadence (e.g. nightly or weekly) depending on ingestion velocity.
- In Delta Lake 3.x with Liquid Clustering, `OPTIMIZE` incrementally clusters data without full re-sorting.

**Certification Alignment:** `Databricks Certified Data Engineer Professional`

---
