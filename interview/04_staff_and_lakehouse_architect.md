# 🎓 SQL Interview Guide — Tier 4: Staff & Lakehouse Architect (System Design & FinOps)

> **Focus Areas**: Lakehouse Open Table Formats (Delta Lake, Apache Iceberg, Apache Hudi), Warehouse Engine Evaluation (Snowflake vs BigQuery vs Databricks SQL), FinOps Slot & Credit Optimization, CDC Disaster Recovery.
> **Target Audience**: Principal Data Architects, Staff Engineers, FinOps Warehouse Leads

---

### Q4.1: SCD Type 2 with MERGE: Full Implementation (Data Patterns)

**Question & Concept Overview:**  
Complete SCD Type 2 implementation using T-SQL MERGE with hash diff change detection, effective dating, and current flag management. The production-grade pattern for dimension management in Azure SQL data warehouses.

**SQL Implementation & Query Plan:**
```sql
-- SCD Type 2: Complete implementation with MERGE + hash diff
-- Handles: inserts, changes (expire old + insert new), no-change (skip)

CREATE OR ALTER PROCEDURE dbo.usp_apply_scd2_customers
    @batch_date DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @batch_date = ISNULL(@batch_date, CAST(GETUTCDATE() AS DATE));

    DECLARE @high_date DATE = '9999-12-31';
    DECLARE @changes_applied INT = 0;

    BEGIN TRANSACTION;

    -- Step 1: Compute hash diff on tracked attributes
    -- Only compare active (current) dimension records
    ;WITH incoming AS (
        SELECT
            s.customer_id,
            s.customer_name,
            s.tier,
            s.country_code,
            s.risk_rating,
            CONVERT(NVARCHAR(MAX),
                HASHBYTES('SHA2_256',
                    ISNULL(UPPER(s.customer_name), '') + '|' +
                    ISNULL(UPPER(s.tier), '') + '|' +
                    ISNULL(UPPER(s.country_code), '') + '|' +
                    ISNULL(UPPER(s.risk_rating), '')
                ), 2) AS hash_diff
        FROM dbo.stage_customer_snapshot s
        WHERE s.batch_date = @batch_date
    ),
    active_dim AS (
        SELECT
            customer_id, customer_name, tier, country_code, risk_rating, hash_diff, customer_sk
        FROM dbo.dim_customers
        WHERE is_current = 1
    )

    -- Step 2: Expire changed records (set valid_to = today, is_current = 0)
    UPDATE dim
    SET
        dim.valid_to   = DATEADD(DAY, -1, @batch_date),
        dim.is_current = 0,
        dim._modified_ts = GETUTCDATE()
    FROM dbo.dim_customers dim
    INNER JOIN active_dim ad ON ad.customer_sk = dim.customer_sk
    INNER JOIN incoming inc ON inc.customer_id = ad.customer_id
    WHERE inc.hash_diff <> ad.hash_diff  -- only changed records
      AND dim.is_current = 1;

    SET @changes_applied += @@ROWCOUNT;

    -- Step 3: Insert new records (both net-new and changed versions)
    INSERT INTO dbo.dim_customers (
        customer_id, customer_name, tier, country_code, risk_rating,
        valid_from, valid_to, is_current, hash_diff, _source, _load_ts
    )
    SELECT
        inc.customer_id,
        inc.customer_name,
        inc.tier,
        inc.country_code,
        inc.risk_rating,
        @batch_date AS valid_from,
        @high_date  AS valid_to,
        1           AS is_current,
        inc.hash_diff,
        'SNAPSHOT_LOAD',
        GETUTCDATE()
    FROM incoming inc
    WHERE
        -- Net-new: no existing active record
        NOT EXISTS (SELECT 1 FROM active_dim ad WHERE ad.customer_id = inc.customer_id)
        OR
        -- Changed: existing active record with different hash
        EXISTS (SELECT 1 FROM active_dim ad
                WHERE ad.customer_id = inc.customer_id
                  AND ad.hash_diff <> inc.hash_diff);

    SET @changes_applied += @@ROWCOUNT;

    COMMIT TRANSACTION;

    -- Log result
    INSERT INTO dbo.pipeline_audit_log (proc_name, batch_date, rows_affected, status, _load_ts)
    VALUES ('usp_apply_scd2_customers', @batch_date, @changes_applied, 'SUCCESS', GETUTCDATE());

    SELECT @changes_applied AS rows_changed;
END;

EXEC dbo.usp_apply_scd2_customers @batch_date = '2024-01-15';
```

**Enterprise Data Scenario:**  
Maintaining full historical customer dimension in Azure SQL DW for TCS EU BFSI regulatory reporting, enabling point-in-time queries like 'what was the customer's risk rating at the time of this 2023 suspicious transaction?'

**Optimizer Invariants & Performance Traps:**
- Hash diff (SHA2_256) detects changes without column-by-column comparison — faster and schema-agnostic
- Expire first, then insert — ensures no window where both old and new records are marked is_current=1
- valid_to = batch_date - 1 day is standard SCD2 convention — query 'as of date X' uses BETWEEN valid_from AND valid_to
- Always use SET XACT_ABORT ON in SCD2 procedures — prevents partial updates leaving dimension in inconsistent state

---

### Q4.2: Data Vault 2.0: Hub-Link-Satellite in T-SQL (Data Modeling)

**Question & Concept Overview:**  
Data Vault 2.0 SQL implementation provides audit-ready, scalable warehouse design. Hubs store business keys, Links store relationships, and Satellites store descriptive attributes — all append-only for full lineage.

**SQL Implementation & Query Plan:**
```sql
-- ── DATA VAULT 2.0: HUB, LINK, SATELLITE DDL ─────────────────

-- HUB: unique business keys for Customer entity
CREATE TABLE dv.hub_customer (
    hub_customer_hk  BINARY(32)     NOT NULL,  -- SHA-256 hash key
    load_date        DATETIME2      NOT NULL DEFAULT GETUTCDATE(),
    record_source    NVARCHAR(100)  NOT NULL,
    customer_bk      NVARCHAR(50)   NOT NULL,  -- business key (natural key)
    CONSTRAINT PK_hub_customer PRIMARY KEY NONCLUSTERED (hub_customer_hk),
    CONSTRAINT UQ_hub_customer_bk UNIQUE (customer_bk)
);
CREATE CLUSTERED COLUMNSTORE INDEX CCI_hub_customer ON dv.hub_customer;

-- SATELLITE: descriptive attributes for Customer (with hash diff)
CREATE TABLE dv.sat_customer_profile (
    hub_customer_hk  BINARY(32)     NOT NULL,
    load_date        DATETIME2      NOT NULL DEFAULT GETUTCDATE(),
    load_end_date    DATETIME2      NULL,        -- NULL = current record
    record_source    NVARCHAR(100)  NOT NULL,
    hash_diff        BINARY(32)     NOT NULL,    -- detects attribute changes
    customer_name    NVARCHAR(200)  NULL,
    tier             NVARCHAR(20)   NULL,
    country_code     CHAR(2)        NULL,
    risk_rating      NVARCHAR(10)   NULL,
    CONSTRAINT PK_sat_customer PRIMARY KEY (hub_customer_hk, load_date),
    CONSTRAINT FK_sat_customer_hub FOREIGN KEY (hub_customer_hk)
        REFERENCES dv.hub_customer (hub_customer_hk)
);

-- LINK: Customer-Transaction relationship
CREATE TABLE dv.lnk_customer_transaction (
    lnk_cust_txn_hk  BINARY(32) NOT NULL,  -- hash of all link components
    load_date        DATETIME2  NOT NULL DEFAULT GETUTCDATE(),
    record_source    NVARCHAR(100) NOT NULL,
    hub_customer_hk  BINARY(32) NOT NULL,
    hub_transaction_hk BINARY(32) NOT NULL,
    CONSTRAINT PK_lnk_cust_txn PRIMARY KEY NONCLUSTERED (lnk_cust_txn_hk)
);

-- ── LOAD PROCEDURES ───────────────────────────────────────────────

-- Load Hub: idempotent — only insert new business keys
CREATE OR ALTER PROCEDURE dv.usp_load_hub_customer @batch_date DATE
AS BEGIN
    INSERT INTO dv.hub_customer (hub_customer_hk, load_date, record_source, customer_bk)
    SELECT
        HASHBYTES('SHA2_256', UPPER(TRIM(s.customer_id))),  -- deterministic hash key
        GETUTCDATE(), 'EU_PAYMENT_GATEWAY', UPPER(TRIM(s.customer_id))
    FROM dbo.stage_transactions s
    WHERE s.batch_date = @batch_date
      AND NOT EXISTS (
          SELECT 1 FROM dv.hub_customer h
          WHERE h.customer_bk = UPPER(TRIM(s.customer_id))
      )
    GROUP BY s.customer_id;  -- dedup from staging
END;

-- Load Satellite: insert only when attributes change (hash diff comparison)
CREATE OR ALTER PROCEDURE dv.usp_load_sat_customer_profile @batch_date DATE
AS BEGIN
    -- Close previous satellite record where hash diff changed
    UPDATE sat
    SET sat.load_end_date = GETUTCDATE()
    FROM dv.sat_customer_profile sat
    INNER JOIN (
        SELECT hub_customer_hk,
               HASHBYTES('SHA2_256', UPPER(ISNULL(customer_name,'')) + '|' +
                         UPPER(ISNULL(tier,'')) + '|' + UPPER(ISNULL(country_code,''))) AS new_hash
        FROM dbo.stage_customer_snapshot WHERE batch_date = @batch_date
    ) src ON src.hub_customer_hk = sat.hub_customer_hk
    WHERE sat.load_end_date IS NULL
      AND sat.hash_diff <> src.new_hash;

    -- Insert new/changed satellite records
    INSERT INTO dv.sat_customer_profile
        (hub_customer_hk, load_date, record_source, hash_diff, customer_name, tier, country_code)
    SELECT
        HASHBYTES('SHA2_256', UPPER(TRIM(s.customer_id))),
        GETUTCDATE(), 'EU_GATEWAY',
        HASHBYTES('SHA2_256', UPPER(ISNULL(s.customer_name,'')) + '|' +
                  UPPER(ISNULL(s.tier,'')) + '|' + UPPER(ISNULL(s.country_code,''))),
        s.customer_name, s.tier, s.country_code
    FROM dbo.stage_customer_snapshot s
    WHERE s.batch_date = @batch_date
      AND NOT EXISTS (
          SELECT 1 FROM dv.sat_customer_profile sat
          WHERE sat.hub_customer_hk = HASHBYTES('SHA2_256', UPPER(TRIM(s.customer_id)))
            AND sat.load_end_date IS NULL
            AND sat.hash_diff = HASHBYTES('SHA2_256', UPPER(ISNULL(s.customer_name,'')) + '|' +
                                UPPER(ISNULL(s.tier,'')) + '|' + UPPER(ISNULL(s.country_code,'')))
      );
END;
```

**Enterprise Data Scenario:**  
Implementing Data Vault 2.0 in Azure SQL for TCS EU BFSI Gold layer — providing full source-to-report lineage for regulatory audits, with hash-based change detection that scales to 100M+ customer records.

**Optimizer Invariants & Performance Traps:**
- HASHBYTES('SHA2_256') produces deterministic 32-byte keys — same input always produces same hash key
- Satellites are append-only — close (load_end_date) the current record and insert new rather than UPDATE
- Hub loading is always idempotent — NOT EXISTS check prevents duplicates from any number of reruns
- Data Vault is the preferred GDPR architecture — full lineage, no data destruction, audit-friendly

---

### Q4.3: Azure SQL: FinOps & Cost Optimization (FinOps)

**Question & Concept Overview:**  
Systematic Azure SQL cost optimization involves DTU/vCore right-sizing, Elastic Pool configuration, Query Store-based optimization, and automated maintenance scheduling to minimize compute costs while meeting SLA.

**SQL Implementation & Query Plan:**
```sql
-- FinOps: Resource consumption analysis for Azure SQL cost optimization
-- Identify top resource consumers across DTU/CPU/IO dimensions

-- DTU consumption by query (last 24 hours)
SELECT TOP 20
    SUBSTRING(qt.query_sql_text, 1, 200) AS query_snippet,
    SUM(rs.avg_cpu_time) AS total_cpu_ms,
    SUM(rs.avg_logical_io_reads) AS total_logical_reads,
    SUM(rs.avg_physical_io_reads) AS total_physical_reads,
    SUM(rs.avg_query_max_used_memory) / 128 AS max_memory_mb,
    SUM(rs.count_executions) AS executions,
    -- DTU estimate: CPU + I/O normalized
    ROUND((SUM(rs.avg_cpu_time) * 0.0001 + SUM(rs.avg_logical_io_reads) * 0.000001) *
          SUM(rs.count_executions), 2) AS estimated_dtu_units
FROM sys.query_store_query q
JOIN sys.query_store_query_text qt ON q.query_text_id = qt.query_text_id
JOIN sys.query_store_plan p ON q.query_id = p.query_id
JOIN sys.query_store_runtime_stats rs ON p.plan_id = rs.plan_id
JOIN sys.query_store_runtime_stats_interval rsi ON rs.runtime_stats_interval_id = rsi.runtime_stats_interval_id
WHERE rsi.start_time >= DATEADD(HOUR, -24, GETUTCDATE())
GROUP BY qt.query_sql_text
ORDER BY estimated_dtu_units DESC;

-- Elastic Pool sizing: workload analysis per database
SELECT
    database_name,
    AVG(avg_cpu_percent) AS avg_cpu_pct,
    MAX(avg_cpu_percent) AS peak_cpu_pct,
    AVG(avg_data_io_percent) AS avg_io_pct,
    MAX(avg_data_io_percent) AS peak_io_pct,
    AVG(avg_memory_usage_percent) AS avg_mem_pct
FROM sys.elastic_pool_resource_stats
WHERE start_time >= DATEADD(DAY, -30, GETUTCDATE())
GROUP BY database_name
ORDER BY peak_cpu_pct DESC;

-- Auto-shrink & maintenance scheduling (off-peak: 2-4 AM UTC)
-- Rebuild fragmented indexes (> 30% fragmentation)
DECLARE @sql NVARCHAR(MAX) = '';
SELECT @sql += 'ALTER INDEX ' + QUOTENAME(i.name) +
               ' ON ' + QUOTENAME(SCHEMA_NAME(o.schema_id)) + '.' + QUOTENAME(o.name) +
               ' REBUILD WITH (ONLINE = ON, FILLFACTOR = 85);' + CHAR(13)
FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'SAMPLED') ips
JOIN sys.indexes i ON ips.object_id = i.object_id AND ips.index_id = i.index_id
JOIN sys.objects o ON ips.object_id = o.object_id
WHERE ips.avg_fragmentation_in_percent > 30
  AND ips.page_count > 1000  -- only substantial indexes
  AND i.name IS NOT NULL;

EXEC sp_executesql @sql;

-- Update statistics (critical for Query Optimizer post-large-load)
EXEC sp_updatestats;
```

**Enterprise Data Scenario:**  
Monthly FinOps review of Azure SQL costs at TCS EU BFSI — using Query Store analysis to identify over-consuming queries, right-sizing the Elastic Pool from P3 to P2 (40% cost reduction) while maintaining SLA.

**Optimizer Invariants & Performance Traps:**
- Azure SQL Elastic Pools share DTU across databases — right-size pool based on peak (not average) utilization
- Query Store DTU analysis identifies 20% of queries consuming 80% of cost — Pareto principle applies
- REBUILD WITH (ONLINE = ON) avoids table lock during business hours — critical for 99.9% availability SLA
- sp_updatestats after large batch loads prevents stale statistics from causing poor query plans

---

### Q4.4: Zero-Downtime Schema Evolution (DevOps & Governance)

**Question & Concept Overview:**  
Schema changes on production BFSI databases require careful migration strategies that maintain 99.9% availability. This pattern implements backward-compatible migrations using online operations and blue-green column transitions.

**SQL Implementation & Query Plan:**
```sql
-- Zero-downtime schema evolution pattern
-- Problem: add NOT NULL column to 100M row table without locking

-- ── PHASE 1: Add column as NULL (instant, no lock) ────────────────
ALTER TABLE dbo.fact_transactions
ADD risk_score DECIMAL(5,2) NULL;   -- nullable first — no table scan

-- ── PHASE 2: Backfill in small batches (off-peak, no locks) ──────
DECLARE @batch_size INT = 10000;
DECLARE @rows_updated INT = 1;
DECLARE @last_sk BIGINT = 0;

WHILE @rows_updated > 0
BEGIN
    UPDATE TOP (@batch_size) t
    SET t.risk_score = CASE
        WHEN t.amount_eur > 100000 THEN 9.5
        WHEN t.amount_eur > 10000  THEN 6.0
        WHEN t.amount_eur > 1000   THEN 3.0
        ELSE 1.0
    END
    FROM dbo.fact_transactions t
    WHERE t.risk_score IS NULL;

    SET @rows_updated = @@ROWCOUNT;
    WAITFOR DELAY '00:00:01';  -- 1 second pause to throttle I/O
END;

-- ── PHASE 3: Add NOT NULL constraint with default (online) ────────
-- Only after all rows backfilled
ALTER TABLE dbo.fact_transactions
ADD CONSTRAINT DF_risk_score DEFAULT 1.0 FOR risk_score;
ALTER TABLE dbo.fact_transactions
ALTER COLUMN risk_score DECIMAL(5,2) NOT NULL;  -- column scan at this point

-- ── RENAME pattern: zero-downtime column rename ───────────────────
-- Cannot rename column without app downtime → use alias view pattern

-- Step 1: Add new column with new name
ALTER TABLE dbo.fact_transactions ADD amount_base_currency DECIMAL(18,2) NULL;

-- Step 2: Keep both in sync via trigger (transition period)
CREATE OR ALTER TRIGGER trg_sync_amount_columns
ON dbo.fact_transactions
AFTER INSERT, UPDATE
AS
BEGIN
    UPDATE t SET t.amount_base_currency = i.amount_eur
    FROM dbo.fact_transactions t
    INNER JOIN inserted i ON t.txn_sk = i.txn_sk
    WHERE i.amount_base_currency IS NULL;
END;

-- Step 3: After app migration complete, backfill remaining, drop old column
-- ALTER TABLE dbo.fact_transactions DROP COLUMN amount_eur;

-- Track schema versions (DbUp / Flyway pattern)
CREATE TABLE dbo.schema_versions (
    version NVARCHAR(20) NOT NULL PRIMARY KEY,
    applied_at DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    description NVARCHAR(500) NOT NULL
);
INSERT INTO dbo.schema_versions VALUES ('1.5.0', DEFAULT, 'Add risk_score column with zero-downtime migration');
```

**Enterprise Data Scenario:**  
Adding risk_score column to the 100M-row fact_transactions table on Azure SQL at TCS EU BFSI with zero downtime — maintaining 99.9% SLA while migrating the schema across 5 concurrent engineering squads.

**Optimizer Invariants & Performance Traps:**
- Always add NOT NULL columns in two phases: NULL first (instant), backfill, then ALTER to NOT NULL
- Batch backfill with WAITFOR DELAY throttles I/O — prevents overwhelming Azure SQL during business hours
- Use view as abstraction layer during column renames — old name in view, new name in table
- Schema version table (DbUp/Flyway pattern) tracks migrations — integrate with ADF CI/CD YAML pipeline

---

### Q4.5: Keyset Pagination (Seek Method) over Massive Datasets (Advanced T-SQL)

**Question & Concept Overview:**  
High-performance keyset pagination pattern replacing OFFSET-FETCH with B-Tree composite index seeks, delivering O(log N) latency regardless of page depth.

**SQL Implementation & Query Plan:**
```sql
-- Keyset Pagination (Seek Method)
-- Eliminates linear O(N) OFFSET scanning penalties
-- Supporting Index: CREATE INDEX idx_orders_seek ON dbo.orders (order_date DESC, order_id DESC) INCLUDE (total_amount, customer_id);

DECLARE @last_seen_date DATETIME2 = '2026-10-10 08:30:00';
DECLARE @last_seen_id BIGINT = 9845210;
DECLARE @page_size INT = 25;

-- Direct B-Tree Seek Query
SELECT TOP (@page_size)
    o.order_id,
    o.customer_id,
    o.order_date,
    o.total_amount
FROM dbo.orders o
WHERE 
    (o.order_date < @last_seen_date)
    OR (o.order_date = @last_seen_date AND o.order_id < @last_seen_id)
ORDER BY 
    o.order_date DESC, 
    o.order_id DESC;

-- Note: Bypasses scanning preceding 500,000 rows, executing in <2ms!
```

**Enterprise Data Scenario:**  
Deep API pagination, infinite scrolling feeds, and high-throughput real-time mobile order history retrieval.

**Optimizer Invariants & Performance Traps:**
- Replaces OFFSET N with index seeks based on the previous page's tie-breaker key
- Maintains constant O(log N + K) latency regardless of whether querying page 1 or page 50,000
- Completely immune to page drift caused by concurrent insertions

---

### Q4.6: High-Throughput Queue Processing via READPAST & UPDLOCK (Advanced T-SQL)

**Question & Concept Overview:**  
Lock-free concurrent worker queue polling in T-SQL using UPDLOCK and READPAST (the SQL Server equivalent of SELECT FOR UPDATE SKIP LOCKED).

**SQL Implementation & Query Plan:**
```sql
-- High-Throughput Concurrent Queue Consumer (50+ Workers)
-- Supporting Index: CREATE INDEX idx_jobs_pending ON dbo.task_queue (priority DESC, job_id ASC) WHERE status = 'PENDING';

BEGIN TRANSACTION;

WITH NextJob AS (
    SELECT TOP (1)
        job_id,
        payload,
        status
    FROM dbo.task_queue WITH (UPDLOCK, READPAST) -- Equivalent to SKIP LOCKED!
    WHERE status = 'PENDING'
    ORDER BY priority DESC, job_id ASC
)
UPDATE NextJob
SET 
    status = 'PROCESSING',
    locked_by = HOST_NAME(),
    locked_at = SYSUTCDATETIME()
OUTPUT 
    inserted.job_id,
    inserted.payload;

COMMIT TRANSACTION;
```

**Enterprise Data Scenario:**  
Transactional background task processing, event dispatchers, and reliable message queuing inside SQL Server.

**Optimizer Invariants & Performance Traps:**
- UPDLOCK acquires update locks during the read phase to prevent race conditions
- READPAST instructs the engine to silently skip rows locked by other concurrent sessions
- Enables horizontal scaling across hundreds of worker nodes without lock contention or deadlocks

---

### Q4.7: Azure Synapse Maximum Throughput Staging Ingestion Pattern (Cloud MPP & Synapse)

**Question & Concept Overview:**  
Configures a dedicated staging table with Round-Robin distribution and Heap storage to achieve maximum ingestion throughput during ELT pipelines.

**SQL Implementation & Query Plan:**
```sql
-- Step 1: Create Staging Table with Round-Robin and Heap
CREATE TABLE stg.orders_raw_ingest
WITH (
    DISTRIBUTION = ROUND_ROBIN,
    HEAP
)
AS
SELECT * FROM dbo.fact_orders WHERE 1 = 0;

-- Step 2: High-speed ingestion via COPY INTO
COPY INTO stg.orders_raw_ingest
FROM 'https://mystorageaccount.dfs.core.windows.net/landing/orders/*.parquet'
WITH (
    FILE_TYPE = 'PARQUET',
    CREDENTIAL = (IDENTITY = 'Managed Identity')
);

-- Step 3: Insert into Production Clustered Columnstore Fact Table
INSERT INTO prod.fact_orders (order_id, customer_id, order_date, total_amount_eur)
SELECT order_id, customer_id, order_date, total_amount_eur
FROM stg.orders_raw_ingest;

-- Step 4: Fast truncate staging table
TRUNCATE TABLE stg.orders_raw_ingest;
```

**Enterprise Data Scenario:**  
High-volume data warehouse ingestion pipelines handling gigabytes to terabytes per hour in Azure Synapse Analytics.

**Optimizer Invariants & Performance Traps:**
- Round-Robin spreads data uniformly across all 60 distributions with zero hash calculation overhead
- Heap storage avoids index maintenance and rowgroup compression overhead during bulk ingest
- Bulk loading into staging before inserting into production Fact ensures clean transaction boundaries and simple retry logic

---

### Q4.8: Configuring Legacy Cardinality Estimation & Hints (Query Engine Internals)

**Question & Concept Overview:**  
Techniques to resolve query plan regressions caused by the post-2014 Cardinality Estimator at database, session, and query levels.

**SQL Implementation & Query Plan:**
```sql
-- 1. Database Scoped Configuration (Fixes regressions across entire database):
ALTER DATABASE SCOPED CONFIGURATION 
SET LEGACY_CARDINALITY_ESTIMATION = ON;

-- 2. Single-Query Targeted Hint (Preserves modern CE for other queries):
SELECT 
    c.CustomerName,
    o.OrderID,
    o.TotalAmount
FROM dbo.Customers c
INNER JOIN dbo.Orders o ON c.CustomerID = o.CustomerID
WHERE c.City = 'Seattle' AND c.PostalCode = '98101'
OPTION (USE HINT('FORCE_LEGACY_CARDINALITY_ESTIMATION'));

-- 3. Verify Query Store Plan Forcing:
SELECT q.query_id, p.plan_id, p.is_forced_plan
FROM sys.query_store_query q
JOIN sys.query_store_plan p ON q.query_id = p.query_id
WHERE p.is_forced_plan = 1;
```

**Enterprise Data Scenario:**  
Migrating mission-critical databases from SQL Server 2008/2012 to 2019/2022 without query timeouts.

**Optimizer Invariants & Performance Traps:**
- Modern CE assumes predicate independence, underestimating row counts for correlated columns.
- Underestimation prompts the optimizer to select Nested Loops with row lookups over Hash Joins.
- Database-scoped configuration isolates the setting without requiring server-wide trace flag 9481.

---

### Q4.9: Enabling Read Committed Snapshot Isolation (RCSI) (Concurrency & Locking)

**Question & Concept Overview:**  
Enables statement-level optimistic concurrency in SQL Server to completely eliminate reader-writer blocking.

**SQL Implementation & Query Plan:**
```sql
-- Step 1: Terminate active connections and activate RCSI:
ALTER DATABASE CoreBanking
SET READ_COMMITTED_SNAPSHOT ON
WITH ROLLBACK IMMEDIATE;

-- Step 2: Verify database isolation state:
SELECT 
    name,
    is_read_committed_snapshot_on,
    snapshot_isolation_state_desc
FROM sys.databases
WHERE name = 'CoreBanking';

-- Step 3: Monitor Persistent Version Store (PVS) memory:
SELECT 
    db_name(database_id) AS DatabaseName,
    pvs_in_row_version_store_size_kb,
    pvs_off_row_version_store_size_kb
FROM sys.dm_tran_persistent_version_store_stats
WHERE database_id = DB_ID('CoreBanking');
```

**Enterprise Data Scenario:**  
High-throughput mixed OLTP and operational reporting databases suffering from blocking.

**Optimizer Invariants & Performance Traps:**
- Readers do not acquire Shared (S) locks, so they never block concurrent exclusive (X) update locks.
- Does not require modifying query syntax (unlike manual SNAPSHOT isolation or NOLOCK).
- SQL Server 2019+ utilizes Persistent Version Store (PVS) inside the user database, reducing TempDB overhead.

---

### Q4.10: Full Medallion Architecture DDL in Spark SQL (Architecture Patterns)

**Question & Concept Overview:**  
The Medallion Architecture (Bronze → Silver → Gold) organizes data into progressively refined layers. Bronze captures raw data with minimal transformation, Silver cleanses and conforms, Gold delivers business-ready aggregations. Implementing this in SQL requires careful DDL design with proper partitioning, clustering, properties, and governance from the start.

**SQL Implementation & Query Plan:**
```sql
-- =====================================================================
-- FULL MEDALLION ARCHITECTURE DDL
-- EU BFSI — Pan-European Retail Bank Transaction Platform
-- Catalog: eu_bfsi_prod | Workspace: Azure Databricks (East US 2)
-- Author: Data Engineering Team | Santosh Jammi, TCS
-- =====================================================================

-- ── CATALOG & SCHEMA SETUP ────────────────────────────────────────────
CREATE CATALOG IF NOT EXISTS eu_bfsi_prod
  COMMENT 'Production catalog — EU Banking platform on Azure Databricks';

CREATE SCHEMA IF NOT EXISTS eu_bfsi_prod.bronze
  MANAGED LOCATION 'abfss://bronze@euadlsprod.dfs.core.windows.net/'
  COMMENT 'Raw ingestion — no business transformations';

CREATE SCHEMA IF NOT EXISTS eu_bfsi_prod.silver
  MANAGED LOCATION 'abfss://silver@euadlsprod.dfs.core.windows.net/'
  COMMENT 'Cleansed, conformed, enriched';

CREATE SCHEMA IF NOT EXISTS eu_bfsi_prod.gold
  MANAGED LOCATION 'abfss://gold@euadlsprod.dfs.core.windows.net/'
  COMMENT 'Aggregated, business-ready, BI/ML ready';

-- ── BRONZE LAYER ───────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS eu_bfsi_prod.bronze.bronze_transactions (
    _ingest_id          STRING          COMMENT 'Auto Loader file UUID',
    _source_file        STRING          COMMENT 'ADLS file path',
    _source_ts          TIMESTAMP       COMMENT 'File modification time',
    _ingest_ts          TIMESTAMP       NOT NULL COMMENT 'Databricks ingest time',
    _batch_id           STRING          COMMENT 'Pipeline run ID',
    _rescued_data       STRING          COMMENT 'Auto Loader schema rescue',
    txn_id              STRING,
    account_id          STRING,
    txn_raw_amount      STRING          COMMENT 'Raw — may contain commas/currency symbols',
    txn_currency        STRING,
    txn_type            STRING,
    txn_status          STRING,
    txn_timestamp_raw   STRING          COMMENT 'Raw timestamp string from source',
    source_system       STRING          COMMENT 'CORE_BANKING | SWIFT | SEPA | PSD2_OPEN'
)
USING DELTA
PARTITIONED BY (ingest_date DATE GENERATED ALWAYS AS (DATE(_ingest_ts)))
COMMENT 'Bronze — raw transactions as landed from source systems'
TBLPROPERTIES (
    'delta.enableChangeDataFeed'       = 'true',
    'delta.autoOptimize.optimizeWrite' = 'true',
    'delta.columnMapping.mode'         = 'name',
    'delta.enableDeletionVectors'      = 'true',
    'data.layer'                       = 'bronze',
    'data.classification'              = 'RAW_CONFIDENTIAL',
    'pipeline.source'                  = 'AUTO_LOADER',
    'data.retention.years'             = '7'
);

-- ── SILVER LAYER ───────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS eu_bfsi_prod.silver.silver_transactions (
    txn_id              STRING          NOT NULL COMMENT 'Deduplicated transaction key',
    account_id          STRING          NOT NULL,
    counterparty_id     STRING,
    txn_amount          DECIMAL(18, 4)  NOT NULL,
    txn_currency        STRING(3)       NOT NULL,
    txn_amount_eur      DECIMAL(18, 4)  COMMENT 'Normalized EUR amount via ECB rate',
    fx_rate             DECIMAL(12, 8),
    txn_type            STRING,
    txn_status          STRING,
    txn_timestamp       TIMESTAMP       NOT NULL,
    txn_date            DATE            GENERATED ALWAYS AS (DATE(txn_timestamp)),
    value_date          DATE,
    source_system       STRING,
    is_high_value       BOOLEAN         GENERATED ALWAYS AS (txn_amount >= 15000),
    amount_band         STRING          GENERATED ALWAYS AS (
                        CASE
                            WHEN txn_amount < 1000    THEN 'MICRO'
                            WHEN txn_amount < 10000   THEN 'SMALL'
                            WHEN txn_amount < 100000  THEN 'MEDIUM'
                            WHEN txn_amount < 1000000 THEN 'LARGE'
                            ELSE 'WHALE'
                        END),
    dq_score            DECIMAL(5, 2)   COMMENT 'Data quality score 0-100',
    dq_flags            ARRAY<STRING>   COMMENT 'DQ rule violations',
    _bronze_ingest_ts   TIMESTAMP       COMMENT 'Source bronze ingest time',
    _silver_ts          TIMESTAMP       NOT NULL COMMENT 'Silver promotion timestamp'
)
USING DELTA
PARTITIONED BY (txn_date)
CLUSTER BY (account_id, txn_currency)
COMMENT 'Silver — cleansed, deduplicated, FX-normalized transactions'
TBLPROPERTIES (
    'delta.enableChangeDataFeed'            = 'true',
    'delta.autoOptimize.optimizeWrite'      = 'true',
    'delta.autoOptimize.autoCompact'        = 'true',
    'delta.columnMapping.mode'              = 'name',
    'delta.enableDeletionVectors'           = 'true',
    'delta.enableRowTracking'               = 'true',
    'data.layer'                            = 'silver',
    'data.classification'                   = 'CONFIDENTIAL',
    'data.pii.columns'                      = 'account_id,counterparty_id',
    'data.gdpr'                             = 'true',
    'data.retention.years'                  = '7'
);

-- ── GOLD LAYER ─────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS eu_bfsi_prod.gold.gold_daily_account_summary (
    snapshot_date       DATE            NOT NULL,
    account_id          STRING          NOT NULL,
    risk_tier           STRING,
    product_code        STRING,
    country_code        STRING,
    txn_count           BIGINT,
    debit_count         BIGINT,
    credit_count        BIGINT,
    total_debit_eur     DECIMAL(18, 2),
    total_credit_eur    DECIMAL(18, 2),
    net_flow_eur        DECIMAL(18, 2),
    max_single_txn_eur  DECIMAL(18, 2),
    avg_txn_eur         DECIMAL(18, 2),
    unique_currencies   BIGINT,
    unique_counterparties BIGINT,
    high_value_count    BIGINT          COMMENT 'Transactions >= 15,000 EUR (CTR threshold)',
    cross_border_count  BIGINT,
    dq_pass_rate        DECIMAL(5, 2)   COMMENT 'Data quality pass % for the day',
    _gold_ts            TIMESTAMP       NOT NULL COMMENT 'Gold layer computation timestamp'
)
USING DELTA
PARTITIONED BY (snapshot_date)
COMMAND 'Gold — daily account-level summary for regulatory & BI reporting'
TBLPROPERTIES (
    'delta.autoOptimize.optimizeWrite'  = 'true',
    'delta.autoOptimize.autoCompact'    = 'true',
    'data.layer'                        = 'gold',
    'data.classification'               = 'INTERNAL',
    'data.retention.years'              = '10',
    'business.domain'                   = 'PAYMENTS_ANALYTICS',
    'business.consumers'                = 'RISK,COMPLIANCE,FINANCE,BI'
);
```

**Enterprise Data Scenario:**  
Greenfield Medallion Architecture for a pan-European retail bank's Azure Databricks platform — supporting 15M daily transactions across 12 EU countries, with full lineage from Core Banking raw events through to COREP/FINREP regulatory reports and Power BI dashboards, all governed by Unity Catalog.

**Optimizer Invariants & Performance Traps:**
- Bronze = raw as-is with ingestion metadata; Silver = validated, typed, enriched; Gold = aggregated, business-ready — each layer has a distinct contract
- Generated columns (txn_date, is_high_value, amount_band) eliminate application-layer logic errors and guarantee consistency
- CLUSTER BY (Liquid Clustering) in Silver enables incremental re-clustering as data grows — no need to repartition
- CDF enabled on Bronze and Silver enables efficient incremental propagation — avoid full scans on multi-billion row tables
- TBLPROPERTIES as a data catalog: store owner, classification, PII columns, GDPR flag, retention, and business domain — queryable via SHOW TBLPROPERTIES

---

### Q4.11: Delta Live Tables (DLT) SQL Syntax — Multi-hop Pipeline (Delta Live Tables)

**Question & Concept Overview:**  
Delta Live Tables (DLT) is Databricks' declarative ETL framework. SQL-based DLT pipelines define streaming and batch tables with expectations (data quality rules) and automatic dependency resolution. DLT manages infrastructure, retries, monitoring, and schema evolution, making it ideal for production Medallion pipelines.

**SQL Implementation & Query Plan:**
```sql
-- =============================================
-- Delta Live Tables (DLT) SQL Pipeline
-- EU BFSI — Bronze→Silver→Gold Multi-hop
-- =============================================
-- File: /pipeline/eu_bfsi_dlt_pipeline.sql
-- Pipeline name: EU_BFSI_TXN_PIPELINE
-- =============================================

-- ─── BRONZE: Raw Ingestion via Auto Loader ────
CREATE OR REFRESH STREAMING TABLE bronze_transactions
COMMENT 'Bronze — raw transactions from ADLS via Auto Loader'
TBLPROPERTIES (
    'delta.enableChangeDataFeed' = 'true',
    'quality.layer'              = 'bronze'
)
AS SELECT
    _metadata.file_path         AS _source_file,
    _metadata.file_modification_time AS _source_ts,
    current_timestamp()         AS _ingest_ts,
    monotonically_increasing_id() AS _row_id,
    *
FROM cloud_files(
    'abfss://raw@euadlsprod.dfs.core.windows.net/transactions/',
    'json',
    map(
        'cloudFiles.schemaLocation',
        'abfss://checkpoints@euadlsprod.dfs.core.windows.net/bronze_txn_schema/',
        'cloudFiles.inferColumnTypes',   'true',
        'cloudFiles.schemaEvolutionMode', 'rescue'
    )
);

-- ─── SILVER: Cleansed with DQ Expectations ────
CREATE OR REFRESH STREAMING TABLE silver_transactions (
  CONSTRAINT txn_id_not_null
      EXPECT (txn_id IS NOT NULL) ON VIOLATION DROP ROW,
  CONSTRAINT valid_amount
      EXPECT (txn_amount > 0 AND txn_amount < 100000000) ON VIOLATION DROP ROW,
  CONSTRAINT valid_currency
      EXPECT (txn_currency RLIKE '^[A-Z]{3}$') ON VIOLATION DROP ROW,
  CONSTRAINT valid_timestamp
      EXPECT (txn_timestamp IS NOT NULL AND txn_timestamp <= current_timestamp())
      ON VIOLATION DROP ROW,
  CONSTRAINT account_id_not_null
      EXPECT (account_id IS NOT NULL) ON VIOLATION WARN  -- Warn, don't drop
)
COMMENT 'Silver — validated, typed, FX-normalized transactions'
TBLPROPERTIES (
    'delta.enableChangeDataFeed' = 'true',
    'quality.layer'              = 'silver'
)
AS SELECT
    txn_id,
    account_id,
    CAST(txn_amount AS DECIMAL(18,4))           AS txn_amount,
    UPPER(TRIM(txn_currency))                   AS txn_currency,
    CAST(txn_timestamp AS TIMESTAMP)            AS txn_timestamp,
    DATE(CAST(txn_timestamp AS TIMESTAMP))      AS txn_date,
    COALESCE(txn_type, 'UNKNOWN')               AS txn_type,
    COALESCE(txn_status, 'PENDING')             AS txn_status,
    COALESCE(source_system, 'UNKNOWN')          AS source_system,
    _ingest_ts                                  AS _bronze_ingest_ts,
    current_timestamp()                         AS _silver_ts
FROM STREAM(LIVE.bronze_transactions)
WHERE _rescued_data IS NULL;  -- Exclude rescued/malformed rows

-- ─── SILVER: FX-Enriched via LIVE table join ──
CREATE OR REFRESH STREAMING TABLE silver_transactions_enriched
COMMENT 'Silver enriched — with EUR normalization'
AS SELECT
    t.*,
    COALESCE(fx.exchange_rate, 1.0)             AS fx_rate,
    ROUND(t.txn_amount * COALESCE(fx.exchange_rate, 1.0), 4) AS txn_amount_eur
FROM STREAM(LIVE.silver_transactions) t
LEFT JOIN LIVE.dim_fx_rates fx   -- Static table (non-streaming JOIN)
    ON t.txn_currency = fx.from_currency
    AND t.txn_date    = fx.rate_date
    AND fx.to_currency = 'EUR';

-- ─── GOLD: Daily Account Summary ──────────────
CREATE OR REFRESH LIVE TABLE gold_daily_account_summary
COMMENT 'Gold — daily account-level aggregation for BI & regulatory reporting'
TBLPROPERTIES (
    'delta.autoOptimize.optimizeWrite' = 'true'
)
AS SELECT
    txn_date                            AS snapshot_date,
    account_id,
    COUNT(*)                            AS txn_count,
    SUM(CASE WHEN txn_type='DEBIT'  THEN txn_amount_eur ELSE 0 END) AS total_debit_eur,
    SUM(CASE WHEN txn_type='CREDIT' THEN txn_amount_eur ELSE 0 END) AS total_credit_eur,
    SUM(CASE WHEN txn_type='DEBIT'  THEN txn_amount_eur
             WHEN txn_type='CREDIT' THEN -txn_amount_eur
             ELSE 0 END)                AS net_flow_eur,
    MAX(txn_amount_eur)                 AS max_single_txn_eur,
    COUNT(DISTINCT txn_currency)        AS unique_currencies,
    SUM(CASE WHEN txn_amount_eur >= 15000 THEN 1 ELSE 0 END) AS high_value_count,
    current_timestamp()                 AS _gold_ts
FROM LIVE.silver_transactions_enriched
GROUP BY txn_date, account_id;
```

**Enterprise Data Scenario:**  
Production payment processing pipeline at a European fintech — DLT's declarative model with built-in expectations replaces 3,000 lines of imperative PySpark with 200 lines of SQL, while automated retries and monitoring reduce on-call incidents by 70%. The pipeline processes 50M daily transactions with < 5-minute latency from source to gold.

**Optimizer Invariants & Performance Traps:**
- EXPECT ... ON VIOLATION DROP ROW: removes bad rows; WARN: logs violation but keeps row; FAIL: halts pipeline — choose based on data quality tolerance
- STREAM(LIVE.table) reads incrementally from an upstream DLT table — enables multi-hop streaming without duplicates
- DLT resolves dependencies automatically from LIVE.* references — no need to manage execution order manually
- cloud_files() is the DLT-native Auto Loader function — handles schema inference, evolution, and checkpoint management
- DLT expectations are tracked in the Pipeline Events UI — violation rates feed the Data Quality dashboard for SLA monitoring

---

### Q4.12: Unity Catalog Governance: GRANT, REVOKE, Row Filters, Column Masks (Data Governance)

**Question & Concept Overview:**  
Unity Catalog provides fine-grained access control with GRANT/REVOKE at catalog/schema/table/column levels, dynamic row filters for per-user data visibility, and column masks for PII redaction. These replace legacy IP-based ACLs with policy-as-code governance that scales across multi-workspace, multi-regulation BFSI environments.

**SQL Implementation & Query Plan:**
```sql
-- =============================================
-- Unity Catalog Governance
-- EU BFSI — GDPR-Compliant Access Control
-- =============================================

USE CATALOG eu_bfsi_prod;

-- ─── 1. GRANT — Catalog/Schema/Table level ────

-- Catalog-level: USE privilege
GRANT USE CATALOG ON CATALOG eu_bfsi_prod
    TO `data-analysts`, `compliance-officers`, `bi-team`;

-- Schema-level: USE privilege
GRANT USE SCHEMA ON SCHEMA eu_bfsi_prod.gold
    TO `data-analysts`, `bi-team`, `compliance-officers`;

-- Table-level: SELECT only (read-only analysts)
GRANT SELECT ON TABLE eu_bfsi_prod.gold.gold_daily_account_summary
    TO `data-analysts`;

-- Silver: Only compliance and engineering can access
GRANT SELECT ON TABLE eu_bfsi_prod.silver.silver_transactions
    TO `compliance-officers`, `data-engineers`;

-- Full DML for data engineers
GRANT SELECT, INSERT, UPDATE, DELETE, MODIFY
    ON TABLE eu_bfsi_prod.silver.silver_transactions
    TO `data-engineers`;

-- Schema-wide GRANT for gold read
GRANT SELECT ON SCHEMA eu_bfsi_prod.gold
    TO `bi-team`;

-- Function execution
GRANT EXECUTE ON FUNCTION eu_bfsi_prod.security.mask_iban
    TO `data-analysts`;

-- ─── 2. REVOKE ─────────────────────────────────
REVOKE SELECT ON TABLE eu_bfsi_prod.silver.silver_transactions
    FROM `data-analysts`;

-- ─── 3. ROW FILTER — per-user data visibility ──
-- Analysts see only their region's data
CREATE FUNCTION IF NOT EXISTS eu_bfsi_prod.security.filter_by_region (
    row_country_code STRING
)
RETURNS BOOLEAN
RETURN
    is_member('data-engineers')         -- Engineers see all
    OR is_member('compliance-officers') -- Compliance sees all
    OR (
        is_member('uk-analysts')  AND row_country_code = 'GB'
    ) OR (
        is_member('de-analysts')  AND row_country_code = 'DE'
    ) OR (
        is_member('fr-analysts')  AND row_country_code = 'FR'
    );

-- Apply row filter to table
ALTER TABLE eu_bfsi_prod.gold.gold_daily_account_summary
    SET ROW FILTER eu_bfsi_prod.security.filter_by_region
    ON (country_code);

-- ─── 4. COLUMN MASK — PII redaction ────────────
-- Mask account_id for non-privileged users
CREATE FUNCTION IF NOT EXISTS eu_bfsi_prod.security.mask_account_id (
    account_id STRING
)
RETURNS STRING
RETURN CASE
    WHEN is_member('data-engineers')    THEN account_id
    WHEN is_member('compliance-officers') THEN
        CONCAT(LEFT(account_id, 3), '****', RIGHT(account_id, 4))
    ELSE
        SHA2(account_id, 256)  -- Pseudonymize for analysts
END;

ALTER TABLE eu_bfsi_prod.silver.silver_transactions
    ALTER COLUMN account_id
    SET MASK eu_bfsi_prod.security.mask_account_id;

-- ─── 5. Show grants / effective permissions ────
SHOW GRANTS ON TABLE eu_bfsi_prod.silver.silver_transactions;
SHOW GRANTS ON SCHEMA eu_bfsi_prod.silver;
SHOW GRANTS ON CATALOG eu_bfsi_prod;

-- ─── 6. Information schema queries ────────────
SELECT
    table_catalog, table_schema, table_name,
    privilege_type, grantee, is_grantable
FROM eu_bfsi_prod.information_schema.table_privileges
WHERE table_schema = 'silver'
ORDER BY table_name, grantee;

-- ─── 7. Audit access via system tables ─────────
SELECT
    event_time, user_name, action_name,
    request_params.table_full_name,
    response.status_code
FROM system.access.audit
WHERE event_date >= current_date() - INTERVAL 7 DAYS
  AND action_name IN ('SELECT', 'INSERT', 'DELETE', 'MERGE')
  AND request_params.table_full_name
      LIKE 'eu_bfsi_prod.silver%'
ORDER BY event_time DESC
LIMIT 500;
```

**Enterprise Data Scenario:**  
Implementing GDPR Article 25 (data protection by design) at a pan-European insurance company — row filters restrict UK, DE, FR analysts to their jurisdiction's customer data, column masks pseudonymize account IDs for the analytics team, and audit logs feed the quarterly GDPR compliance report automatically from system.access.audit.

**Optimizer Invariants & Performance Traps:**
- Row filters are transparent — users don't see the filter; they simply get fewer rows with no error message, which is the intended behavior for need-to-know data
- Column masks evaluate per-row at query time — use is_member() / is_account_group_member() for group-based logic
- GRANT on SCHEMA applies to all current tables but NOT future tables — use GRANT ON FUTURE TABLES for forward-covering grants
- system.access.audit provides immutable audit log of all data access events — required for GDPR Article 30 records of processing activities
- Unity Catalog GRANTs are workspace-independent — grants made in one workspace apply across all workspaces sharing the metastore

---

### Q4.13: Data Vault 2.0 SQL Patterns: Hub, Link, Satellite (Architecture Patterns)

**Question & Concept Overview:**  
Data Vault 2.0 provides a highly scalable, auditable, and agile data modeling approach for enterprise data warehouses. The three core entity types — Hubs (unique business keys), Links (relationships), and Satellites (context/attributes) — are implemented in Spark SQL with Delta tables and MERGE INTO for parallel, idempotent loads. DV2 is ideal for BFSI environments requiring full auditability.

**SQL Implementation & Query Plan:**
```sql
-- =====================================================================
-- DATA VAULT 2.0 SQL PATTERNS
-- EU BFSI — Payment Transaction Data Vault
-- =====================================================================

USE CATALOG eu_bfsi_prod;
USE SCHEMA dv_raw;  -- Raw Vault schema

-- ─── HUB: Hub_Transaction ─────────────────────────────────────────────
-- Stores unique business keys for transactions
CREATE TABLE IF NOT EXISTS hub_transaction (
    txn_hash_key    STRING  NOT NULL  COMMENT 'MD5(txn_id || source_system)',
    load_date       TIMESTAMP NOT NULL COMMENT 'First seen timestamp',
    record_source   STRING  NOT NULL  COMMENT 'System that first provided this key',
    txn_id          STRING  NOT NULL  COMMENT 'Business key from source'
)
USING DELTA
COMMENT 'Hub — unique transaction business keys'
TBLPROPERTIES ('delta.enableChangeDataFeed'='true');

-- Load Hub (idempotent — only new hash keys inserted)
MERGE INTO hub_transaction AS tgt
USING (
    SELECT DISTINCT
        MD5(CONCAT_WS('||', txn_id, source_system))  AS txn_hash_key,
        MIN(_ingest_ts) OVER (PARTITION BY txn_id)   AS load_date,
        source_system                                 AS record_source,
        txn_id
    FROM eu_bfsi_prod.bronze.bronze_transactions
    WHERE ingest_date = current_date()
) AS src
ON tgt.txn_hash_key = src.txn_hash_key
WHEN NOT MATCHED THEN INSERT *;

-- ─── HUB: Hub_Account ─────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS hub_account (
    acct_hash_key   STRING  NOT NULL,
    load_date       TIMESTAMP NOT NULL,
    record_source   STRING  NOT NULL,
    account_id      STRING  NOT NULL
)
USING DELTA COMMENT 'Hub — unique account business keys';

-- ─── LINK: Link_Transaction_Account ───────────────────────────────────
-- Represents the relationship: Transaction involves Account
CREATE TABLE IF NOT EXISTS link_txn_account (
    link_hash_key   STRING  NOT NULL  COMMENT 'MD5(txn_hash_key || acct_hash_key)',
    load_date       TIMESTAMP NOT NULL,
    record_source   STRING  NOT NULL,
    txn_hash_key    STRING  NOT NULL  COMMENT 'FK → hub_transaction',
    acct_hash_key   STRING  NOT NULL  COMMENT 'FK → hub_account'
)
USING DELTA COMMENT 'Link — transaction-to-account relationship';

MERGE INTO link_txn_account AS tgt
USING (
    SELECT
        MD5(CONCAT_WS('||',
            MD5(CONCAT_WS('||', b.txn_id, b.source_system)),
            MD5(b.account_id)
        ))                                          AS link_hash_key,
        b._ingest_ts                                AS load_date,
        b.source_system                             AS record_source,
        MD5(CONCAT_WS('||', b.txn_id, b.source_system)) AS txn_hash_key,
        MD5(b.account_id)                           AS acct_hash_key
    FROM eu_bfsi_prod.bronze.bronze_transactions b
    WHERE ingest_date = current_date()
) AS src
ON tgt.link_hash_key = src.link_hash_key
WHEN NOT MATCHED THEN INSERT *;

-- ─── SATELLITE: Sat_Transaction_Details ───────────────────────────────
-- Stores context/attributes for transactions (versioned)
CREATE TABLE IF NOT EXISTS sat_transaction_details (
    txn_hash_key    STRING  NOT NULL  COMMENT 'FK → hub_transaction',
    load_date       TIMESTAMP NOT NULL COMMENT 'Record effective from',
    load_end_date   TIMESTAMP         COMMENT 'NULL = current; populated when superseded',
    record_source   STRING  NOT NULL,
    hash_diff       STRING  NOT NULL  COMMENT 'MD5 of all satellite attributes for change detection',
    -- Descriptive attributes
    txn_amount      DECIMAL(18,4),
    txn_currency    STRING(3),
    txn_type        STRING,
    txn_status      STRING,
    txn_timestamp   TIMESTAMP,
    source_system   STRING
)
USING DELTA
COMMENT 'Satellite — transaction detail attributes with full history'
TBLPROPERTIES ('delta.enableChangeDataFeed'='true');

-- Load Satellite (insert-only, no updates)
INSERT INTO sat_transaction_details
SELECT
    MD5(CONCAT_WS('||', b.txn_id, b.source_system))  AS txn_hash_key,
    b._ingest_ts                                       AS load_date,
    NULL                                               AS load_end_date,
    b.source_system                                    AS record_source,
    MD5(CONCAT_WS('||',
        COALESCE(CAST(b.txn_raw_amount AS STRING), ''),
        COALESCE(b.txn_currency, ''),
        COALESCE(b.txn_type, ''),
        COALESCE(b.txn_status, ''),
        COALESCE(CAST(b.txn_timestamp_raw AS STRING), '')
    ))                                                 AS hash_diff,
    CAST(REGEXP_REPLACE(b.txn_raw_amount, '[^0-9.]', '') AS DECIMAL(18,4)) AS txn_amount,
    UPPER(TRIM(b.txn_currency))                        AS txn_currency,
    b.txn_type,
    b.txn_status,
    CAST(b.txn_timestamp_raw AS TIMESTAMP)             AS txn_timestamp,
    b.source_system
FROM eu_bfsi_prod.bronze.bronze_transactions b
WHERE NOT EXISTS (
    -- Only insert if hash_diff changed (new attributes)
    SELECT 1 FROM sat_transaction_details s
    WHERE s.txn_hash_key = MD5(CONCAT_WS('||', b.txn_id, b.source_system))
      AND s.hash_diff = MD5(CONCAT_WS('||',
            COALESCE(CAST(b.txn_raw_amount AS STRING), ''),
            COALESCE(b.txn_currency, ''),
            COALESCE(b.txn_type, ''),
            COALESCE(b.txn_status, ''),
            COALESCE(CAST(b.txn_timestamp_raw AS STRING), '')
        ))
      AND s.load_end_date IS NULL
);
```

**Enterprise Data Scenario:**  
Building a Data Vault 2.0 raw vault for a pan-European bank's enterprise data warehouse — Hub/Link/Sat pattern absorbs schema changes from Core Banking, SWIFT, and PSD2 Open Banking feeds without breaking downstream consumers, while the hash-key approach enables parallel loading of 200M daily records across 50 Databricks worker nodes.

**Optimizer Invariants & Performance Traps:**
- Hub stores ONLY the business key and hash key — all attributes belong in satellites; this enforces separation of concerns
- Hash keys (MD5/SHA1 of business key + source) enable parallel loading of all vault entities without sequence generators
- Satellites are insert-only append tables — hash_diff change detection avoids re-inserting unchanged records
- Links require all related hub hash keys — they store relationships with timestamps, enabling full temporal analysis of relationship history
- DV2's parallel load pattern (Hub/Link/Sat load simultaneously) scales linearly — a 1-hour sequential load becomes 15 minutes with parallel Databricks jobs

---

### Q4.14: GDPR Erasure with DELETE and VACUUM (Data Governance)

**Question & Concept Overview:**  
GDPR Article 17 (Right to Erasure) requires physically removing personal data across all layers of the data lake within 30 days of a verified erasure request. Delta's DELETE combined with column mapping and VACUUM provides a compliant erasure workflow. The challenge is cascading deletions across Bronze, Silver, and Gold layers while maintaining referential integrity.

**SQL Implementation & Query Plan:**
```sql
-- =============================================
-- GDPR Right to Erasure — Full Pipeline
-- EU BFSI — Customer Data Deletion Workflow
-- Author: Santosh Jammi, TCS Data Engineering
-- =============================================

USE CATALOG eu_bfsi_prod;

-- ─── STEP 0: Create erasure request tracking table ────
CREATE TABLE IF NOT EXISTS eu_bfsi_prod.governance.gdpr_erasure_requests (
    request_id          STRING NOT NULL,
    customer_id         STRING NOT NULL,
    requested_by        STRING,
    request_date        DATE NOT NULL,
    approved_date       DATE,
    approval_status     STRING COMMENT 'PENDING | APPROVED | REJECTED | COMPLETED',
    erasure_scope       ARRAY<STRING> COMMENT 'List of tables to erase from',
    completed_ts        TIMESTAMP,
    completion_notes    STRING
) USING DELTA;

-- ─── STEP 1: Approve and scope the erasure request ────
INSERT INTO eu_bfsi_prod.governance.gdpr_erasure_requests
VALUES (
    'GDPR-2024-001247',
    'CUST-EU-83847291',
    'dpo@eurobank.eu',
    '2024-12-15',
    '2024-12-16',
    'APPROVED',
    ARRAY(
        'silver.silver_customers',
        'silver.silver_accounts',
        'silver.silver_transactions',
        'bronze.bronze_transactions',
        'gold.gold_daily_account_summary'
    ),
    NULL,
    NULL
);

-- ─── STEP 2: Collect all affected identifiers ─────────
CREATE OR REPLACE TEMPORARY VIEW v_erasure_scope AS
SELECT
    r.customer_id,
    a.account_id,
    r.request_id
FROM eu_bfsi_prod.governance.gdpr_erasure_requests r
JOIN eu_bfsi_prod.silver.silver_accounts a
    ON r.customer_id = a.customer_id
WHERE r.request_id = 'GDPR-2024-001247'
  AND r.approval_status = 'APPROVED';

-- ─── STEP 3: Delete PII from Silver customers ────────
DELETE FROM eu_bfsi_prod.silver.silver_customers
WHERE customer_id IN (
    SELECT customer_id FROM v_erasure_scope
);

-- ─── STEP 4: Pseudonymize transaction references ──────
-- (Cannot delete transactions — needed for financial audit)
-- Replace PII fields with pseudonymous tokens
UPDATE eu_bfsi_prod.silver.silver_transactions
SET
    account_id      = SHA2(CONCAT(account_id, 'GDPR_SALT_2024'), 256),
    counterparty_id = SHA2(CONCAT(counterparty_id, 'GDPR_SALT_2024'), 256)
WHERE account_id IN (
    SELECT account_id FROM v_erasure_scope
);

-- ─── STEP 5: Delete from bronze (raw data) ───────────
DELETE FROM eu_bfsi_prod.bronze.bronze_transactions
WHERE account_id IN (
    SELECT account_id FROM v_erasure_scope
);

-- ─── STEP 6: Delete from gold aggregations ───────────
DELETE FROM eu_bfsi_prod.gold.gold_daily_account_summary
WHERE account_id IN (
    SELECT account_id FROM v_erasure_scope
);

-- ─── STEP 7: Physical file deletion with VACUUM ───────
-- CRITICAL: Set retention to 0 ONLY for GDPR compliance
-- First, disable safety check:
SET spark.databricks.delta.retentionDurationCheck.enabled = false;

VACUUM eu_bfsi_prod.silver.silver_customers RETAIN 0 HOURS;
VACUUM eu_bfsi_prod.bronze.bronze_transactions RETAIN 0 HOURS;
VACUUM eu_bfsi_prod.silver.silver_transactions RETAIN 0 HOURS;
VACUUM eu_bfsi_prod.gold.gold_daily_account_summary RETAIN 0 HOURS;

-- Re-enable safety check
SET spark.databricks.delta.retentionDurationCheck.enabled = true;

-- ─── STEP 8: Mark request as completed ───────────────
UPDATE eu_bfsi_prod.governance.gdpr_erasure_requests
SET
    approval_status = 'COMPLETED',
    completed_ts    = current_timestamp(),
    completion_notes = 'PII deleted from 4 tables; transactions pseudonymized; VACUUM completed'
WHERE request_id = 'GDPR-2024-001247';

-- ─── STEP 9: Verify erasure ───────────────────────────
SELECT COUNT(*) AS remaining_records
FROM eu_bfsi_prod.silver.silver_customers
WHERE customer_id = 'CUST-EU-83847291';
-- Expected: 0
```

**Enterprise Data Scenario:**  
GDPR Article 17 erasure automation at a European digital bank — a former customer exercises their right to erasure; the workflow deletes PII from Silver/Bronze/Gold layers, pseudonymizes transaction references (preserving financial audit trail), runs VACUUM to purge old file versions, and generates a compliance certificate within 72 hours of the request.

**Optimizer Invariants & Performance Traps:**
- VACUUM RETAIN 0 HOURS physically removes Parquet files from storage — do this ONLY for GDPR; normal operations should keep 7+ days
- Disable retentionDurationCheck only temporarily and in the scope of GDPR deletion — never as a permanent setting
- Financial transactions often cannot be deleted (money laundering regulations require 5-7 year retention) — pseudonymization with SHA256 is the compliant alternative
- Time travel to versions before deletion becomes impossible after VACUUM — this is intentional for GDPR compliance
- Maintain the erasure_requests audit table permanently — it's your proof of compliance without retaining the erased PII

---

### Q4.15: FinOps Table Partitioning and Cost Optimization Strategies (FinOps & Performance)

**Question & Concept Overview:**  
FinOps in Azure Databricks requires minimizing DBU consumption and ADLS storage costs while maintaining query performance SLAs. Strategic partitioning, Liquid Clustering, Photon engine optimization, and compute auto-scaling are the primary levers. Poor partitioning (too many small files or over-partitioned tables) is the #1 cause of runaway Databricks costs in BFSI platforms.

**SQL Implementation & Query Plan:**
```sql
-- =============================================
-- FinOps Partitioning & Cost Optimization
-- EU BFSI — Azure Databricks Cost Engineering
-- =============================================

USE CATALOG eu_bfsi_prod;
USE SCHEMA silver;

-- ─── 1. Diagnose partition health ─────────────
-- Check number of files and sizes per partition
SELECT
    partition.txn_date,
    COUNT(*)                AS num_files,
    SUM(size) / 1e9         AS total_size_gb,
    AVG(size) / 1e6         AS avg_file_size_mb,
    MIN(size) / 1e3         AS min_file_kb,
    MAX(size) / 1e6         AS max_file_mb,
    SUM(CASE WHEN size < 1048576 THEN 1 ELSE 0 END) AS tiny_files_under_1mb
FROM (
    DESCRIBE DETAIL eu_bfsi_prod.silver.silver_transactions
)
CROSS JOIN (
    SHOW PARTITIONS eu_bfsi_prod.silver.silver_transactions
) partition
GROUP BY partition.txn_date
ORDER BY tiny_files_under_1mb DESC
LIMIT 30;

-- ─── 2. Optimal partitioning strategies ───────

-- Strategy A: Date partitioning (most common for time-series BFSI data)
-- Good for: daily batch queries, time-range scans
-- Target: 128MB - 1GB per partition file
CREATE TABLE IF NOT EXISTS silver_transactions_v2
USING DELTA
PARTITIONED BY (txn_date)  -- ~1 partition per day, sized for daily volume
COMMENT 'Date-partitioned silver transactions';

-- Strategy B: Liquid Clustering (DBR 13.3+ — preferred over static partitioning)
-- Allows incremental re-clustering without full rewrites
CREATE TABLE IF NOT EXISTS silver_transactions_lc
USING DELTA
CLUSTER BY (txn_date, account_id, txn_currency)
COMMENT 'Liquid-clustered silver transactions — auto-optimized';

-- ─── 3. Auto-optimize settings for cost control ─
ALTER TABLE silver_transactions
SET TBLPROPERTIES (
    'delta.autoOptimize.optimizeWrite'   = 'true',  -- Bin-pack on write
    'delta.autoOptimize.autoCompact'     = 'true',  -- Compact in background
    'delta.targetFileSize'               = '134217728',  -- 128MB target
    'delta.tuneFileSizesForRewrites'     = 'true'   -- Optimize for MERGE
);

-- ─── 4. Statistics collection for better plans ──
ANALYZE TABLE silver_transactions
COMPUTE STATISTICS FOR ALL COLUMNS;

-- ─── 5. Partition pruning verification ──────────
-- EXPLAIN shows partition skipping
EXPLAIN COST
SELECT COUNT(*)
FROM silver_transactions
WHERE txn_date = '2024-12-31';  -- Should show: PartitionFilters: [txn_date = 2024-12-31]

-- ─── 6. Archive cold partitions to cheaper storage
-- Move partitions older than 2 years to archive tier
CREATE TABLE IF NOT EXISTS eu_bfsi_prod.archive.silver_transactions_archive
USING DELTA
LOCATION 'abfss://archive@euadlsarchive.dfs.core.windows.net/transactions/'
COMMENT 'Archive — transactions > 2 years (Cool tier ADLS)';

-- Insert old data into archive then delete from hot
INSERT INTO eu_bfsi_prod.archive.silver_transactions_archive
SELECT * FROM eu_bfsi_prod.silver.silver_transactions
WHERE txn_date < DATE_SUB(current_date(), 730);

-- Then delete from hot tier (after verifying archive)
DELETE FROM eu_bfsi_prod.silver.silver_transactions
WHERE txn_date < DATE_SUB(current_date(), 730);
VACUUM eu_bfsi_prod.silver.silver_transactions RETAIN 168 HOURS;

-- ─── 7. Query optimization via SET configs ──────
-- Reduce shuffle partitions for small datasets (cost saving)
SET spark.sql.shuffle.partitions = 200;  -- Default 200; reduce for < 10GB queries

-- Enable AQE (default in Spark 3.x)
SET spark.sql.adaptive.enabled = true;
SET spark.sql.adaptive.coalescePartitions.enabled = true;
SET spark.sql.adaptive.skewJoin.enabled = true;

-- ─── 8. Bloom filter for high-cardinality lookups
CREATE BLOOMFILTER INDEX ON TABLE silver_transactions
FOR COLUMNS (
    txn_id OPTIONS (fpp=0.001, numItems=5000000000),
    account_id OPTIONS (fpp=0.01, numItems=10000000)
);
```

**Enterprise Data Scenario:**  
FinOps optimization at a European digital bank where uncontrolled Databricks spend had grown 340% in 18 months — audit reveals 2.3 billion tiny files from 3 years of unoptimized streaming writes. Liquid Clustering + OPTIMIZE + VACUUM + ADLS tiering reduces monthly Azure spend by 58% while improving P95 query latency from 4 minutes to 35 seconds.

**Optimizer Invariants & Performance Traps:**
- Target 128MB-1GB file sizes in Delta — tiny files (<1MB) cause excessive file listing overhead and slow queries significantly
- Liquid Clustering outperforms static partitioning for high-cardinality dimensions — it clusters on multiple columns without exploding partition count
- ADLS Gen2 tiering: Hot (frequently accessed), Cool (infrequently accessed, cheaper), Archive (rare access, much cheaper) — move >2-year data to Cool tier for 50% storage cost saving
- Adaptive Query Execution (AQE) dynamically coalesces shuffle partitions, handles skew joins, and switches join strategies at runtime — keep enabled for all production clusters
- Bloom filters dramatically speed up equality lookups on high-cardinality columns (txn_id, account_id) — each file's bloom filter prevents unnecessary file reads for point lookups

---

### Q4.16: Microsoft Fabric Lakehouse SQL Endpoint and Cross-Workspace Queries (Microsoft Fabric)

**Question & Concept Overview:**  
Microsoft Fabric's Lakehouse exposes a SQL Analytics Endpoint (formerly SQL Server endpoint) that supports T-SQL queries directly against Delta tables in OneLake. The unified OneLake storage model enables cross-workspace queries and shortcut-based data sharing without data movement. Fabric's Direct Lake mode powers Power BI with columnar in-memory performance over Delta files.

**SQL Implementation & Query Plan:**
```sql
-- =============================================
-- Microsoft Fabric Lakehouse SQL
-- EU BFSI — Cross-Workspace Analytics
-- =============================================

-- ─── 1. Fabric SQL Analytics Endpoint (T-SQL compatible) ─
-- Access via: SQL connection string in Fabric workspace
-- jdbc:sqlserver://<workspace>.datawarehouse.fabric.microsoft.com

-- Query Delta table via SQL Analytics Endpoint
SELECT TOP 100
    txn_id,
    account_id,
    txn_amount,
    txn_currency,
    txn_date
FROM [eu_bfsi_lakehouse].[dbo].[silver_transactions]
WHERE txn_date = CAST(GETDATE() AS DATE)
  AND txn_amount > 10000
ORDER BY txn_amount DESC;

-- ─── 2. OneLake Shortcut — cross-workspace data sharing
-- (Configured via Fabric portal; queries are transparent)
-- Shortcut from workspace B to workspace A's Delta table:
SELECT COUNT(*), SUM(txn_amount_eur)
FROM [eu_analytics_lakehouse].[dbo].[silver_transactions]  -- Shortcut to prod lakehouse
WHERE txn_date >= DATEADD(DAY, -30, GETDATE());

-- ─── 3. Fabric Warehouse — cross-item queries ─────────────
-- Query across Lakehouse and Warehouse in same workspace
SELECT
    lh.account_id,
    lh.txn_amount_eur,
    wh.customer_segment,
    wh.relationship_manager
FROM [eu_bfsi_lakehouse].[dbo].[silver_transactions] lh  -- Lakehouse (Delta)
JOIN [eu_bfsi_warehouse].[dbo].[dim_customers] wh         -- Fabric Warehouse table
    ON lh.account_id = wh.account_id
WHERE lh.txn_date = CAST(GETDATE()-1 AS DATE);

-- ─── 4. Azure Databricks ↔ Fabric interop ────────────────
-- Option A: Fabric shortcut to ADLS Gen2 (where Databricks Delta tables live)
-- Create shortcut in Fabric to:
-- abfss://silver@euadlsprod.dfs.core.windows.net/silver_transactions/
-- → Available as: [eu_bfsi_lakehouse].[dbo].[silver_transactions]

-- Option B: From Databricks, write to Fabric OneLake via ABFSS connector
-- Databricks SQL writing to Fabric OneLake:
CREATE TABLE IF NOT EXISTS fabric.eu_bfsi_lakehouse.silver_transactions_export
USING DELTA
LOCATION 'abfss://eu_bfsi_lakehouse@onelake.dfs.fabric.microsoft.com/silver_transactions/'
AS SELECT * FROM eu_bfsi_prod.silver.silver_transactions
WHERE txn_date = current_date() - INTERVAL 1 DAY;

-- ─── 5. Direct Lake — Fabric Power BI optimization ────────
-- Direct Lake reads Delta Parquet files directly into memory
-- No import, no DirectQuery latency — native columnar performance
-- Trigger Direct Lake framing refresh via SQL:
-- EXEC sp_refreshsqlmodule '[dbo].[silver_transactions]';

-- ─── 6. Fabric SQL — GDPR-compliant view ─────────────────
CREATE OR ALTER VIEW [dbo].[v_silver_transactions_masked]
AS
SELECT
    txn_id,
    -- Mask account_id using SQL dynamic data masking
    CASE
        WHEN IS_MEMBER('DataEngineers') = 1 THEN account_id
        ELSE CONCAT('****', RIGHT(account_id, 6))
    END AS account_id,
    txn_amount,
    txn_currency,
    txn_date,
    txn_type
FROM [dbo].[silver_transactions];

-- Grant access to view (not underlying table)
GRANT SELECT ON [dbo].[v_silver_transactions_masked]
    TO [eu-analysts-sg@bank.eu];
```

**Enterprise Data Scenario:**  
A European universal bank's analytics modernization — Azure Databricks runs the heavy ETL (Bronze→Silver→Gold via DLT), writes Delta tables to ADLS Gen2, and Fabric shortcuts expose the same tables to Power BI via Direct Lake, eliminating the legacy SQL Server data warehouse while reducing time-to-insight from daily batch to real-time.

**Optimizer Invariants & Performance Traps:**
- Fabric SQL Analytics Endpoint is T-SQL compatible — existing SQL Server queries work with minimal changes, lowering migration effort
- OneLake Shortcuts eliminate data duplication — the same Delta file is queryable from Databricks, Fabric Lakehouse, and Fabric Warehouse simultaneously
- Direct Lake mode achieves Power BI report render times under 2 seconds on billion-row Delta tables — it frames data into columnar memory cache on demand
- ABFSS connector allows Databricks to write directly to Fabric OneLake — enabling hybrid architectures where Databricks processes and Fabric serves
- Cross-workspace queries in Fabric use the workspace identity for authorization — ensure OneLake permissions are configured at both workspace and item levels

---

### Q4.17: Databricks SQL Functions and Procedures (CREATE FUNCTION, SQL UDF) (Reusable SQL Components)

**Question & Concept Overview:**  
Databricks supports SQL User Defined Functions (UDFs), Python UDFs registered in Unity Catalog, and stored procedures-like patterns using EXECUTE IMMEDIATE. SQL UDFs enable reusable, versionable business logic — critical for regulatory calculations (PD, LGD, risk scoring) that must be consistent across all pipelines and consumers.

**SQL Implementation & Query Plan:**
```sql
-- =============================================
-- SQL Functions and Reusable Logic
-- EU BFSI — Regulatory Calculation Library
-- =============================================

USE CATALOG eu_bfsi_prod;

-- ─── 1. Scalar SQL UDF ────────────────────────
CREATE OR REPLACE FUNCTION eu_bfsi_prod.utils.calculate_ead (
    outstanding_balance DECIMAL(18, 4),
    undrawn_commitment  DECIMAL(18, 4),
    credit_conversion_factor DECIMAL(5, 4)  -- CCF: 0.0 to 1.0
)
RETURNS DECIMAL(18, 4)
COMMENT 'Exposure at Default (EAD) = Outstanding + CCF * Undrawn. Used for COREP credit risk.'
RETURN outstanding_balance + (credit_conversion_factor * undrawn_commitment);

-- Usage:
SELECT
    account_id,
    eu_bfsi_prod.utils.calculate_ead(
        outstanding_balance,
        undrawn_commitment,
        0.75  -- 75% CCF for revolving facilities
    ) AS ead_exposure
FROM eu_bfsi_prod.silver.silver_credit_facilities;

-- ─── 2. Table-valued SQL UDF ──────────────────
CREATE OR REPLACE FUNCTION eu_bfsi_prod.utils.get_account_transactions (
    p_account_id STRING,
    p_from_date  DATE,
    p_to_date    DATE
)
RETURNS TABLE (
    txn_id          STRING,
    txn_amount      DECIMAL(18,4),
    txn_currency    STRING,
    txn_date        DATE,
    txn_type        STRING
)
COMMENT 'Returns transactions for an account in a date range'
RETURN
SELECT txn_id, txn_amount, txn_currency, txn_date, txn_type
FROM eu_bfsi_prod.silver.silver_transactions
WHERE account_id = p_account_id
  AND txn_date BETWEEN p_from_date AND p_to_date;

-- Usage:
SELECT * FROM eu_bfsi_prod.utils.get_account_transactions(
    'ACC-EU-12345678', '2024-01-01', '2024-12-31'
);

-- ─── 3. Risk scoring UDF with CASE logic ──────
CREATE OR REPLACE FUNCTION eu_bfsi_prod.utils.calculate_risk_score (
    days_past_due       INT,
    debt_to_income      DECIMAL(5,4),
    credit_utilization  DECIMAL(5,4),
    num_recent_inquiries INT
)
RETURNS INT
COMMENT 'Simplified credit risk score 0-100. Higher = higher risk.'
RETURN
    -- Days past due component (40 pts max)
    CASE
        WHEN days_past_due = 0          THEN 0
        WHEN days_past_due <= 30        THEN 15
        WHEN days_past_due <= 60        THEN 25
        WHEN days_past_due <= 90        THEN 35
        ELSE                                 40
    END
    -- DTI component (30 pts max)
    + CASE
        WHEN debt_to_income < 0.35      THEN 0
        WHEN debt_to_income < 0.50      THEN 10
        WHEN debt_to_income < 0.65      THEN 20
        ELSE                                 30
    END
    -- Utilization component (20 pts max)
    + CASE
        WHEN credit_utilization < 0.30  THEN 0
        WHEN credit_utilization < 0.60  THEN 7
        WHEN credit_utilization < 0.80  THEN 14
        ELSE                                 20
    END
    -- Inquiries component (10 pts max)
    + LEAST(num_recent_inquiries * 2, 10);

-- ─── 4. EXECUTE IMMEDIATE — dynamic SQL ───────
-- Stored procedure-like pattern in Databricks
DECLARE table_name STRING DEFAULT 'silver_transactions';
DECLARE schema_name STRING DEFAULT 'silver';
DECLARE row_count BIGINT;

EXECUTE IMMEDIATE
    CONCAT('SELECT COUNT(*) FROM eu_bfsi_prod.', schema_name, '.', table_name,
           ' WHERE txn_date = current_date()')
    INTO row_count;

SELECT row_count AS todays_record_count;

-- ─── 5. Grant function access ─────────────────
GRANT EXECUTE ON FUNCTION eu_bfsi_prod.utils.calculate_ead
    TO `risk-analysts`, `compliance-officers`, `data-engineers`;

GRANT EXECUTE ON FUNCTION eu_bfsi_prod.utils.get_account_transactions
    TO `data-analysts`;

-- ─── 6. List all functions in schema ──────────
SHOW FUNCTIONS IN eu_bfsi_prod.utils;
```

**Enterprise Data Scenario:**  
Regulatory calculation library at a European bank's risk platform — SQL UDFs encapsulate EAD, LGD, and credit scoring formulas reviewed and approved by the Model Risk Management team. All 23 pipelines (credit risk, stress testing, COREP) call the same UDF, ensuring a single change to the CCF parameter updates all downstream calculations simultaneously.

**Optimizer Invariants & Performance Traps:**
- SQL UDFs in Unity Catalog are first-class securables — GRANT EXECUTE controls who can call them, enabling function-level access control
- Table-valued functions (RETURNS TABLE) are composable — use them in FROM clause like a table, enabling modular pipeline building
- SQL UDFs are inlined into the query plan when possible — no serialization overhead unlike Python UDFs which require inter-process communication
- EXECUTE IMMEDIATE enables parameterized dynamic SQL — use for metadata-driven pipeline frameworks where table/column names vary
- Register business-critical formulas (EAD, LGD, PD) as versioned SQL UDFs — ensures calculation consistency across 50+ pipelines accessing the same regulatory logic

---

### Q4.18: Data Quality Checks in SQL (Expectations, DQ Framework) (Data Quality)

**Question & Concept Overview:**  
Enterprise-grade data quality requires declarative rules, automated monitoring, and integration with pipeline execution. In Databricks, DQ is implemented via DLT expectations (declarative), SQL-based assertion tables, and Great Expectations-style check patterns. Financial regulatory data must meet SLA-bound quality thresholds — failed DQ can trigger pipeline halts and alert the data engineering team.

**SQL Implementation & Query Plan:**
```sql
-- =============================================
-- SQL Data Quality Framework
-- EU BFSI — Payment Data Quality Checks
-- =============================================

USE CATALOG eu_bfsi_prod;
USE SCHEMA governance;

-- ─── 1. DQ Rules Catalog Table ────────────────
CREATE TABLE IF NOT EXISTS dq_rules (
    rule_id         STRING NOT NULL,
    table_fqn       STRING NOT NULL COMMENT 'catalog.schema.table',
    rule_name       STRING NOT NULL,
    rule_type       STRING COMMENT 'NOT_NULL | RANGE | FORMAT | REFERENTIAL | CUSTOM_SQL',
    column_name     STRING,
    rule_sql        STRING NOT NULL COMMENT 'SQL expression that returns TRUE for VALID rows',
    severity        STRING COMMENT 'CRITICAL | HIGH | MEDIUM | LOW',
    threshold_pct   DECIMAL(5,2) COMMENT 'Acceptable fail % (e.g. 0.0 = zero tolerance)',
    owner           STRING,
    active          BOOLEAN DEFAULT TRUE
) USING DELTA;

-- Load rules
INSERT INTO dq_rules VALUES
('DQ-001', 'eu_bfsi_prod.silver.silver_transactions', 'txn_id_not_null',
 'NOT_NULL', 'txn_id', 'txn_id IS NOT NULL', 'CRITICAL', 0.0, 'data-eng@bank.eu', true),
('DQ-002', 'eu_bfsi_prod.silver.silver_transactions', 'positive_amount',
 'RANGE', 'txn_amount', 'txn_amount > 0', 'CRITICAL', 0.0, 'data-eng@bank.eu', true),
('DQ-003', 'eu_bfsi_prod.silver.silver_transactions', 'valid_currency',
 'FORMAT', 'txn_currency', "txn_currency RLIKE '^[A-Z]{3}$'", 'HIGH', 0.01, 'data-eng@bank.eu', true),
('DQ-004', 'eu_bfsi_prod.silver.silver_transactions', 'future_timestamp',
 'RANGE', 'txn_timestamp', 'txn_timestamp <= current_timestamp()', 'HIGH', 0.0, 'data-eng@bank.eu', true),
('DQ-005', 'eu_bfsi_prod.silver.silver_transactions', 'valid_txn_type',
 'FORMAT', 'txn_type', "txn_type IN ('DEBIT','CREDIT','FEE','REVERSAL','INTERNAL')", 'MEDIUM', 0.1, 'data-eng@bank.eu', true);

-- ─── 2. DQ Results Table ──────────────────────
CREATE TABLE IF NOT EXISTS dq_results (
    run_id          STRING NOT NULL,
    run_ts          TIMESTAMP NOT NULL,
    rule_id         STRING NOT NULL,
    table_fqn       STRING NOT NULL,
    total_rows      BIGINT,
    passing_rows    BIGINT,
    failing_rows    BIGINT,
    pass_rate_pct   DECIMAL(5,2),
    severity        STRING,
    threshold_pct   DECIMAL(5,2),
    dq_status       STRING COMMENT 'PASS | FAIL | WARN',
    sample_failures STRING COMMENT 'JSON sample of failed rows'
) USING DELTA;

-- ─── 3. DQ Check Execution (run per-table) ────
INSERT INTO dq_results
WITH base AS (
    SELECT
        '${run_id}'                             AS run_id,
        current_timestamp()                     AS run_ts,
        r.rule_id,
        r.table_fqn,
        r.severity,
        r.threshold_pct
    FROM dq_rules r
    WHERE r.table_fqn = 'eu_bfsi_prod.silver.silver_transactions'
      AND r.active = true
),
check_results AS (
    SELECT
        'DQ-001' AS rule_id,
        COUNT(*) AS total_rows,
        SUM(CASE WHEN txn_id IS NOT NULL THEN 1 ELSE 0 END) AS passing_rows,
        SUM(CASE WHEN txn_id IS NULL THEN 1 ELSE 0 END) AS failing_rows
    FROM eu_bfsi_prod.silver.silver_transactions
    WHERE txn_date = current_date()
    UNION ALL
    SELECT 'DQ-002', COUNT(*),
        SUM(CASE WHEN txn_amount > 0 THEN 1 ELSE 0 END),
        SUM(CASE WHEN txn_amount <= 0 THEN 1 ELSE 0 END)
    FROM eu_bfsi_prod.silver.silver_transactions WHERE txn_date = current_date()
    UNION ALL
    SELECT 'DQ-003', COUNT(*),
        SUM(CASE WHEN txn_currency RLIKE '^[A-Z]{3}$' THEN 1 ELSE 0 END),
        SUM(CASE WHEN NOT (txn_currency RLIKE '^[A-Z]{3}$') THEN 1 ELSE 0 END)
    FROM eu_bfsi_prod.silver.silver_transactions WHERE txn_date = current_date()
)
SELECT
    b.run_id,
    b.run_ts,
    b.rule_id,
    b.table_fqn,
    cr.total_rows,
    cr.passing_rows,
    cr.failing_rows,
    ROUND(100.0 * cr.passing_rows / cr.total_rows, 4) AS pass_rate_pct,
    b.severity,
    b.threshold_pct,
    CASE
        WHEN 100.0 * cr.failing_rows / cr.total_rows <= b.threshold_pct THEN 'PASS'
        WHEN b.severity = 'CRITICAL' THEN 'FAIL'
        ELSE 'WARN'
    END AS dq_status,
    NULL AS sample_failures
FROM base b
JOIN check_results cr ON b.rule_id = cr.rule_id;

-- ─── 4. DQ Dashboard Query ────────────────────
SELECT
    run_ts,
    rule_id,
    table_fqn,
    total_rows,
    failing_rows,
    pass_rate_pct,
    severity,
    dq_status
FROM dq_results
WHERE DATE(run_ts) = current_date()
ORDER BY dq_status DESC, severity, pass_rate_pct;
```

**Enterprise Data Scenario:**  
Regulatory data quality gate at a European bank's FINREP reporting pipeline — 47 SQL-based DQ rules run after each silver layer load; CRITICAL rule failures halt the gold layer job and alert the data engineering on-call via Teams webhook, preventing out-of-tolerance data from reaching the regulatory submission portal.

**Optimizer Invariants & Performance Traps:**
- DQ rules as data (not code) enables non-engineers to configure quality checks via a UI or spreadsheet import — accelerates governance adoption
- DLT EXPECT clauses are the most elegant option for streaming pipelines; SQL assertion tables work better for batch-oriented governance frameworks
- Threshold-based pass/fail (e.g., 0.01% fail rate allowed for optional fields) prevents false alarms from genuinely nullable columns
- Store sample failing rows as JSON in dq_results — enables root-cause analysis without re-running the check
- Integrate DQ results with Databricks Asset Bundles monitoring and PagerDuty/Teams alerts to close the incident response loop

---

### Q4.19: APPLY CHANGES INTO — DLT CDC Pattern (Delta Live Tables)

**Question & Concept Overview:**  
APPLY CHANGES INTO is a DLT-exclusive SQL command that implements CDC (Change Data Capture) processing. It consumes ordered change events from a source (insert/update/delete) and applies them to a target table with automatic ordering, deduplication, and SCD Type 1 or Type 2 handling. This is the most sophisticated streaming CDC pattern available in Databricks.

**SQL Implementation & Query Plan:**
```sql
-- =============================================
-- APPLY CHANGES INTO — DLT CDC Pipeline
-- EU BFSI — Core Banking Account CDC
-- =============================================
-- File: /pipeline/cdc_account_pipeline.sql
-- Pipeline mode: Enhanced Autoscaling, Triggered
-- =============================================

-- ─── SOURCE: Streaming CDC events from Debezium/Kafka ─
CREATE OR REFRESH STREAMING TABLE bronze_account_cdc
COMMENT 'Bronze — raw CDC events from Core Banking Debezium connector'
AS SELECT
    CAST(key AS STRING)                     AS account_id,
    get_json_object(CAST(value AS STRING), '$.op')          AS operation,
    get_json_object(CAST(value AS STRING), '$.ts_ms')       AS event_ts_ms,
    get_json_object(CAST(value AS STRING), '$.after.account_id')       AS after_account_id,
    get_json_object(CAST(value AS STRING), '$.after.account_type')     AS after_account_type,
    get_json_object(CAST(value AS STRING), '$.after.risk_tier')        AS after_risk_tier,
    get_json_object(CAST(value AS STRING), '$.after.kyc_status')       AS after_kyc_status,
    get_json_object(CAST(value AS STRING), '$.after.current_balance')  AS after_current_balance,
    get_json_object(CAST(value AS STRING), '$.after.account_status')   AS after_account_status,
    _metadata.timestamp                     AS kafka_ingested_ts
FROM cloud_files(
    'abfss://kafka-dump@euadlsprod.dfs.core.windows.net/core-banking-cdc/',
    'json'
);

-- ─── APPLY CHANGES INTO — SCD Type 1 (latest wins) ───
APPLY CHANGES INTO LIVE.silver_accounts_scd1
FROM STREAM(LIVE.bronze_account_cdc)
KEYS (account_id)
APPLY AS DELETE WHEN operation = 'd'
APPLY AS TRUNCATE WHEN operation = 't'
SEQUENCE BY CAST(event_ts_ms AS BIGINT)
COLUMNS * EXCEPT (operation, event_ts_ms, kafka_ingested_ts)
STORED AS SCD TYPE 1;
-- Result: One row per account — always reflects latest state

-- ─── APPLY CHANGES INTO — SCD Type 2 (full history) ──
APPLY CHANGES INTO LIVE.silver_accounts_scd2
FROM STREAM(LIVE.bronze_account_cdc)
KEYS (account_id)
APPLY AS DELETE WHEN operation = 'd'
SEQUENCE BY CAST(event_ts_ms AS BIGINT)
COLUMNS after_account_id, after_account_type, after_risk_tier,
        after_kyc_status, after_current_balance, after_account_status
STORED AS SCD TYPE 2
TRACK HISTORY ON * EXCEPT (after_current_balance);
-- after_current_balance excluded from history tracking (too frequent, not needed)
-- Result: Full history with __START_AT and __END_AT columns auto-managed

-- ─── Query SCD2 historical table ──────────────
-- (Auto-generated columns by DLT)
SELECT
    after_account_id    AS account_id,
    after_risk_tier     AS risk_tier,
    after_kyc_status    AS kyc_status,
    __START_AT          AS effective_from,
    __END_AT            AS effective_to,
    CASE WHEN __END_AT IS NULL THEN 'CURRENT' ELSE 'HISTORICAL' END AS record_status
FROM LIVE.silver_accounts_scd2
WHERE after_account_id = 'ACC-EU-98765431'
ORDER BY __START_AT;

-- ─── Gold: Point-in-time risk tier from SCD2 ──
SELECT
    txn_id,
    txn_amount,
    t.account_id,
    -- Get risk tier AS OF the transaction date
    a.after_risk_tier               AS risk_tier_at_txn_time
FROM eu_bfsi_prod.silver.silver_transactions t
JOIN eu_bfsi_prod.silver.silver_accounts_scd2 a
    ON t.account_id = a.after_account_id
    AND t.txn_timestamp BETWEEN a.__START_AT
        AND COALESCE(a.__END_AT, TIMESTAMP '9999-12-31 23:59:59')
WHERE t.txn_date = '2024-06-30';
```

**Enterprise Data Scenario:**  
Real-time Core Banking CDC pipeline at a European challenger bank — Debezium captures every account attribute change from PostgreSQL Core Banking, APPLY CHANGES INTO processes 500K daily CDC events into SCD2, enabling the risk team to query a customer's exact risk classification at any point in time for MiFID II suitability back-testing.

**Optimizer Invariants & Performance Traps:**
- APPLY CHANGES INTO is exclusive to DLT — it handles out-of-order events, deduplication, and SCD management automatically
- SEQUENCE BY column must be monotonically increasing per key — use Kafka offset, Debezium ts_ms, or database LSN (Log Sequence Number)
- SCD TYPE 2 auto-generates __START_AT and __END_AT columns — no manual effective date management required
- TRACK HISTORY ON * EXCEPT excludes frequently changing columns (like balances) from SCD2 versioning — prevents version explosion for operational metrics
- APPLY CHANGES INTO requires the target table to be a LIVE table (DLT-managed) — it cannot be used with regular Delta tables outside DLT

---

### Q4.20: Iceberg Equality vs Position Deletes Write Amplification in GDPR Art. 17 Compliance (Cloud Warehouse Architecture)

**Question & Concept Overview:**  
An exabyte-scale open lakehouse table stores 8 petabytes of user activity data across 120,000 Apache Iceberg partitions, receiving 10,000 GDPR Article 17 'Right to Erasure' requests per hour. Each erasure request targets a single `user_id` dispersed across thousands of historic Parquet data files. The architecture team originally implemented Iceberg Equality Deletes (`user_id = X`), which writes small metadata marker files without touching existing Parquet data files. Within 3 weeks, over 1,500,000 equality delete files accumulate across the table metadata tree. Analytical queries executed by Trino and Apache Spark experience complete performance collapse: query planning times explode from 800ms to 4 minutes, and executor nodes crash with OutOfMemory errors because every scan task must load millions of equality delete predicates into in-memory hash sets before evaluating each Parquet row. When switching to Position Deletes (rewriting the specific data files containing targeted rows to record exact file-and-ordinal offsets), the cluster's compaction engine triggers a massive Write Amplification Factor (WAF) of 85x on the underlying cloud object store, generating $350,000 in monthly S3 PUT/GET API charges and causing optimistic concurrency control (OCC) commit collisions that fail 40% of streaming ingestion pipelines. How do you engineer a hybrid delete and compaction topology that guarantees legally compliant 30-day GDPR erasure verification without scan-time query death or catastrophic write amplification?

**Enterprise Data Scenario:**  
Enterprise Cloud Data Warehouse Scale

**Optimizer Invariants & Performance Traps:**
- 

---

### Q4.21: Delta Lake Deletion Vectors and Roaring Bitmap Inline Decompression Latency (Cloud Warehouse Architecture)

**Question & Concept Overview:**  
A transactional lakehouse table manages 3 petabytes of financial transactions across 400,000 Delta Lake Parquet files. The platform enables Delta Lake Deletion Vectors (DVs) to achieve millisecond-level point deletions without rewriting 500MB Parquet data files. When a row is deleted, a serialized Roaring Bitmap containing the 32-bit row indices within that specific Parquet file is written either inline into the Delta log or as a small standalone sidecar `.bin` file. Under an analytical query scanning 100,000 files across 1,000 worker cores, query latency degrades by 450%. CPU profiling with `perf` reveals that 38% of total CPU cycles are consumed inside the SIMD bitwise decompression and array-conversion loops of the Roaring Bitmap decoder (`roaring_bitmap_contains` or `RoaringBitmap.andNot`). Because the bitmap contains sparse clusterings of run-length encoded (RLE) intervals interleaved with raw 16-bit unsigned integer arrays, the CPU's branch prediction unit suffers a 22% misprediction rate, and L1 instruction cache misses explode as execution branches between bitmap containers, array containers, and run containers. How do you re-architect the deletion vector storage format and SIMD execution path to achieve line-rate Parquet scanning while retaining point-deletion capabilities?

**Enterprise Data Scenario:**  
Enterprise Cloud Data Warehouse Scale

**Optimizer Invariants & Performance Traps:**
- 

---

### Q4.22: Hierarchical Envelope Encryption and KMS Rate-Limit Exhaustion during Exabyte Scans (Cloud Warehouse Architecture)

**Question & Concept Overview:**  
A global healthcare lakehouse stores 12 petabytes of encrypted patient genomic data across 2,500,000 Parquet files on AWS S3. To enforce patient privacy and granular revocation, every individual Parquet file is encrypted with a unique Data Encryption Key (DEK) via AES-256-GCM in Parquet Modular Encryption (PME). Each DEK is encrypted under a regional Key Encryption Key (KEK) managed in AWS KMS. When a distributed machine learning pipeline launches a full-cohort analytical scan utilizing 4,000 Apache Spark executor tasks across 200 compute nodes, each executor task attempts to open 600 Parquet files concurrently. In the first 5 seconds of query initialization, the cluster fires 2,400,000 concurrent `kms:Decrypt` requests to the AWS KMS API. The AWS KMS regional endpoint (hard-capped at a burst limit of 50,000 requests/sec) instantly triggers exponential HTTP 429 'ThrottlingException' errors. The default AWS SDK retry logic on 4,000 workers initiates an uncontrolled Throttling Storm: retry queues saturate network buffers, workers block indefinitely in exponential backoff loops, and the entire analytical pipeline halts with fatal task failure exceptions after 3 hours. How do you design a high-throughput cryptographic key distribution and envelope caching layer that enables scanning 2.5 million encrypted Parquet files without breaching cloud KMS service quotas?

**Enterprise Data Scenario:**  
Enterprise Cloud Data Warehouse Scale

**Optimizer Invariants & Performance Traps:**
- 

---

### Q4.23: Avro Manifest Tree B-Tree Pruning Collapse at 500,000 Partitions in Apache Iceberg (Cloud Warehouse Architecture)

**Question & Concept Overview:**  
An exabyte IoT telemetry lakehouse built on Apache Iceberg accumulates 500,000 active partitions with 15,000,000 underlying Parquet data files. The table metadata is structured as a hierarchical Avro metadata tree: a top-level Snapshot points to a Manifest List, which points to 12,000 individual Avro Manifest Files, each indexing up to 1,500 data files with partition summaries and column-level upper/lower bounds. A query engine (Trino or Spark) receives an interactive dashboard query that filters on `event_date = '2026-03-01' AND device_id = 'DEV-994182'`. Although partition pruning should theoretically eliminate 99.9% of partitions, query planning freezes for 180 seconds before a single worker task can be scheduled. JFR (Java Flight Recorder) profiling of the Spark Driver reveals that deserializing and parsing the 12,000 Avro manifest files requires reading 45GB of XML/JSON/Avro data over S3, consuming 68GB of Driver JVM heap memory and triggering severe G1GC Stop-The-World pauses. The driver spends 85% of its CPU time evaluating min/max partition ranges sequentially across thousands of non-pruned manifest files because manifests contain mixed date intervals resulting from streaming append micro-batches. How do you re-architect the Iceberg metadata hierarchy and manifest bin-packing topology to achieve deterministic sub-second query planning over 500,000 partitions?

**Enterprise Data Scenario:**  
Enterprise Cloud Data Warehouse Scale

**Optimizer Invariants & Performance Traps:**
- 

---

### Q4.24: Optimistic Concurrency Control (OCC) Commit Explosions in Multi-Writer Streaming Sinks (Cloud Warehouse Architecture)

**Question & Concept Overview:**  
A mission-critical financial ledger lakehouse table built on Apache Iceberg receives concurrent streaming ingestion from 64 independent Apache Flink and Spark Structured Streaming jobs operating across 8 regional Kubernetes clusters. Each streaming job commits micro-batches every 10 seconds using Iceberg's Optimistic Concurrency Control (OCC). Under high event velocity, multiple streaming writers attempt to commit their new snapshot to the Iceberg REST Catalog simultaneously. Writer A succeeds in committing Snapshot S1 via atomic HTTP CAS (Compare-And-Swap) or ETag verification. Writers B, C, and D receive a `CommitFailedException` (optimistic lock collision) because their base snapshot S0 is now stale. Iceberg's default commit retry logic forces Writers B, C, and D to re-read the metadata tree, verify whether their committed files conflict with S1, and attempt to re-commit. However, while B is retrying, Writers E and F commit S2 and S3, forcing B, C, and D into an exponential retry spiral. Within 3 minutes, 64 streaming writers enter continuous commit retry thrashing: CPU usage on the catalog database hits 100%, metadata file generation balloons by 10,000 files/hour, commit latency inflates from 200ms to 45 seconds, and Flink streaming jobs fail checkpoint SLAs, triggering global restart cascades. How do you architect a multi-writer ingestion topology that guarantees linear scalability without OCC retry collapse?

**Enterprise Data Scenario:**  
Enterprise Cloud Data Warehouse Scale

**Optimizer Invariants & Performance Traps:**
- 

---

### Q4.25: S3 Object Lock Compliance Mode Retention Collisions with Analytical Lakehouse Scans (Cloud Warehouse Architecture)

**Question & Concept Overview:**  
A global investment bank mandates that all raw trading audit data stored in an enterprise Iceberg lakehouse must be protected under AWS S3 Object Lock in 'Compliance Mode' with a strict 7-year immutable retention policy to comply with SEC Rule 17a-4. Under Compliance Mode, no user—including the AWS root account—can overwrite, delete, or modify any locked S3 object until the retention period expires. During a routine lakehouse optimization run, an automated maintenance worker executes table compaction, creating new optimized 512MB Parquet files and marking old 2MB Parquet files as orphaned via Iceberg snapshot expiration. However, when the distributed garbage collection process (`expireSnapshots` / orphan file cleanup) attempts to issue `s3:DeleteObject` commands on the unreferenced historical files, AWS S3 rejects every request with `AccessDenied: Object under WORM compliance retention`. Over 12 months, 45,000,000 unreferenced obsolete Parquet files accumulate in the bucket (consuming 4.2 petabytes of redundant storage and costing $95,000/month in dead storage). Furthermore, when distributed analytical query engines execute partition scans over historical snapshots, the underlying S3 list operations traverse millions of deleted yet physically present files, degrading query planning and incurring massive object scan costs. How do you design an immutable regulatory storage topology that guarantees SEC Rule 17a-4 WORM compliance while allowing analytical lakehouse metadata compaction and physical storage reclamation?

**Enterprise Data Scenario:**  
Enterprise Cloud Data Warehouse Scale

**Optimizer Invariants & Performance Traps:**
- 

---
