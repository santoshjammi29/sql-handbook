# 🎓 SQL Interview Guide — Tier 2: Mid-Level Data Engineer (Analytical Mastery & Indexing)

> **Focus Areas**: Analytical Window Functions (ROW_NUMBER, RANK, DENSE_RANK, NTILE), Framing (ROWS vs RANGE), Recursive CTEs, B-Tree vs Hash Indexes, Filtered Indexes, Surrogate vs Natural Keys.
> **Target Audience**: ETL Developers, Analytics Engineers, Database Developers

---

### Q2.1: CTEs & Complex Query Composition (Query Patterns)

**Question & Concept Overview:**  
Common Table Expressions (CTEs) enable breaking complex financial queries into readable, named steps. Recursive CTEs are essential for hierarchical data like organizational structures and account hierarchies.

**SQL Implementation & Query Plan:**
```sql
-- Multi-step CTE: monthly cohort analysis
WITH
-- Step 1: First transaction per customer (cohort assignment)
customer_first_txn AS (
    SELECT
        customer_id,
        MIN(transaction_date) AS cohort_date,
        DATEFROMPARTS(YEAR(MIN(transaction_date)), MONTH(MIN(transaction_date)), 1) AS cohort_month
    FROM dbo.fact_transactions
    WHERE status = 'SETTLED'
    GROUP BY customer_id
),

-- Step 2: All subsequent transactions with cohort label
txn_with_cohort AS (
    SELECT
        t.customer_id,
        t.transaction_date,
        t.amount_eur,
        c.cohort_month,
        DATEDIFF(MONTH, c.cohort_month, DATEFROMPARTS(YEAR(t.transaction_date), MONTH(t.transaction_date), 1)) AS months_since_cohort
    FROM dbo.fact_transactions t
    INNER JOIN customer_first_txn c ON t.customer_id = c.customer_id
    WHERE t.status = 'SETTLED'
),

-- Step 3: Cohort retention matrix
retention AS (
    SELECT
        cohort_month,
        months_since_cohort,
        COUNT(DISTINCT customer_id) AS active_customers,
        SUM(amount_eur) AS cohort_volume
    FROM txn_with_cohort
    GROUP BY cohort_month, months_since_cohort
)

-- Final: Retention rates vs month-0 baseline
SELECT
    r.cohort_month,
    r.months_since_cohort,
    r.active_customers,
    base.active_customers AS cohort_size,
    ROUND(r.active_customers * 100.0 / base.active_customers, 2) AS retention_pct,
    r.cohort_volume
FROM retention r
INNER JOIN retention base
    ON base.cohort_month = r.cohort_month
    AND base.months_since_cohort = 0
ORDER BY r.cohort_month, r.months_since_cohort;
```

**Enterprise Data Scenario:**  
Building customer cohort retention analysis for EU BFSI commercial banking, tracking how monthly customer cohorts evolve over time — key input to churn prediction models in the Azure ML pipeline.

**Optimizer Invariants & Performance Traps:**
- CTEs improve readability by naming intermediate result sets — critical for complex regulatory reports
- Each CTE reference causes re-evaluation (not caching) — use temp tables for expensive CTEs referenced multiple times
- Recursive CTEs require MAXRECURSION hint for deep hierarchies — default limit is 100 levels
- Name CTE steps descriptively (customer_first_txn, not cte1) — enables 6-month maintainability

---

### Q2.2: Window Functions: ROW_NUMBER, RANK, LAG, LEAD (Analytical Functions)

**Question & Concept Overview:**  
Window functions perform calculations across a set of rows related to the current row, without collapsing the result set. They are the cornerstone of financial time-series analysis, trend detection, and ranking.

**SQL Implementation & Query Plan:**
```sql
-- Window functions for BFSI transaction analytics
SELECT
    customer_id,
    transaction_date,
    amount_eur,
    currency,
    status,

    -- Ranking within customer — find most recent transaction
    ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY transaction_date DESC) AS txn_recency_rank,

    -- Dense rank by volume within currency (no gaps)
    DENSE_RANK() OVER (PARTITION BY currency ORDER BY amount_eur DESC) AS volume_rank,

    -- NTILE: assign customers to quartiles by transaction count
    NTILE(4) OVER (PARTITION BY currency ORDER BY amount_eur) AS amount_quartile,

    -- LAG/LEAD: compare to previous/next transaction
    LAG(amount_eur, 1, 0)  OVER (PARTITION BY customer_id ORDER BY transaction_date) AS prev_txn_amount,
    LEAD(amount_eur, 1, 0) OVER (PARTITION BY customer_id ORDER BY transaction_date) AS next_txn_amount,

    -- Running total per customer (cumulative cash flow)
    SUM(amount_eur) OVER (
        PARTITION BY customer_id
        ORDER BY transaction_date
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS cumulative_spend,

    -- 7-day moving average per currency
    AVG(amount_eur) OVER (
        PARTITION BY currency
        ORDER BY transaction_date
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ) AS rolling_7d_avg_eur,

    -- % change vs previous day
    ROUND(
        (amount_eur - LAG(amount_eur) OVER (PARTITION BY customer_id ORDER BY transaction_date))
        / NULLIF(LAG(amount_eur) OVER (PARTITION BY customer_id ORDER BY transaction_date), 0) * 100,
        2
    ) AS pct_change_vs_prev

FROM dbo.fact_transactions
WHERE status = 'SETTLED'
    AND transaction_date BETWEEN '2024-01-01' AND '2024-01-31';
```

**Enterprise Data Scenario:**  
Computing 7-day rolling transaction volumes, customer spend trends, and anomaly detection (sudden spike vs previous day) in Azure Synapse Dedicated Pool for EU BFSI real-time fraud monitoring.

**Optimizer Invariants & Performance Traps:**
- ROW_NUMBER() + WHERE rank=1 is the standard 'latest record per group' pattern — deduplication essential in ETL
- ROWS BETWEEN vs RANGE BETWEEN: use ROWS for predictable window bounds; RANGE can include ties
- LAG/LEAD with default value (LAG(col, 1, 0)) avoids NULL in first row — cleaner for percentage calculations
- Window functions compute AFTER WHERE but BEFORE HAVING — can't filter on window result in same query level

---

### Q2.3: PIVOT & UNPIVOT for Report Formatting (Data Shaping)

**Question & Concept Overview:**  
PIVOT transforms rows to columns, enabling cross-tabulation reports (currencies as columns, dates as rows). UNPIVOT does the reverse — critical for normalizing wide-format source data before ELT loading.

**SQL Implementation & Query Plan:**
```sql
-- PIVOT: currencies as columns, date as rows (executive dashboard format)
SELECT report_date, [EUR], [GBP], [USD], [CHF], [SEK], [NOK]
FROM (
    SELECT
        CAST(transaction_date AS DATE) AS report_date,
        currency,
        amount_eur
    FROM dbo.fact_transactions
    WHERE transaction_date BETWEEN '2024-01-01' AND '2024-01-31'
      AND status = 'SETTLED'
) AS source_data
PIVOT (
    SUM(amount_eur)
    FOR currency IN ([EUR], [GBP], [USD], [CHF], [SEK], [NOK])
) AS pivot_result
ORDER BY report_date;

-- Dynamic PIVOT: currencies not hardcoded (handles new currencies automatically)
DECLARE @currencies NVARCHAR(MAX);
DECLARE @sql NVARCHAR(MAX);

SELECT @currencies = STRING_AGG(QUOTENAME(currency), ',')
FROM (SELECT DISTINCT currency FROM dbo.fact_transactions WHERE status = 'SETTLED') c;

SET @sql = N'
    SELECT report_date, * -- Note: SELECT * used dynamically to auto-bind dynamic column list
    FROM (
        SELECT CAST(transaction_date AS DATE) AS report_date, currency, amount_eur
        FROM dbo.fact_transactions WHERE status = ''SETTLED''
    ) src
    PIVOT (SUM(amount_eur) FOR currency IN (' + @currencies + ')) pvt
    ORDER BY report_date;';

EXEC sp_executesql @sql;

-- UNPIVOT: normalize wide staging table to tall format for Delta Lake load
SELECT customer_id, metric_name, metric_value
FROM dbo.stage_customer_metrics_wide
UNPIVOT (
    metric_value
    FOR metric_name IN (
        total_txns, total_volume_eur, avg_txn_eur, high_value_count, risk_score
    )
) AS unpvt;
```

**Enterprise Data Scenario:**  
Generating the executive currency exposure dashboard for EU BFSI C-level reporting in Azure Synapse, with dynamic PIVOT handling new trading currencies without pipeline code changes.

**Optimizer Invariants & Performance Traps:**
- Dynamic PIVOT with STRING_AGG + QUOTENAME handles new currency codes without code changes
- QUOTENAME() wraps column names in brackets — prevents SQL injection in dynamic PIVOT column list
- Static PIVOT requires hardcoded column list — use only when column values are finite and stable
- UNPIVOT is the ELT normalization pattern — converts source flat files with metric-per-column to tall format

---

### Q2.4: TRY_CATCH Error Handling & Transactions (Error Handling)

**Question & Concept Overview:**  
Robust error handling in T-SQL is critical for production financial systems. TRY_CATCH with transaction management, error logging, and re-throwing enables graceful failure recovery and audit trail maintenance.

**SQL Implementation & Query Plan:**
```sql
-- Production error handling pattern with audit log
CREATE OR ALTER PROCEDURE dbo.usp_process_daily_transactions
    @batch_date DATE,
    @source     NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT OFF;  -- Manual transaction control

    DECLARE @proc_name   NVARCHAR(200) = OBJECT_NAME(@@PROCID);
    DECLARE @start_ts    DATETIME2    = GETUTCDATE();
    DECLARE @rows_loaded INT          = 0;
    DECLARE @error_msg   NVARCHAR(MAX);

    -- Log pipeline start to audit table
    INSERT INTO dbo.pipeline_audit_log (proc_name, batch_date, source, start_ts, status)
    VALUES (@proc_name, @batch_date, @source, @start_ts, 'RUNNING');

    DECLARE @audit_id BIGINT = SCOPE_IDENTITY();

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Main business logic
        INSERT INTO dbo.fact_transactions (transaction_id, amount_eur, currency, status, transaction_date, _load_ts)
        SELECT transaction_id, amount_eur, currency, status, transaction_date, GETUTCDATE()
        FROM dbo.stage_transactions
        WHERE batch_date = @batch_date AND source_system = @source
          AND transaction_id NOT IN (SELECT transaction_id FROM dbo.fact_transactions);

        SET @rows_loaded = @@ROWCOUNT;

        -- Validate: reject if 0 rows (potential upstream issue)
        IF @rows_loaded = 0
            THROW 50001, 'Zero rows loaded — possible upstream data issue', 1;

        COMMIT TRANSACTION;

        -- Log success
        UPDATE dbo.pipeline_audit_log
        SET status = 'SUCCESS', rows_loaded = @rows_loaded, end_ts = GETUTCDATE()
        WHERE audit_id = @audit_id;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        SET @error_msg = ERROR_MESSAGE();

        -- Log failure with full error context
        UPDATE dbo.pipeline_audit_log
        SET status = 'FAILED',
            error_message = @error_msg,
            error_number = ERROR_NUMBER(),
            error_line = ERROR_LINE(),
            end_ts = GETUTCDATE()
        WHERE audit_id = @audit_id;

        -- Re-raise for ADF to capture and trigger alert
        THROW;
    END CATCH;
END;
```

**Enterprise Data Scenario:**  
Production-grade stored procedure called from ADF pipeline, with full audit trail for EU BFSI regulatory compliance, auto-rollback on any failure, and structured error logging for Azure Monitor alerts.

**Optimizer Invariants & Performance Traps:**
- SET XACT_ABORT OFF with manual ROLLBACK gives more control than SET XACT_ABORT ON in complex procedures
- SCOPE_IDENTITY() returns the last identity from the current scope — safer than @@IDENTITY (cross-trigger safe)
- THROW (no args) re-raises the original error with original error number — preserves ADF error context
- Audit log pattern (pipeline_audit_log) provides full run history for GDPR pipeline lineage documentation

---

### Q2.5: JSON & XML in Azure SQL (Semi-Structured Data)

**Question & Concept Overview:**  
Azure SQL's JSON functions enable querying semi-structured Event Hub payloads and REST API responses without moving data to a separate document store, enabling the JSON-in-SQL hybrid pattern.

**SQL Implementation & Query Plan:**
```sql
-- Parse JSON transaction payload from Event Hubs landing table
SELECT
    e.event_id,
    e.received_ts,
    JSON_VALUE(e.payload, '$.transactionId')           AS transaction_id,
    JSON_VALUE(e.payload, '$.amount.value')            AS amount,
    JSON_VALUE(e.payload, '$.amount.currency')         AS currency,
    JSON_VALUE(e.payload, '$.metadata.sourceSystem')   AS source_system,
    JSON_VALUE(e.payload, '$.customer.id')             AS customer_id,
    JSON_VALUE(e.payload, '$.customer.tier')           AS customer_tier
FROM dbo.bronze_event_hub e
WHERE JSON_VALUE(e.payload, '$.status') = 'SETTLED'
  AND ISJSON(e.payload) = 1;  -- validate JSON before parsing

-- OPENJSON: parse JSON array into rows
DECLARE @json_array NVARCHAR(MAX) = '[
    {"id":"T001","amount":4250.75,"currency":"EUR"},
    {"id":"T002","amount":180.00,"currency":"GBP"}
]';

SELECT id, CAST(amount AS DECIMAL(18,2)) AS amount, currency
FROM OPENJSON(@json_array)
WITH (
    id       NVARCHAR(50)   '$.id',
    amount   DECIMAL(18,2)  '$.amount',
    currency NVARCHAR(3)    '$.currency'
);

-- Generate JSON output for REST API response / ADF lookup activity
SELECT
    transaction_id AS transactionId,
    amount_eur AS amountEur,
    currency,
    status,
    transaction_date AS transactionDate
FROM dbo.fact_transactions
WHERE transaction_date = '2024-01-15' AND status = 'SETTLED'
FOR JSON PATH, ROOT('transactions'), INCLUDE_NULL_VALUES;

-- Create computed column with JSON index for fast parsing
ALTER TABLE dbo.bronze_event_hub
ADD transaction_id AS JSON_VALUE(payload, '$.transactionId');

CREATE INDEX IX_bronze_event_hub_txn_id ON dbo.bronze_event_hub (transaction_id);
```

**Enterprise Data Scenario:**  
Parsing Azure Event Hubs payment event payloads (JSON format) directly in Azure SQL without ETL into structured tables, enabling real-time querying of raw Bronze layer data from Power BI.

**Optimizer Invariants & Performance Traps:**
- ISJSON() guard is essential before JSON_VALUE — malformed JSON throws an error without it
- JSON_VALUE returns scalar; JSON_QUERY returns JSON fragment (object/array) — choose correctly
- OPENJSON WITH schema is 5x faster than JSON_VALUE column-by-column for wide JSON objects
- Computed columns on JSON_VALUE + index enables fast lookup on JSON fields without full parse

---

### Q2.6: Temporal Tables: System-Versioned History (Advanced DDL)

**Question & Concept Overview:**  
Temporal tables (system-versioned) automatically maintain full row history, enabling point-in-time queries essential for GDPR audit trails, regulatory retrospective reporting, and SCD Type 2 compliance in Azure SQL.

**SQL Implementation & Query Plan:**
```sql
-- Create temporal table: customer dimension with automatic history
CREATE TABLE dbo.dim_customers (
    customer_sk     INT IDENTITY(1,1) NOT NULL,
    customer_id     NVARCHAR(50) NOT NULL,
    customer_name   NVARCHAR(200) NULL,
    tier            NVARCHAR(20)  NULL,
    country_code    CHAR(2)       NULL,
    risk_rating     NVARCHAR(10)  NULL,
    account_number  NVARCHAR(50)  NULL,
    is_active       BIT NOT NULL DEFAULT 1,

    -- System columns: auto-managed by SQL Server
    SysStartTime DATETIME2 GENERATED ALWAYS AS ROW START NOT NULL,
    SysEndTime   DATETIME2 GENERATED ALWAYS AS ROW END   NOT NULL,

    CONSTRAINT PK_dim_customers PRIMARY KEY (customer_sk),
    CONSTRAINT UQ_customer_id UNIQUE (customer_id),
    PERIOD FOR SYSTEM_TIME (SysStartTime, SysEndTime)
)
WITH (SYSTEM_VERSIONING = ON (HISTORY_TABLE = dbo.dim_customers_history));

-- Normal UPDATE — SQL Server automatically saves old row to history table
UPDATE dbo.dim_customers
SET risk_rating = 'HIGH', tier = 'PREMIUM'
WHERE customer_id = 'CUST-001';

-- Query historical state: what was CUST-001's tier on Jan 1, 2024?
SELECT customer_id, customer_name, tier, risk_rating
FROM dbo.dim_customers
FOR SYSTEM_TIME AS OF '2024-01-01T00:00:00';  -- point-in-time query

-- Query: full change history for audit (GDPR right of access)
SELECT
    customer_id, customer_name, tier, risk_rating,
    SysStartTime AS valid_from,
    SysEndTime   AS valid_to
FROM dbo.dim_customers
FOR SYSTEM_TIME ALL
WHERE customer_id = 'CUST-001'
ORDER BY SysStartTime;

-- BETWEEN: changes in January 2024
SELECT customer_id, customer_name, tier, risk_rating
FROM dbo.dim_customers
FOR SYSTEM_TIME BETWEEN '2024-01-01' AND '2024-02-01'
WHERE customer_id = 'CUST-001';
```

**Enterprise Data Scenario:**  
Maintaining a full audit trail of customer risk rating changes in Azure SQL for EU BFSI regulatory reporting — enabling retrospective queries like 'what was this customer's risk tier at the time of the suspicious transaction?'

**Optimizer Invariants & Performance Traps:**
- Temporal tables provide automatic SCD Type 2 — no custom MERGE logic needed for dimension history
- FOR SYSTEM_TIME AS OF enables point-in-time queries — critical for 'state at transaction time' regulatory reports
- History table is append-only — SQL Server manages it automatically, no manual inserts
- Retention policy can be set (ALTER TABLE ... SET HISTORY_RETENTION_PERIOD = 7 YEARS) for GDPR compliance

---

### Q2.7: Dynamic SQL & Parameterized Queries (Advanced T-SQL)

**Question & Concept Overview:**  
Dynamic SQL enables building query strings at runtime for flexible reporting, schema-agnostic operations, and bulk metadata operations. sp_executesql with parameterization prevents SQL injection while maintaining plan reuse.

**SQL Implementation & Query Plan:**
```sql
-- Safe dynamic SQL with sp_executesql — plan cache friendly
CREATE OR ALTER PROCEDURE dbo.usp_get_transactions_flexible
    @start_date   DATE,
    @end_date     DATE,
    @currency     NVARCHAR(3)    = NULL,   -- optional filter
    @status       NVARCHAR(20)   = NULL,   -- optional filter
    @min_amount   DECIMAL(18,2)  = NULL,
    @order_col    NVARCHAR(50)   = 'transaction_date',
    @order_dir    NVARCHAR(4)    = 'DESC'
AS
BEGIN
    SET NOCOUNT ON;

    -- Whitelist allowed ORDER BY columns (SQL injection prevention)
    DECLARE @safe_order NVARCHAR(50) = CASE @order_col
        WHEN 'transaction_date' THEN 'transaction_date'
        WHEN 'amount_eur' THEN 'amount_eur'
        WHEN 'customer_id' THEN 'customer_id'
        ELSE 'transaction_date'  -- default to safe column
    END;

    DECLARE @safe_dir NVARCHAR(4) = CASE UPPER(@order_dir) WHEN 'ASC' THEN 'ASC' ELSE 'DESC' END;

    DECLARE @sql NVARCHAR(MAX) = N'
        SELECT TOP 10000
            transaction_id, amount_eur, currency, status, transaction_date, customer_id
        FROM dbo.fact_transactions
        WHERE transaction_date BETWEEN @p_start AND @p_end
    ';

    -- Dynamically add optional filters
    IF @currency IS NOT NULL  SET @sql += N' AND currency = @p_currency';
    IF @status   IS NOT NULL  SET @sql += N' AND status = @p_status';
    IF @min_amount IS NOT NULL SET @sql += N' AND amount_eur >= @p_min';

    SET @sql += N' ORDER BY ' + @safe_order + ' ' + @safe_dir;

    EXEC sp_executesql @sql,
        N'@p_start DATE, @p_end DATE, @p_currency NVARCHAR(3), @p_status NVARCHAR(20), @p_min DECIMAL(18,2)',
        @p_start    = @start_date,
        @p_end      = @end_date,
        @p_currency = @currency,
        @p_status   = @status,
        @p_min      = @min_amount;
END;

-- Call from ADF Lookup activity or Power BI
EXEC dbo.usp_get_transactions_flexible
    @start_date = '2024-01-01',
    @end_date   = '2024-01-31',
    @currency   = 'EUR',
    @min_amount = 10000;
```

**Enterprise Data Scenario:**  
Flexible self-service query API for EU BFSI reporting team — Power BI parameterized data sources call this stored procedure with dynamic filters, avoiding the need to build separate queries for each report variant.

**Optimizer Invariants & Performance Traps:**
- sp_executesql with parameters reuses query plan — avoids plan cache pollution from concatenated SQL strings
- Whitelist ORDER BY column names against allowed values — dynamic ORDER BY is a common SQL injection vector
- Never concatenate user input directly into SQL string — always use @p_ parameterized variables
- IF @param IS NOT NULL pattern enables optional filters without performance degradation from OR conditions

---

### Q2.8: MERGE Statement: Upsert Pattern (DML Patterns)

**Question & Concept Overview:**  
The MERGE statement combines INSERT, UPDATE, and DELETE in a single atomic operation. It's the standard T-SQL pattern for SCD loading, idempotent ETL, and applying change data from source systems.

**SQL Implementation & Query Plan:**
```sql
-- MERGE: idempotent Silver layer upsert — safe to re-run
MERGE dbo.fact_transactions AS tgt
USING (
    -- Source: incoming batch from staging
    SELECT
        s.transaction_id,
        s.amount * ISNULL(fx.rate, 1.0) AS amount_eur,
        s.currency,
        s.status,
        s.transaction_date,
        s.customer_id,
        s.counterparty_id
    FROM dbo.stage_transactions s
    LEFT JOIN dbo.dim_fx_rates fx
        ON fx.currency = s.currency
        AND fx.rate_date = s.transaction_date
    WHERE s.batch_date = '2024-01-15'
) AS src
ON tgt.transaction_id = src.transaction_id

-- Update existing records where amount or status changed
WHEN MATCHED AND (
    tgt.status    <> src.status    OR
    ABS(tgt.amount_eur - src.amount_eur) > 0.01  -- tolerance for float comparison
) THEN
    UPDATE SET
        tgt.status        = src.status,
        tgt.amount_eur    = src.amount_eur,
        tgt._modified_ts  = GETUTCDATE()

-- Insert new records
WHEN NOT MATCHED BY TARGET THEN
    INSERT (transaction_id, amount_eur, currency, status,
            transaction_date, customer_id, counterparty_id, _load_ts)
    VALUES (src.transaction_id, src.amount_eur, src.currency, src.status,
            src.transaction_date, src.customer_id, src.counterparty_id, GETUTCDATE())

-- Log matched records that don't change (for audit completeness)
-- WHEN MATCHED AND ... THEN ... (can have multiple WHEN MATCHED)

-- Soft-delete: mark target records not in source as inactive
WHEN NOT MATCHED BY SOURCE
    AND tgt.transaction_date = '2024-01-15'  -- scope to current batch only!
THEN
    UPDATE SET tgt.is_active = 0

OUTPUT $action AS merge_action,
       inserted.transaction_id,
       deleted.amount_eur AS old_amount,
       inserted.amount_eur AS new_amount
INTO dbo.merge_audit_log (action, transaction_id, old_amount, new_amount);
```

**Enterprise Data Scenario:**  
Idempotent Silver layer upsert in the TCS EU BFSI daily batch pipeline — MERGE guarantees that re-running the same batch date produces identical results without duplicates or data corruption.

**Optimizer Invariants & Performance Traps:**
- Scope NOT MATCHED BY SOURCE with date filter — otherwise soft-deletes ALL historical records not in today's batch
- OUTPUT clause captures MERGE results for audit logging — $action returns 'INSERT', 'UPDATE', or 'DELETE'
- Multiple WHEN MATCHED clauses allowed — evaluate conditions top-to-bottom, first match wins
- ABS() tolerance on float comparison prevents spurious updates from floating-point rounding

---

### Q2.9: 7-Day Moving Average & Running Total Analytical Query (Window Functions)

**Question & Concept Overview:**  
Calculates running cumulative revenue and a rolling 7-day moving average using explicit ROWS BETWEEN window frame specifications.

**SQL Implementation & Query Plan:**
```sql
SELECT
    sale_date,
    daily_revenue_eur,
    -- Running Total: Cumulative sum from start to current row
    SUM(daily_revenue_eur) OVER (
        ORDER BY sale_date
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS running_total_revenue_eur,
    -- 7-Day Moving Average: Current row plus previous 6 rows
    AVG(daily_revenue_eur) OVER (
        ORDER BY sale_date
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ) AS moving_avg_7d_eur,
    -- Moving 7-Day Total Transaction Count
    COUNT(*) OVER (
        ORDER BY sale_date
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ) AS moving_window_count
FROM dbo.fact_daily_sales_summary
ORDER BY sale_date;
```

**Enterprise Data Scenario:**  
Financial analytics, SaaS revenue run-rates, and smoothing noisy daily telemetry on the Azure SQL Silver reporting layer.

**Optimizer Invariants & Performance Traps:**
- Always specify ROWS BETWEEN rather than RANGE BETWEEN to guarantee predictable performance and avoid tie clumping
- Notice that for the first 6 days of the dataset, AVG() smoothly averages available preceding rows (1 to 6 days)
- Explicit frame prevents expensive tempdb spooling incurred by the default RANGE specification

---

### Q2.10: Engine-Agnostic Matrix Pivoting via Conditional Aggregation (Aggregation & Grouping)

**Question & Concept Overview:**  
Transposes quarterly rows into structured columns without relying on vendor-specific PIVOT keywords, compatible across all relational and cloud platforms.

**SQL Implementation & Query Plan:**
```sql
SELECT
    department_id,
    fiscal_year,
    SUM(CASE WHEN quarter = 'Q1' THEN revenue_eur ELSE 0 END) AS q1_revenue_eur,
    SUM(CASE WHEN quarter = 'Q2' THEN revenue_eur ELSE 0 END) AS q2_revenue_eur,
    SUM(CASE WHEN quarter = 'Q3' THEN revenue_eur ELSE 0 END) AS q3_revenue_eur,
    SUM(CASE WHEN quarter = 'Q4' THEN revenue_eur ELSE 0 END) AS q4_revenue_eur,
    SUM(revenue_eur) AS total_annual_revenue_eur
FROM dbo.fact_department_financials
GROUP BY department_id, fiscal_year
ORDER BY fiscal_year DESC, department_id ASC;
```

**Enterprise Data Scenario:**  
Financial quarterly rollups, cohort analysis, and transposing EAV (Entity-Attribute-Value) models for Power BI matrix visual consumption.

**Optimizer Invariants & Performance Traps:**
- Works identically across SQL Server, PostgreSQL, MySQL, Oracle, Snowflake, BigQuery, and Spark SQL
- Using SUM(CASE ...) is cleaner, faster, and more flexible than proprietary PIVOT syntax when combining multiple aggregations
- Easily extended with FILTER (WHERE ...) clause in modern PostgreSQL / DuckDB

---

### Q2.11: Deduplication with Earliest Record Preservation using CTE (Data Quality & Cleansing)

**Question & Concept Overview:**  
Eliminates duplicate entities across business keys while preserving the earliest original record using ROW_NUMBER() and a Common Table Expression.

**SQL Implementation & Query Plan:**
```sql
WITH ranked_duplicates AS (
    SELECT
        customer_sk,
        customer_id,
        email,
        created_at,
        ROW_NUMBER() OVER (
            PARTITION BY email
            ORDER BY created_at ASC, customer_sk ASC
        ) AS duplicate_rank
    FROM dbo.dim_customers
)
DELETE FROM ranked_duplicates
WHERE duplicate_rank > 1;

-- Verify zero duplicates remain
SELECT email, COUNT(*)
FROM dbo.dim_customers
GROUP BY email
HAVING COUNT(*) > 1;
```

**Enterprise Data Scenario:**  
Silver-layer customer Master Data Management (MDM) deduplication and CRM reconciliation pipelines.

**Optimizer Invariants & Performance Traps:**
- T-SQL and PostgreSQL allow direct DELETE operations through Common Table Expressions
- ORDER BY created_at ASC preserves the first seen record; DESC would preserve the most recent record
- For tables > 500,000 rows, combine with chunked deletion to prevent lock escalation

---

### Q2.12: SARGable Date Range Filtering vs Date Functions (Query Optimization)

**Question & Concept Overview:**  
Demonstrates writing Search Argument Able (SARGable) date boundary queries that utilize B-tree index seeks rather than forcing full clustered index scans.

**SQL Implementation & Query Plan:**
```sql
-- ❌ Non-SARGable Antipattern (forces full clustered index scan)
SELECT OrderID, CustomerID, OrderDate, TotalAmount
FROM dbo.Orders
WHERE YEAR(OrderDate) = 2024 AND MONTH(OrderDate) = 6;

-- ✅ SARGable Production Pattern (enables logarithmic index seek)
SELECT OrderID, CustomerID, OrderDate, TotalAmount
FROM dbo.Orders
WHERE OrderDate >= '2024-06-01'
  AND OrderDate < '2024-07-01';
```

**Enterprise Data Scenario:**  
Production report and ETL queries filtering time-series or transactional records by month/year.

**Optimizer Invariants & Performance Traps:**
- Wrapping OrderDate in YEAR() and MONTH() requires the engine to evaluate the scalar function for every row in the table.
- Half-open interval (>= start AND < next_month) correctly handles datetime2 and datetime fractional second precision.
- Saves 90%+ CPU time and disk I/O on tables exceeding 1 million rows.

---

### Q2.13: CTEs (Common Table Expressions) in Spark SQL (Query Structuring)

**Question & Concept Overview:**  
CTEs (WITH clauses) improve query readability and maintainability by naming intermediate result sets. Spark SQL supports multiple CTEs in a single WITH block and recursive CTEs. In BFSI pipelines, CTEs help decompose complex multi-step transformations into readable, testable units.

**SQL Implementation & Query Plan:**
```sql
-- =============================================
-- CTEs for Complex BFSI Analytics
-- AML Transaction Monitoring Pipeline
-- =============================================

USE CATALOG eu_bfsi_prod;
USE SCHEMA gold;

WITH
-- CTE 1: Base transaction data with FX normalization
normalized_txns AS (
    SELECT
        t.txn_id,
        t.account_id,
        t.txn_amount,
        t.txn_currency,
        t.txn_amount * COALESCE(fx.exchange_rate, 1.0)  AS amount_eur,
        t.txn_type,
        t.txn_timestamp,
        DATE(t.txn_timestamp)                            AS txn_date,
        t.counterparty_country,
        t.source_system
    FROM eu_bfsi_prod.silver.silver_transactions t
    LEFT JOIN eu_bfsi_prod.silver.silver_fx_rates fx
        ON t.txn_currency = fx.from_currency
        AND DATE(t.txn_timestamp) = fx.rate_date
        AND fx.to_currency = 'EUR'
    WHERE t.txn_date BETWEEN '2024-01-01' AND '2024-12-31'
      AND t.txn_status = 'COMPLETED'
),

-- CTE 2: Daily account aggregates
daily_account_aggregates AS (
    SELECT
        account_id,
        txn_date,
        COUNT(*)                    AS txn_count,
        SUM(amount_eur)             AS daily_debit_eur,
        MAX(amount_eur)             AS max_single_txn_eur,
        COUNT(DISTINCT counterparty_country) AS unique_countries
    FROM normalized_txns
    WHERE txn_type = 'DEBIT'
    GROUP BY account_id, txn_date
),

-- CTE 3: Accounts with high-risk patterns
high_risk_accounts AS (
    SELECT
        account_id,
        AVG(daily_debit_eur)        AS avg_daily_debit,
        MAX(daily_debit_eur)        AS peak_daily_debit,
        SUM(txn_count)              AS total_txns,
        MAX(unique_countries)       AS max_countries_in_day
    FROM daily_account_aggregates
    GROUP BY account_id
    HAVING  AVG(daily_debit_eur) > 50000
        OR  MAX(unique_countries) >= 5
        OR  MAX(daily_debit_eur)  > 250000
),

-- CTE 4: Account profile enrichment
account_profile AS (
    SELECT
        a.account_id,
        a.customer_id,
        a.account_type,
        a.risk_tier,
        c.customer_name,
        c.nationality,
        c.pep_flag,         -- Politically Exposed Person
        c.sanction_flag
    FROM eu_bfsi_prod.silver.silver_accounts a
    JOIN eu_bfsi_prod.silver.silver_customers c
        ON a.customer_id = c.customer_id
)

-- Final output: AML alert candidates
SELECT
    hr.account_id,
    ap.customer_name,
    ap.nationality,
    ap.pep_flag,
    ap.sanction_flag,
    ap.risk_tier,
    hr.avg_daily_debit,
    hr.peak_daily_debit,
    hr.total_txns,
    hr.max_countries_in_day,
    CASE
        WHEN ap.sanction_flag = true         THEN 'CRITICAL'
        WHEN ap.pep_flag = true              THEN 'HIGH'
        WHEN hr.peak_daily_debit > 500000   THEN 'HIGH'
        WHEN hr.max_countries_in_day >= 10  THEN 'MEDIUM'
        ELSE                                     'LOW'
    END                                     AS alert_priority,
    current_timestamp()                     AS alert_generated_ts
FROM high_risk_accounts hr
JOIN account_profile ap ON hr.account_id = ap.account_id
ORDER BY alert_priority, hr.peak_daily_debit DESC;
```

**Enterprise Data Scenario:**  
AML transaction monitoring pipeline at a pan-European retail bank — CTEs decompose the complex multi-join, multi-aggregation alert generation query into readable stages that can be individually unit-tested and reviewed by compliance teams.

**Optimizer Invariants & Performance Traps:**
- CTEs are not materialized by default in Spark — they are inlined into the query plan; use temp views for reuse across multiple queries
- Multiple CTEs in one WITH block are separated by commas — later CTEs can reference earlier ones
- CTEs vastly improve query readability vs deeply nested subqueries — prefer them in code reviews
- For expensive intermediate results reused multiple times, consider CACHE TABLE or a temp view materialization
- Spark SQL supports recursive CTEs (WITH RECURSIVE) since Spark 3.4 — useful for hierarchy traversal

---

### Q2.14: Window Functions in Spark SQL (Analytical Functions)

**Question & Concept Overview:**  
Window functions perform calculations across a set of rows related to the current row without collapsing the result set. Essential for running totals, rankings, lag/lead comparisons, and period-over-period analytics in financial reporting. Spark SQL implements the full ANSI SQL window function standard.

**SQL Implementation & Query Plan:**
```sql
-- =============================================
-- Window Functions — EU Banking Analytics
-- Account Balance & Transaction Trend Analysis
-- =============================================

USE CATALOG eu_bfsi_prod;
USE SCHEMA gold;

SELECT
    account_id,
    txn_date,
    txn_id,
    txn_amount,
    txn_type,

    -- RANKING functions
    ROW_NUMBER() OVER (
        PARTITION BY account_id
        ORDER BY txn_timestamp DESC
    )                                               AS txn_recency_rank,

    RANK() OVER (
        PARTITION BY account_id, MONTH(txn_date)
        ORDER BY txn_amount DESC
    )                                               AS monthly_amount_rank,

    DENSE_RANK() OVER (
        PARTITION BY account_id
        ORDER BY DATE(txn_date)
    )                                               AS day_sequence,

    -- VALUE functions: LAG / LEAD
    LAG(txn_amount, 1, 0) OVER (
        PARTITION BY account_id
        ORDER BY txn_timestamp
    )                                               AS prev_txn_amount,

    txn_amount - LAG(txn_amount, 1, 0) OVER (
        PARTITION BY account_id
        ORDER BY txn_timestamp
    )                                               AS amount_delta_from_prev,

    LEAD(txn_date, 1) OVER (
        PARTITION BY account_id
        ORDER BY txn_timestamp
    )                                               AS next_txn_date,

    -- AGGREGATE window functions
    SUM(txn_amount) OVER (
        PARTITION BY account_id
        ORDER BY txn_timestamp
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    )                                               AS running_total,

    AVG(txn_amount) OVER (
        PARTITION BY account_id
        ORDER BY txn_date
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    )                                               AS rolling_7day_avg,

    SUM(txn_amount) OVER (
        PARTITION BY account_id, YEAR(txn_date), MONTH(txn_date)
    )                                               AS monthly_total,

    -- FIRST_VALUE / LAST_VALUE
    FIRST_VALUE(txn_amount) OVER (
        PARTITION BY account_id, DATE(txn_date)
        ORDER BY txn_timestamp
        ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
    )                                               AS first_txn_of_day,

    LAST_VALUE(txn_amount) OVER (
        PARTITION BY account_id, DATE(txn_date)
        ORDER BY txn_timestamp
        ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
    )                                               AS last_txn_of_day,

    -- NTILE: Quartile bucketing
    NTILE(4) OVER (
        PARTITION BY YEAR(txn_date)
        ORDER BY txn_amount
    )                                               AS amount_quartile,

    -- PERCENT_RANK / CUME_DIST
    ROUND(PERCENT_RANK() OVER (
        PARTITION BY account_id
        ORDER BY txn_amount
    ), 4)                                           AS pct_rank_in_account,

    ROUND(CUME_DIST() OVER (
        ORDER BY txn_amount
    ), 4)                                           AS cumulative_distribution

FROM eu_bfsi_prod.silver.silver_transactions
WHERE txn_date BETWEEN '2024-01-01' AND '2024-12-31'
  AND txn_status = 'COMPLETED'
  AND txn_type = 'DEBIT'
QUALIFY txn_recency_rank <= 10;  -- Databricks-specific: filter on window result
```

**Enterprise Data Scenario:**  
A European investment bank's risk analytics team calculating rolling 7-day average transaction amounts and running totals per account to detect structuring patterns (breaking large transactions into smaller ones to evade AML thresholds) — window functions make this a single-pass SQL query.

**Optimizer Invariants & Performance Traps:**
- PARTITION BY is optional — omitting it makes the window span the entire dataset (use carefully on large tables)
- ROWS BETWEEN vs RANGE BETWEEN: ROWS is physical (N rows before/after), RANGE is logical (based on ORDER BY value)
- QUALIFY clause (Databricks extension) filters on window function results without a subquery wrapper
- LAG/LEAD default value (3rd parameter) prevents NULL in first/last rows — always provide defaults for financial calcs
- Window functions are computed after WHERE/GROUP BY/HAVING but before ORDER BY and LIMIT

---

### Q2.15: Complex Types: Arrays, Maps, Structs — EXPLODE, COLLECT_LIST (Complex Data Types)

**Question & Concept Overview:**  
Spark SQL's support for nested data types (ARRAY, MAP, STRUCT) enables working with semi-structured data natively without denormalization. EXPLODE converts arrays/maps into rows, while COLLECT_LIST/COLLECT_SET aggregate rows back into arrays. Critical for processing JSON-based financial messages.

**SQL Implementation & Query Plan:**
```sql
-- =============================================
-- Complex Types in Spark SQL
-- EU BFSI — SWIFT & Trade Finance Messages
-- =============================================

USE CATALOG eu_bfsi_prod;
USE SCHEMA silver;

-- 1. Querying STRUCT fields (dot notation)
SELECT
    txn_id,
    counterparty.bank_name                  AS cp_bank,
    counterparty.bic_code                   AS cp_bic,
    counterparty.country                    AS cp_country,
    amount_details.value                    AS txn_value,
    amount_details.currency                 AS txn_currency,
    amount_details.fx_rate                  AS applied_rate
FROM silver_swift_mt103
WHERE counterparty.country NOT IN ('GB', 'US', 'EU')
  AND amount_details.value > 100000;

-- 2. EXPLODE array — one row per array element
SELECT
    trade_id,
    leg_idx,               -- Position in original array
    leg.leg_type           AS leg_type,
    leg.notional           AS leg_notional,
    leg.currency           AS leg_currency,
    leg.maturity_date      AS leg_maturity
FROM silver_trade_legs
LATERAL VIEW POSEXPLODE(trade_legs) AS leg_idx, leg
WHERE leg.leg_type IN ('FIXED', 'FLOATING');

-- 3. EXPLODE map — one row per key-value pair
SELECT
    account_id,
    attr_key,
    attr_value
FROM silver_account_attributes
LATERAL VIEW EXPLODE(attribute_map) AS attr_key, attr_value
WHERE attr_key IN ('RISK_TIER', 'KYC_STATUS', 'PRODUCT_CODE');

-- 4. COLLECT_LIST — aggregate rows into array
SELECT
    account_id,
    COLLECT_LIST(txn_id)                    AS all_txn_ids,
    COLLECT_LIST(
        STRUCT(txn_id, txn_amount, txn_date)
    )                                       AS txn_details,
    SIZE(COLLECT_LIST(txn_id))              AS txn_count,
    COLLECT_SET(txn_currency)               AS unique_currencies,
    ARRAY_SORT(COLLECT_SET(counterparty_country)) AS countries_dealt_with
FROM silver_transactions
WHERE txn_date >= '2024-01-01'
GROUP BY account_id;

-- 5. Array manipulation functions
SELECT
    account_id,
    flagged_txn_ids,
    ARRAY_CONTAINS(flagged_txn_ids, '${alert_txn_id}')   AS in_alert_list,
    ARRAY_SIZE(flagged_txn_ids)                           AS flag_count,
    FILTER(flagged_txn_ids, x -> x LIKE 'TXN-EU%')       AS eu_flagged_only,
    TRANSFORM(txn_amounts, x -> x * 1.20)                AS amounts_with_vat,
    AGGREGATE(txn_amounts, 0D, (acc, x) -> acc + x)      AS total_amount,
    FLATTEN(ARRAY(txn_ids_q1, txn_ids_q2, txn_ids_q3, txn_ids_q4)) AS all_year_txns
FROM silver_account_summary;

-- 6. Struct construction and from_json
SELECT
    txn_id,
    STRUCT(
        account_id      AS account,
        txn_amount      AS amount,
        txn_currency    AS currency
    )                                       AS txn_core_struct,
    FROM_JSON(
        raw_payload,
        'STRUCT<sender_bic:STRING, receiver_bic:STRING, ref:STRING>'
    )                                       AS parsed_payload
FROM bronze_transactions;
```

**Enterprise Data Scenario:**  
Processing SWIFT MT103 and ISO 20022 trade finance messages at a European correspondent bank — JSON payloads with nested arrays of trade legs and MAP-typed attribute collections are parsed and exploded in the silver layer transformation pipeline.

**Optimizer Invariants & Performance Traps:**
- POSEXPLODE returns both the index and the element — use it when array position matters (e.g., trade legs order)
- COLLECT_LIST preserves duplicates; COLLECT_SET removes them — choose based on whether deduplication is needed
- FILTER, TRANSFORM, AGGREGATE are higher-order functions that accept lambda expressions — powerful for array operations
- from_json/to_json enable parsing JSON strings into typed structs without exploding to rows
- Struct columns support dot notation for field access — nested structs can be chained: col.nested.field

---

### Q2.16: JOIN Types in Spark SQL (Query Structuring)

**Question & Concept Overview:**  
Spark SQL supports all standard SQL JOIN types plus Spark-specific extensions. Understanding join strategies (broadcast, shuffle hash, sort merge) is critical for performance in large-scale BFSI joins between fact and dimension tables. The USING clause simplifies equi-joins on identically named columns.

**SQL Implementation & Query Plan:**
```sql
-- =============================================
-- JOIN Patterns in EU BFSI Analytics
-- Transaction Enrichment Pipeline
-- =============================================

USE CATALOG eu_bfsi_prod;
USE SCHEMA gold;

-- 1. INNER JOIN — most common, only matching rows
SELECT
    t.txn_id,
    t.account_id,
    t.txn_amount,
    a.account_type,
    a.risk_tier,
    c.customer_name
FROM silver_transactions t
INNER JOIN silver_accounts a ON t.account_id = a.account_id
INNER JOIN silver_customers c ON a.customer_id = c.customer_id
WHERE t.txn_date = current_date();

-- 2. LEFT JOIN — keep all transactions, enrich where possible
SELECT
    t.txn_id,
    t.txn_amount,
    t.txn_currency,
    COALESCE(fx.exchange_rate, 1.0)     AS fx_rate,
    t.txn_amount * COALESCE(fx.exchange_rate, 1.0) AS amount_eur
FROM silver_transactions t
LEFT JOIN silver_fx_rates fx
    ON t.txn_currency = fx.from_currency
    AND DATE(t.txn_timestamp) = fx.rate_date
    AND fx.to_currency = 'EUR';

-- 3. ANTI JOIN — find unmatched records (data quality)
SELECT t.txn_id, t.account_id, t.txn_amount
FROM bronze_transactions t
LEFT ANTI JOIN silver_transactions s ON t.txn_id = s.txn_id
WHERE t.ingestion_date = current_date();
-- Finds bronze records not yet promoted to silver

-- 4. SEMI JOIN — filter on existence (no columns from right side)
SELECT account_id, customer_id, risk_tier
FROM silver_accounts
WHERE account_id IN (
    SELECT DISTINCT account_id
    FROM silver_transactions
    WHERE txn_amount > 1000000
      AND txn_date >= '2024-01-01'
);
-- Equivalent SEMI JOIN syntax:
SELECT a.account_id, a.customer_id, a.risk_tier
FROM silver_accounts a
LEFT SEMI JOIN silver_transactions t
    ON a.account_id = t.account_id
    AND t.txn_amount > 1000000
    AND t.txn_date >= '2024-01-01';

-- 5. CROSS JOIN — use with extreme caution (Cartesian product)
SELECT
    c.currency_code,
    r.region_code,
    CONCAT(c.currency_code, '_', r.region_code) AS segment_key
FROM dim_currency c
CROSS JOIN dim_region r;  -- Safe only on small dimension tables

-- 6. USING clause — same-named column equi-join
SELECT t.txn_id, t.txn_amount, a.account_type
FROM silver_transactions t
JOIN silver_accounts a USING (account_id);

-- 7. NON-EQUI JOIN — join with range condition
SELECT
    t.txn_id,
    t.txn_amount,
    r.risk_category
FROM silver_transactions t
JOIN dim_amount_risk_bands r
    ON t.txn_amount BETWEEN r.min_amount AND r.max_amount
    AND t.txn_currency = r.currency;

-- 8. FULL OUTER JOIN — reconciliation pattern
SELECT
    COALESCE(s.txn_id, t.txn_id)           AS txn_id,
    s.txn_amount                            AS source_amount,
    t.txn_amount                            AS target_amount,
    s.txn_amount - t.txn_amount             AS variance,
    CASE
        WHEN s.txn_id IS NULL THEN 'TARGET_ONLY'
        WHEN t.txn_id IS NULL THEN 'SOURCE_ONLY'
        ELSE 'MATCHED'
    END                                     AS reconciliation_status
FROM silver_source_transactions s
FULL OUTER JOIN silver_target_transactions t ON s.txn_id = t.txn_id;
```

**Enterprise Data Scenario:**  
Transaction enrichment pipeline in a European bank's silver layer — LEFT JOINs add FX rates and account details while ANTI JOINs identify bronze records that failed silver promotion, enabling automated re-processing alerts in the monitoring dashboard.

**Optimizer Invariants & Performance Traps:**
- ANTI JOIN and SEMI JOIN are Spark SQL extensions — they're highly efficient because the right table is only used for filtering
- Broadcast join is automatically chosen when one side is small (<= spark.sql.autoBroadcastJoinThreshold, default 10MB)
- FULL OUTER JOIN is the reconciliation pattern — ideal for source-to-target data quality checks
- Non-equi joins (BETWEEN, >, <) cannot use hash join — Spark falls back to sort-merge join, which can be expensive
- The USING clause automatically deduplicates the join column in the output — the ON clause keeps both sides

---

### Q2.17: GROUP BY Extensions: ROLLUP, CUBE, GROUPING SETS (Analytical Functions)

**Question & Concept Overview:**  
ROLLUP, CUBE, and GROUPING SETS are SQL extensions that generate multiple levels of aggregation in a single query pass. Essential for financial reporting where subtotals, grand totals, and cross-dimensional summaries are needed simultaneously — replacing multiple UNION ALL queries with a single, efficient operation.

**SQL Implementation & Query Plan:**
```sql
-- =============================================
-- GROUP BY Extensions — EU BFSI Regulatory Reporting
-- EBA COREP / FINREP Multi-dimensional Aggregation
-- =============================================

USE CATALOG eu_bfsi_prod;
USE SCHEMA gold;

-- 1. ROLLUP — hierarchical subtotals (right-to-left)
-- Produces: (region, country, currency), (region, country), (region), ()
SELECT
    COALESCE(region, 'ALL_REGIONS')         AS region,
    COALESCE(country_code, 'ALL_COUNTRIES') AS country_code,
    COALESCE(txn_currency, 'ALL_CURRENCIES') AS txn_currency,
    SUM(txn_amount_eur)                     AS total_amount_eur,
    COUNT(DISTINCT txn_id)                  AS txn_count,
    COUNT(DISTINCT account_id)              AS unique_accounts,
    GROUPING(region)                        AS is_region_subtotal,
    GROUPING(country_code)                  AS is_country_subtotal,
    GROUPING(txn_currency)                  AS is_currency_subtotal,
    GROUPING_ID(region, country_code, txn_currency) AS grouping_level
FROM gold_txn_summary
WHERE report_period = '2024-Q4'
GROUP BY ROLLUP(region, country_code, txn_currency)
ORDER BY grouping_level DESC, region, country_code, txn_currency;

-- 2. CUBE — all combinations of GROUP BY columns
-- Produces every combination: 2^N grouping sets for N columns
SELECT
    COALESCE(txn_type, 'ALL')               AS txn_type,
    COALESCE(risk_tier, 'ALL')              AS risk_tier,
    COALESCE(product_code, 'ALL')           AS product_code,
    SUM(txn_amount_eur)                     AS total_eur,
    AVG(txn_amount_eur)                     AS avg_eur,
    COUNT(*)                                AS txn_count
FROM gold_txn_summary
GROUP BY CUBE(txn_type, risk_tier, product_code)
HAVING SUM(txn_amount_eur) > 1000000
ORDER BY GROUPING_ID(txn_type, risk_tier, product_code) DESC;

-- 3. GROUPING SETS — explicit control over which combinations
-- For FINREP: need (country), (product), (country, product), and grand total
SELECT
    country_code,
    product_code,
    txn_currency,
    SUM(exposure_amount_eur)                AS total_exposure,
    COUNT(DISTINCT counterparty_id)         AS counterparty_count,
    GROUPING_ID(country_code, product_code, txn_currency) AS grp_id
FROM gold_regulatory_exposure
WHERE reporting_date = '2024-12-31'
GROUP BY GROUPING SETS (
    (country_code),
    (product_code),
    (txn_currency),
    (country_code, product_code),
    (country_code, txn_currency),
    ()  -- Grand total row
)
ORDER BY grp_id DESC, total_exposure DESC;
```

**Enterprise Data Scenario:**  
Generating EBA FINREP regulatory exposure reports for a pan-European bank — GROUPING SETS produces country-level, product-level, and grand-total summaries in a single optimized query, replacing the 5 separate UNION ALL queries that previously caused the daily reporting job to exceed the SLA window.

**Optimizer Invariants & Performance Traps:**
- GROUPING() returns 1 if column is aggregated (subtotal row), 0 if it's a detail row — use with COALESCE for labeling
- GROUPING_ID() returns a bit-mask integer identifying which columns are aggregated — useful for downstream filtering
- ROLLUP(a, b, c) is equivalent to GROUPING SETS ((a,b,c),(a,b),(a),()) — N+1 sets for N columns
- CUBE(a,b,c) generates 2^N grouping sets — use GROUPING SETS for explicit control to avoid unnecessary computation
- These extensions are critical for single-pass generation of regulatory reports (COREP, FINREP, EMIR) at multiple hierarchy levels

---

### Q2.18: PIVOT and UNPIVOT in Spark SQL (Analytical Functions)

**Question & Concept Overview:**  
PIVOT rotates rows into columns, transforming long-format data into wide-format reports. UNPIVOT is the reverse operation. These are essential for financial matrix reports, period-over-period comparisons, and cross-tabulation reporting required by regulatory bodies.

**SQL Implementation & Query Plan:**
```sql
-- =============================================
-- PIVOT / UNPIVOT — EU BFSI Reporting
-- Monthly P&L and Exposure Matrix Reports
-- =============================================

USE CATALOG eu_bfsi_prod;
USE SCHEMA gold;

-- 1. PIVOT: Monthly transaction volumes by product type
SELECT *
FROM (
    SELECT
        account_id,
        DATE_FORMAT(txn_date, 'MMM-yyyy')   AS txn_month,
        product_code,
        txn_amount_eur
    FROM gold_txn_summary
    WHERE txn_date BETWEEN '2024-01-01' AND '2024-12-31'
)
PIVOT (
    ROUND(SUM(txn_amount_eur) / 1000000, 2) AS vol_meur  -- Millions EUR
    FOR product_code IN (
        'MORTGAGE'  AS mortgage,
        'PERSONAL'  AS personal_loan,
        'CURRENT'   AS current_acct,
        'SAVINGS'   AS savings_acct,
        'TRADE_FIN' AS trade_finance,
        'FX_SPOT'   AS fx_spot
    )
);
-- Output columns: account_id, txn_month, mortgage, personal_loan, ...

-- 2. PIVOT with multiple aggregations per column
SELECT *
FROM (
    SELECT country_code, risk_tier, txn_amount_eur
    FROM gold_regulatory_exposure
    WHERE reporting_date = '2024-12-31'
)
PIVOT (
    ROUND(SUM(txn_amount_eur)/1e9, 2)   AS sum_geur,
    COUNT(*)                            AS cnt
    FOR risk_tier IN ('LOW' AS low, 'MEDIUM' AS med, 'HIGH' AS high, 'CRITICAL' AS crit)
);
-- Output: country_code, low_sum_geur, low_cnt, med_sum_geur, med_cnt, ...

-- 3. Dynamic PIVOT (using Spark SQL + Python wrapper)
-- Note: Spark SQL PIVOT requires static column list
-- For dynamic pivoting, generate SQL in PySpark:
/*
pivot_cols = spark.sql("""
    SELECT DISTINCT risk_tier FROM gold_regulatory_exposure
    WHERE reporting_date = '2024-12-31'
    ORDER BY risk_tier
""").rdd.flatMap(lambda x: x).collect()

pivot_expr = ', '.join([f"'{col}' AS {col.lower().replace(' ','_')}" for col in pivot_cols])
dynamic_pivot_sql = f"""
    SELECT * FROM (
        SELECT country_code, risk_tier, txn_amount_eur
        FROM gold_regulatory_exposure WHERE reporting_date = '2024-12-31'
    ) PIVOT (SUM(txn_amount_eur) FOR risk_tier IN ({pivot_expr}))
"""
result = spark.sql(dynamic_pivot_sql)
*/

-- 4. UNPIVOT: Wide → Long format
SELECT account_id, metric_name, metric_value
FROM (
    SELECT
        account_id,
        balance_current,
        balance_savings,
        balance_loan,
        credit_limit
    FROM gold_account_balances
    WHERE snapshot_date = '2024-12-31'
)
UNPIVOT (
    metric_value FOR metric_name IN (
        balance_current  AS 'CURRENT_BALANCE',
        balance_savings  AS 'SAVINGS_BALANCE',
        balance_loan     AS 'LOAN_BALANCE',
        credit_limit     AS 'CREDIT_LIMIT'
    )
)
WHERE metric_value IS NOT NULL;
```

**Enterprise Data Scenario:**  
Building an EBA COREP capital adequacy matrix report for a European universal bank — PIVOT transforms long-format risk exposure data (one row per country-tier) into the wide-format matrix table (countries as rows, risk tiers as columns) required by the regulatory submission template.

**Optimizer Invariants & Performance Traps:**
- PIVOT requires specifying column values statically in SQL — use PySpark to generate dynamic pivot SQL for unknown categories
- PIVOT with multiple aggregate functions generates N*M columns (N pivot values × M aggregations) — keep combinations manageable
- UNPIVOT is essentially a structured STACK operation — equivalent to multiple UNION ALLs but more readable
- Pivoted DataFrames are often used to feed Power BI or Excel-based reports via JDBC/ODBC Databricks SQL endpoints
- Consider materialized gold views for pivoted reporting tables — avoids re-running expensive pivots on every report query

---

### Q2.19: Date and Timestamp Functions (Spark SQL Functions)

**Question & Concept Overview:**  
Date and timestamp handling is critical in BFSI for interest calculations, period-end reporting, settlement date computations, and timezone normalization. Spark SQL provides a rich set of date functions fully compatible with ANSI SQL, plus Databricks-specific extensions for timezone-aware operations.

**SQL Implementation & Query Plan:**
```sql
-- =============================================
-- Date & Timestamp Functions
-- EU BFSI — Reporting Period & Settlement Calcs
-- =============================================

USE CATALOG eu_bfsi_prod;
USE SCHEMA silver;

SELECT
    txn_id,
    txn_timestamp,

    -- ── Current values ──────────────────────
    current_date()                          AS today,
    current_timestamp()                     AS now_utc,
    now()                                   AS now_alias,

    -- ── Extraction ──────────────────────────
    YEAR(txn_timestamp)                     AS txn_year,
    MONTH(txn_timestamp)                    AS txn_month,
    DAY(txn_timestamp)                      AS txn_day,
    DAYOFWEEK(txn_timestamp)                AS day_of_week,  -- 1=Sun
    DAYOFYEAR(txn_timestamp)                AS day_of_year,
    WEEKOFYEAR(txn_timestamp)               AS week_number,
    QUARTER(txn_timestamp)                  AS txn_quarter,
    HOUR(txn_timestamp)                     AS txn_hour,
    MINUTE(txn_timestamp)                   AS txn_minute,

    -- ── Formatting ──────────────────────────
    DATE_FORMAT(txn_timestamp, 'yyyy-MM-dd')            AS date_str,
    DATE_FORMAT(txn_timestamp, 'dd/MM/yyyy HH:mm:ss')   AS eu_datetime_str,
    DATE_FORMAT(txn_timestamp, 'MMM yyyy')              AS month_label,
    TO_DATE(txn_timestamp)                              AS date_only,

    -- ── Arithmetic ──────────────────────────
    DATE_ADD(txn_timestamp, 2)              AS value_date_t2,   -- T+2 settlement
    DATE_ADD(txn_timestamp, 30)             AS payment_due,
    DATE_SUB(txn_timestamp, 1)              AS prev_business_approx,
    ADD_MONTHS(txn_timestamp, 3)            AS quarterly_review,
    ADD_MONTHS(LAST_DAY(txn_timestamp), 1)  AS next_month_end,
    LAST_DAY(txn_timestamp)                 AS month_end,
    TRUNC(txn_timestamp, 'MM')              AS month_start,
    TRUNC(txn_timestamp, 'YEAR')            AS year_start,
    TRUNC(txn_timestamp, 'DD')              AS start_of_day,

    -- ── Differences ─────────────────────────
    DATEDIFF(current_date(), DATE(txn_timestamp))       AS days_since_txn,
    MONTHS_BETWEEN(current_date(), DATE(txn_timestamp)) AS months_since_txn,

    -- ── Timezone Conversion ──────────────────
    CONVERT_TIMEZONE('UTC', 'Europe/London', txn_timestamp)  AS ts_london,
    CONVERT_TIMEZONE('UTC', 'Europe/Paris',  txn_timestamp)  AS ts_paris,
    FROM_UTC_TIMESTAMP(txn_timestamp, 'Europe/Berlin')       AS ts_berlin,
    TO_UTC_TIMESTAMP(txn_timestamp, 'Europe/Warsaw')         AS back_to_utc,

    -- ── Unix timestamps ──────────────────────
    UNIX_TIMESTAMP(txn_timestamp)           AS epoch_seconds,
    FROM_UNIXTIME(epoch_timestamp)          AS from_epoch,
    TIMESTAMP_MILLIS(epoch_millis)          AS from_millis,

    -- ── Parsing ─────────────────────────────
    TO_TIMESTAMP('31/12/2024 23:59:59', 'dd/MM/yyyy HH:mm:ss') AS parsed_ts,
    TO_DATE('31-12-2024', 'dd-MM-yyyy')                         AS parsed_date,
    TRY_TO_TIMESTAMP('not-a-date', 'yyyy-MM-dd')                AS safe_parse  -- Returns NULL

FROM silver_transactions
WHERE txn_date = current_date() - INTERVAL 1 DAY;  -- Yesterday's transactions
```

**Enterprise Data Scenario:**  
SEPA Direct Debit settlement date calculation engine at a European payment institution — T+2 settlement dates, CET business day reporting windows, and end-of-month position snapshots all require precise date arithmetic with timezone awareness for cross-border EUR/GBP/CHF transactions.

**Optimizer Invariants & Performance Traps:**
- All Databricks timestamps are stored in UTC — always use CONVERT_TIMEZONE for European reporting (CET/CEST shift)
- TRUNC(ts, 'MM') gives first day of month — essential for monthly report period boundaries
- DATE_ADD operates on calendar days; business day calculations require a custom calendar table join
- TRY_TO_TIMESTAMP / TRY_CAST return NULL on parse failure instead of throwing — always prefer in ETL
- MONTHS_BETWEEN returns a decimal — ROUND to integer for whole-month differences in interest calculations

---

### Q2.20: Delta Lake DML: MERGE INTO, UPDATE, DELETE (Delta Lake DML)

**Question & Concept Overview:**  
Delta Lake's ACID DML operations (MERGE, UPDATE, DELETE) enable true data warehouse semantics on the data lake. MERGE INTO is the most powerful — implementing upsert, delete, and conditional insert in a single atomic operation. These replace complex partition-swap workarounds previously needed with plain Parquet.

**SQL Implementation & Query Plan:**
```sql
-- =============================================
-- Delta Lake DML Operations
-- EU BFSI — Account & Transaction Management
-- =============================================

USE CATALOG eu_bfsi_prod;
USE SCHEMA silver;

-- ─────────────────────────────────────────────
-- 1. UPDATE — Correct account risk tiers
-- ─────────────────────────────────────────────
UPDATE silver_accounts
SET
    risk_tier           = 'HIGH',
    risk_review_date    = current_date(),
    updated_by          = current_user(),
    updated_ts          = current_timestamp()
WHERE account_id IN (
    SELECT DISTINCT account_id
    FROM silver_aml_alerts
    WHERE alert_date >= current_date() - INTERVAL 30 DAYS
      AND alert_severity = 'CRITICAL'
      AND alert_status = 'CONFIRMED'
);

-- ─────────────────────────────────────────────
-- 2. DELETE — GDPR right-to-erasure
-- ─────────────────────────────────────────────
DELETE FROM silver_customer_pii
WHERE customer_id IN (
    SELECT customer_id
    FROM gold_erasure_requests
    WHERE request_status = 'APPROVED'
      AND approved_date <= current_date()
);

-- ─────────────────────────────────────────────
-- 3. MERGE INTO — Full upsert (SCD Type 1)
-- Scenario: Intra-day account balance refresh
-- ─────────────────────────────────────────────
MERGE INTO silver_accounts AS target
USING (
    SELECT
        account_id,
        current_balance,
        available_balance,
        credit_limit,
        account_status,
        last_activity_date,
        current_timestamp() AS source_ts
    FROM bronze_account_snapshot
    WHERE snapshot_date = current_date()
      AND batch_id = '${latest_batch_id}'
) AS source
ON target.account_id = source.account_id

WHEN MATCHED AND target.account_status != source.account_status THEN
    UPDATE SET
        target.current_balance    = source.current_balance,
        target.available_balance  = source.available_balance,
        target.account_status     = source.account_status,
        target.last_activity_date = source.last_activity_date,
        target.updated_ts         = source.source_ts

WHEN MATCHED AND (
    target.current_balance   != source.current_balance  OR
    target.available_balance != source.available_balance
) THEN
    UPDATE SET
        target.current_balance    = source.current_balance,
        target.available_balance  = source.available_balance,
        target.last_activity_date = source.last_activity_date,
        target.updated_ts         = source.source_ts

WHEN NOT MATCHED THEN
    INSERT (
        account_id, current_balance, available_balance,
        credit_limit, account_status, last_activity_date,
        created_ts, updated_ts
    )
    VALUES (
        source.account_id, source.current_balance, source.available_balance,
        source.credit_limit, source.account_status, source.last_activity_date,
        source.source_ts, source.source_ts
    )

WHEN NOT MATCHED BY SOURCE AND target.account_status = 'ACTIVE' THEN
    UPDATE SET target.account_status = 'CLOSED',
               target.updated_ts = current_timestamp();
```

**Enterprise Data Scenario:**  
Intra-day account balance refresh at a European retail bank — MERGE INTO atomically upserts Core Banking account snapshots received every 4 hours, updating existing accounts and inserting new ones, while soft-deleting accounts no longer present in the source feed.

**Optimizer Invariants & Performance Traps:**
- MERGE INTO is atomic — all matched/not-matched clauses execute in a single transaction, never leaving partial state
- WHEN NOT MATCHED BY SOURCE (Delta-specific) handles rows in target that have no match in source — enables soft-delete patterns
- Multiple WHEN MATCHED clauses are evaluated in order — only the first matching clause executes per row
- For large MERGE operations, add /*+ BROADCAST(source) */ hint if source is small; otherwise ensure both sides are partitioned on join key
- Delta records every MERGE as a single commit — DESCRIBE HISTORY shows operationParameters with metrics

---

### Q2.21: Delta Lake Time Travel: VERSION AS OF / TIMESTAMP AS OF (Delta Lake Features)

**Question & Concept Overview:**  
Delta Lake's time travel feature allows querying historical versions of a table using VERSION AS OF or TIMESTAMP AS OF. This enables data auditing, regulatory point-in-time reconstruction, rollback after erroneous DML, and reproducible ML training datasets from a specific snapshot in time.

**SQL Implementation & Query Plan:**
```sql
-- =============================================
-- Delta Time Travel
-- EU BFSI — Regulatory Point-in-Time Queries
-- =============================================

USE CATALOG eu_bfsi_prod;
USE SCHEMA silver;

-- 1. Query by version number
SELECT COUNT(*), SUM(txn_amount_eur) AS total_eur
FROM silver_transactions VERSION AS OF 142
WHERE txn_date = '2024-12-31';

-- 2. Query by timestamp (EOM snapshot for regulatory reporting)
SELECT
    account_id,
    current_balance,
    available_balance,
    account_status
FROM silver_accounts
TIMESTAMP AS OF '2024-12-31T23:59:59.000+00:00'
WHERE account_status = 'ACTIVE';

-- 3. Audit: Compare current vs past state
SELECT
    curr.account_id,
    curr.risk_tier                          AS current_risk_tier,
    hist.risk_tier                          AS risk_tier_90days_ago,
    curr.credit_limit                       AS current_limit,
    hist.credit_limit                       AS limit_90days_ago,
    curr.credit_limit - hist.credit_limit   AS limit_change
FROM silver_accounts curr
JOIN silver_accounts TIMESTAMP AS OF
    DATE_SUB(current_date(), 90) hist
    ON curr.account_id = hist.account_id
WHERE curr.risk_tier != hist.risk_tier
   OR curr.credit_limit != hist.credit_limit
ORDER BY ABS(curr.credit_limit - hist.credit_limit) DESC;

-- 4. Restore table to a previous version (ROLLBACK)
RESTORE TABLE silver_accounts
TO VERSION AS OF 98;
-- Or by timestamp:
-- RESTORE TABLE silver_accounts TO TIMESTAMP AS OF '2024-12-01 08:00:00';

-- 5. CTAS from historical snapshot
CREATE OR REPLACE TABLE eu_bfsi_prod.gold.eom_dec2024_account_snapshot
USING DELTA
COMMENT 'EOM December 2024 account snapshot for COREP reporting'
AS
SELECT *
FROM eu_bfsi_prod.silver.silver_accounts
TIMESTAMP AS OF '2024-12-31T23:59:00.000+00:00';

-- 6. Show Delta history (audit log)
DESCRIBE HISTORY silver_transactions
LIMIT 30;
-- Returns: version, timestamp, userName, operation, operationParameters, operationMetrics

-- 7. Find version closest to a business event timestamp
SELECT version, timestamp, operation, operationMetrics
FROM (
    DESCRIBE HISTORY eu_bfsi_prod.silver.silver_transactions
)
WHERE timestamp <= '2024-12-31T18:00:00.000+00:00'
ORDER BY timestamp DESC
LIMIT 1;
```

**Enterprise Data Scenario:**  
A European bank's regulatory team reconstructing a point-in-time account position snapshot for an ECB audit — TIMESTAMP AS OF '2024-12-31T23:59:59' retrieves the exact end-of-year state used for COREP capital adequacy reporting, without any manual archiving.

**Optimizer Invariants & Performance Traps:**
- Time travel is only available within the retention window — default 30 days, configurable via delta.deletedFileRetentionDuration
- RESTORE TABLE is atomic — it adds a new commit pointing to historical files, rather than replaying old operations
- VERSION AS OF is cheaper than TIMESTAMP AS OF — the version→file mapping is O(1) while timestamp requires log scanning
- Historical snapshots are available even after OPTIMIZE/VACUUM — but VACUUM with retentionHours=0 deletes old files immediately
- Use DESCRIBE HISTORY to find exact version numbers before using VERSION AS OF in audits

---

### Q2.22: LATERAL VIEW and Subqueries (Scalar, Correlated) (Query Structuring)

**Question & Concept Overview:**  
LATERAL VIEW is used to explode complex types (arrays, maps) into virtual columns while keeping the original row context. Scalar and correlated subqueries allow embedding per-row calculations and existence checks that reference the outer query. These are powerful for complex enrichment patterns in financial data pipelines.

**SQL Implementation & Query Plan:**
```sql
-- =============================================
-- LATERAL VIEW & Subqueries
-- EU BFSI — Trade & Account Enrichment
-- =============================================

USE CATALOG eu_bfsi_prod;
USE SCHEMA silver;

-- 1. LATERAL VIEW EXPLODE with alias
SELECT
    t.trade_id,
    t.trade_date,
    t.counterparty_id,
    leg.leg_type,
    leg.notional,
    leg.currency,
    leg.start_date,
    leg.end_date
FROM silver_trades t
LATERAL VIEW EXPLODE(t.trade_legs) AS leg
WHERE leg.currency = 'EUR'
  AND leg.notional > 10000000;

-- 2. Multiple LATERAL VIEW (cross-product of arrays)
SELECT
    account_id,
    flag_type,
    flag_value,
    product_code
FROM silver_accounts
LATERAL VIEW EXPLODE(risk_flags)    AS flag_type
LATERAL VIEW EXPLODE(product_codes) AS product_code
WHERE flag_type IN ('AML_ALERT', 'SANCTIONS_MATCH');

-- 3. LATERAL VIEW OUTER (keeps rows even if array is empty/null)
SELECT
    c.customer_id,
    c.customer_name,
    acc.account_id
FROM silver_customers c
LATERAL VIEW OUTER EXPLODE(c.linked_account_ids) AS account_id;

-- 4. Scalar subquery — single value per row
SELECT
    t.txn_id,
    t.account_id,
    t.txn_amount,
    -- Scalar subquery: account's monthly average for comparison
    (
        SELECT ROUND(AVG(txn_amount), 2)
        FROM silver_transactions inner_t
        WHERE inner_t.account_id = t.account_id
          AND YEAR(inner_t.txn_date)  = YEAR(t.txn_date)
          AND MONTH(inner_t.txn_date) = MONTH(t.txn_date)
          AND inner_t.txn_id != t.txn_id
    )                                       AS monthly_avg_excl_self,
    t.txn_amount - (
        SELECT ROUND(AVG(txn_amount), 2)
        FROM silver_transactions inner_t
        WHERE inner_t.account_id = t.account_id
    )                                       AS deviation_from_lifetime_avg
FROM silver_transactions t
WHERE t.txn_date = current_date() - INTERVAL 1 DAY
  AND t.txn_type = 'DEBIT'
  AND t.txn_amount > 50000;

-- 5. Correlated EXISTS subquery — AML alert filter
SELECT a.account_id, a.customer_id, a.risk_tier
FROM silver_accounts a
WHERE EXISTS (
    SELECT 1
    FROM silver_transactions t
    WHERE t.account_id = a.account_id
      AND t.txn_amount > 500000
      AND t.txn_date >= current_date() - INTERVAL 7 DAYS
      AND t.counterparty_country NOT IN ('DE','FR','NL','BE','ES','IT')
);

-- 6. NOT EXISTS — accounts with no transactions in 12 months (dormant)
SELECT a.account_id, a.customer_id, a.account_type
FROM silver_accounts a
WHERE a.account_status = 'ACTIVE'
  AND NOT EXISTS (
    SELECT 1
    FROM silver_transactions t
    WHERE t.account_id = a.account_id
      AND t.txn_date >= current_date() - INTERVAL 365 DAYS
  );
```

**Enterprise Data Scenario:**  
AML screening at a European bank — correlated EXISTS subquery identifies accounts with recent large cross-border transactions to non-EU countries, while LATERAL VIEW EXPLODE processes multi-leg structured product trades from the derivatives portfolio system.

**Optimizer Invariants & Performance Traps:**
- LATERAL VIEW OUTER preserves rows where the array/map is NULL or empty — critical for outer join semantics with explode
- Correlated scalar subqueries execute once per row — replace with window functions for large datasets to avoid N+1 execution
- EXISTS is more efficient than IN with subquery — Spark converts EXISTS to a semi-join internally
- Multiple LATERAL VIEW clauses produce a cartesian product of the arrays — ensure this is the intended behavior
- Spark 3.x can optimize correlated subqueries through decorrelation — EXPLAIN EXTENDED reveals if optimization fired

---

### Q2.23: Databricks SQL COPY INTO for Incremental File Ingestion (Lakehouse Ingestion)

**Question & Concept Overview:**  
Production Databricks SQL COPY INTO pattern for idempotent, incremental file loading from cloud storage into Delta tables, featuring schema merging, validation, and file tracking.

**SQL Implementation & Query Plan:**
```sql
-- =====================================================================
-- Databricks SQL: Idempotent Incremental Ingestion via COPY INTO
-- Scenario: Incremental hourly ingestion of banking payment files
-- =====================================================================

-- 1. Create target Delta table with schema and table constraints
CREATE TABLE IF NOT EXISTS eu_bfsi_prod.silver.payment_events (
    payment_id          STRING          NOT NULL,
    account_id          BIGINT          NOT NULL,
    amount_eur          DECIMAL(18, 2)  NOT NULL,
    counterparty_iban   STRING,
    payment_timestamp   TIMESTAMP       NOT NULL,
    payment_status      STRING          NOT NULL,
    ingest_time         TIMESTAMP       DEFAULT CURRENT_TIMESTAMP()
)
USING DELTA
TBLPROPERTIES (
    'delta.autoOptimize.optimizeWrite' = 'true',
    'delta.autoOptimize.autoCompact'   = 'true'
);

-- 2. Execute idempotent COPY INTO from ADLS Gen2 landing zone
-- Automatically skips files previously loaded into this Delta table
COPY INTO eu_bfsi_prod.silver.payment_events
FROM 'abfss://landing@eubfsidatalakeprod.dfs.core.windows.net/payments/incoming/'
FILEFORMAT = PARQUET
FORMAT_OPTIONS (
    'mergeSchema' = 'false',              -- Prevent unexpected column expansion
    'ignoreCorruptFiles' = 'false'        -- Abort immediately if corrupt file detected
)
COPY_OPTIONS (
    'force' = 'false'                     -- false = Idempotent (skip already-processed files)
);

-- 3. Check commit history and verified loaded files
DESCRIBE HISTORY eu_bfsi_prod.silver.payment_events LIMIT 5;

-- View number of added files and rows in latest commit
SELECT
    version,
    timestamp,
    operation,
    operationMetrics.numTargetRowsInserted AS rows_inserted,
    operationMetrics.numFilesAdded AS files_added
FROM (DESCRIBE HISTORY eu_bfsi_prod.silver.payment_events)
WHERE operation = 'COPY INTO'
ORDER BY version DESC
LIMIT 1;
```

**Enterprise Data Scenario:**  
Automated hourly financial payment file ingestion into an Azure Databricks Delta Lake Silver table, ensuring zero duplicate records even if upstream orchestrators retry failed runs.

**Optimizer Invariants & Performance Traps:**
- COPY INTO is completely idempotent when force = 'false' — safe to re-run on pipeline retries
- Delta tracks loaded file paths and timestamps in _delta_log; no external checkpoint table needed
- mergeSchema = 'false' enforces strict schema validation, rejecting unauthorized upstream schema changes
- Ideal for low-complexity scheduled batch file ingestion (every 15-60 minutes)

---

### Q2.24: QUALIFY Clause for Elegant Top-N Partition Pruning (Query Structuring)

**Question & Concept Overview:**  
Utilizing the ANSI QUALIFY clause in Spark SQL to filter window function results directly without creating messy nested subqueries or temporary views. Greatly improves query readability and optimization.

**SQL Implementation & Query Plan:**
```sql
-- =============================================================================
-- Identify the Top 3 Highest Value Transactions per Customer in 2026
-- =============================================================================

USE CATALOG prod_catalog;
USE SCHEMA silver;

-- ❌ OLD PATTERN: Required verbose CTE or subquery wrapping
-- WITH ranked AS (
--   SELECT *, ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY txn_amount DESC) as rnk
--   FROM sales_transactions
-- )
-- SELECT * FROM ranked WHERE rnk <= 3;

-- ✅ MODERN QUALIFY PATTERN: Single declarative statement
SELECT
    customer_id,
    txn_id,
    txn_amount,
    txn_timestamp,
    ROW_NUMBER() OVER (
        PARTITION BY customer_id
        ORDER BY txn_amount DESC
    ) AS transaction_rank,
    DENSE_RANK() OVER (
        PARTITION BY customer_id
        ORDER BY txn_amount DESC
    ) AS transaction_dense_rank
FROM sales_transactions
WHERE txn_date >= '2026-01-01'
QUALIFY transaction_rank <= 3
ORDER BY customer_id, transaction_rank;
```

**Enterprise Data Scenario:**  
Extracting the top 3 highest-value purchases or latest status updates per customer in executive sales summaries without maintaining nested subquery boilerplate.

**Optimizer Invariants & Performance Traps:**
- QUALIFY is evaluated after WHERE and window functions, but before ORDER BY and LIMIT.
- Eliminates subqueries and Common Table Expressions (CTEs) previously required to filter on window outputs.
- Catalyst optimizer can push window limits into physical Top-K execution operators when paired with QUALIFY.
- Supported across Databricks SQL, Snowflake, and Google BigQuery.

---

### Q2.25: Relational Matrix Reshaping via PIVOT and UNPIVOT (Spark SQL Transformations)

**Question & Concept Overview:**  
Transforming normalized relational rows into cross-tabulated metric matrices using PIVOT, and normalizing matrix columns back into relational key-value pairs using UNPIVOT.

**SQL Implementation & Query Plan:**
```sql
-- =============================================================================
-- 1. PIVOT: Transpose quarterly revenue metrics by Region
-- =============================================================================
SELECT * FROM (
    SELECT
        region,
        quarter,
        revenue
    FROM prod_catalog.gold.regional_financials
)
PIVOT (
    SUM(revenue)
    FOR quarter IN ('Q1', 'Q2', 'Q3', 'Q4')
)
ORDER BY region;

-- =============================================================================
-- 2. UNPIVOT: Normalize wide monthly columns back into relational key-value rows
-- =============================================================================
SELECT
    product_id,
    month_name,
    units_sold
FROM prod_catalog.staging.wide_monthly_forecast
UNPIVOT (
    units_sold FOR month_name IN (
        jan_sales AS 'January',
        feb_sales AS 'February',
        mar_sales AS 'March',
        apr_sales AS 'April'
    )
);
```

**Enterprise Data Scenario:**  
Converting wide ERP financial forecasts into conformed dimensional tables for Power BI Direct Lake ingestion.

**Optimizer Invariants & Performance Traps:**
- PIVOT requires explicit enumeration of pivot values IN ('Q1', 'Q2', ...) to generate deterministic output schemas.
- UNPIVOT replaces complex UNION ALL chains with a single, highly optimized Catalyst physical operator.
- Essential for transforming third-party financial spreadsheets into clean 3NF Medallion tables.
- Combines seamlessly with GROUP BY to calculate sub-totals alongside pivoted metrics.

---
