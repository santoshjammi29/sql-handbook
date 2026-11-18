# 🎓 SQL Interview Guide — Tier 3: Senior Distributed Data Engineer (MPP & Concurrency)

> **Focus Areas**: Distributed MPP Architectures, Data Movement (Broadcast vs Hash Redistribution), Data Skew Triage, Columnar Storage Engines, ACID Concurrency & Isolation Levels, Deadlock Resolution.
> **Target Audience**: Senior Data Engineers, Cloud Warehouse Architects, Database Administrators

---

### Q3.1: Columnstore Indexes for Analytics (Performance)

**Question & Concept Overview:**  
Columnstore indexes store data column-by-column, enabling 10-100x faster analytical aggregations through compression and batch mode execution. Essential for Azure SQL Silver/Gold layer analytical queries at scale.

**SQL Implementation & Query Plan:**
```sql
-- Create clustered columnstore index on fact table
-- Ideal for: aggregation-heavy queries, full table scans, DW workloads
CREATE CLUSTERED COLUMNSTORE INDEX CCI_fact_transactions
ON dbo.fact_transactions;
-- Note: CCI replaces clustered B-tree index — all data stored in columnstore format

-- Nonclustered columnstore: keep row-based index for OLTP, add columnstore for analytics
-- Best for: hybrid HTAP workloads (Azure SQL General Purpose)
CREATE NONCLUSTERED COLUMNSTORE INDEX NCCI_fact_transactions_analytics
ON dbo.fact_transactions (transaction_date, currency, amount_eur, status, customer_id)
WHERE transaction_date >= '2023-01-01';  -- filtered to recent data

-- Query benefits from batch mode execution (check execution plan: Batch Mode on Row Store)
SELECT
    currency,
    YEAR(transaction_date) AS year,
    MONTH(transaction_date) AS month,
    COUNT(*) AS txn_count,
    SUM(amount_eur) AS total_volume,
    AVG(amount_eur) AS avg_amount,
    PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY amount_eur) OVER (PARTITION BY currency) AS p95
FROM dbo.fact_transactions
WHERE transaction_date BETWEEN '2023-01-01' AND '2024-12-31'
GROUP BY currency, YEAR(transaction_date), MONTH(transaction_date);

-- Columnstore maintenance: reorganize compressed rowgroups
ALTER INDEX CCI_fact_transactions ON dbo.fact_transactions REORGANIZE;

-- Check rowgroup quality (health indicator for columnstore performance)
SELECT
    object_name(object_id) AS table_name,
    row_group_id,
    state_description,
    total_rows,
    size_in_bytes / 1024 AS size_kb,
    delta_store_hobt_id
FROM sys.column_store_row_groups
WHERE object_id = OBJECT_ID('dbo.fact_transactions')
ORDER BY row_group_id;
```

**Enterprise Data Scenario:**  
Adding a nonclustered columnstore index to the Silver fact_transactions table in Azure SQL to support Power BI Direct Query aggregation queries, reducing report load time from 45 seconds to under 2 seconds.

**Optimizer Invariants & Performance Traps:**
- Columnstore indexes achieve 5-10x compression vs B-tree — dramatically reduces I/O for full table scans
- Batch mode execution processes 900 rows at a time vs row mode (1 row) — 10x CPU efficiency on aggregations
- DELTA store accumulates small inserts before compressing — avoid tiny batch inserts for best columnstore performance
- For Azure SQL, use NCCI on OLTP tables (preserves row-based updates) and CCI on pure analytics tables

---

### Q3.2: Row-Level Security (RLS) for GDPR (Security & Governance)

**Question & Concept Overview:**  
Row-Level Security transparently filters query results based on the executing user's context, enabling multi-tenant data isolation and GDPR-compliant data access controls without modifying application queries.

**SQL Implementation & Query Plan:**
```sql
-- Create security schema and predicate function
CREATE SCHEMA Security;
GO

-- Security predicate: filter rows based on calling user's country_code claim
CREATE FUNCTION Security.fn_transaction_security_predicate(
    @customer_country_code CHAR(2)
)
RETURNS TABLE
WITH SCHEMABINDING
AS RETURN
    SELECT 1 AS fn_result
    WHERE
        -- Internal analysts see all records
        IS_MEMBER('db_role_analyst_global') = 1
        OR
        -- Country-specific users see only their country's data (GDPR data sovereignty)
        @customer_country_code = (
            SELECT country_code
            FROM dbo.dim_user_country_mapping
            WHERE db_user = USER_NAME()
        )
        OR
        -- AML team sees high-value cross-border transactions globally
        (IS_MEMBER('db_role_aml') = 1 AND @customer_country_code IS NOT NULL);
GO

-- Apply RLS security policy to transactions view
CREATE SECURITY POLICY dbo.TransactionRLSPolicy
ADD FILTER PREDICATE Security.fn_transaction_security_predicate(customer_country_code)
ON dbo.fact_transactions,

-- Block predicate: also prevents INSERT of rows user can't see
ADD BLOCK PREDICATE Security.fn_transaction_security_predicate(customer_country_code)
ON dbo.fact_transactions AFTER INSERT
WITH (STATE = ON);

-- Test RLS (execute as different user)
EXECUTE AS USER = 'analyst_uk@company.com';
SELECT COUNT(*), customer_country_code FROM dbo.fact_transactions GROUP BY customer_country_code;
-- Returns only UK rows transparently
REVERT;

-- Check RLS policies
SELECT
    p.name AS policy_name,
    p.is_enabled,
    pred.predicate_definition,
    pred.predicate_type_desc
FROM sys.security_policies p
JOIN sys.security_predicates pred ON p.object_id = pred.object_id;
```

**Enterprise Data Scenario:**  
Implementing GDPR-compliant data sovereignty controls in Azure SQL — EU banking analysts in Germany see only German customer transactions, while the global AML team sees all high-value cross-border transactions.

**Optimizer Invariants & Performance Traps:**
- RLS is enforced at the engine level — even DBA tools like SSMS show filtered results for RLS users
- WITH SCHEMABINDING on the predicate function prevents dropping referenced tables accidentally
- BLOCK predicates prevent users from inserting rows they wouldn't be able to read — critical for multi-tenant isolation
- Use SESSION_CONTEXT() for application-passed claims (JWT roles) in connection pool scenarios

---

### Q3.3: Change Data Capture (CDC) (Data Integration)

**Question & Concept Overview:**  
CDC tracks row-level changes (INSERT, UPDATE, DELETE) at the SQL Server engine level, providing a reliable change feed for incremental ETL, Delta Lake streaming ingestion, and audit compliance without triggers.

**SQL Implementation & Query Plan:**
```sql
-- Enable CDC on database (requires sysadmin)
EXEC sys.sp_cdc_enable_db;

-- Enable CDC on transactions table
EXEC sys.sp_cdc_enable_table
    @source_schema = N'dbo',
    @source_name   = N'fact_transactions',
    @role_name     = N'cdc_reader',  -- database role that can read CDC tables
    @supports_net_changes = 1,       -- capture net change per row (not every intermediate state)
    @captured_column_list = N'transaction_id,amount_eur,currency,status,transaction_date,customer_id';

-- Query CDC changes for incremental ETL (ADF or Python)
DECLARE @from_lsn BINARY(10) = sys.fn_cdc_get_min_lsn('dbo_fact_transactions');
DECLARE @to_lsn   BINARY(10) = sys.fn_cdc_get_max_lsn();

-- All changes: $__$operation: 1=Delete, 2=Insert, 3=Before Update, 4=After Update
SELECT
    sys.fn_cdc_map_lsn_to_time(__$start_lsn) AS change_time,
    CASE __$operation
        WHEN 1 THEN 'DELETE'
        WHEN 2 THEN 'INSERT'
        WHEN 4 THEN 'UPDATE'
    END AS operation,
    transaction_id,
    amount_eur,
    currency,
    status,
    __$start_lsn AS change_lsn
FROM cdc.fn_cdc_get_all_changes_dbo_fact_transactions(@from_lsn, @to_lsn, 'all')
WHERE __$operation IN (2, 4)  -- only INSERT and after-UPDATE
ORDER BY __$start_lsn;

-- Net changes only: most recent change per transaction_id
SELECT transaction_id, amount_eur, currency, status, __$operation -- Note: Specify explicit columns in production
FROM cdc.fn_cdc_get_net_changes_dbo_fact_transactions(@from_lsn, @to_lsn, 'all');

-- Monitor CDC latency (alert if > 5 minutes behind)
SELECT
    capture_instance,
    [object_id],
    create_date,
    start_lsn,
    stop_lsn
FROM cdc.change_tables;
```

**Enterprise Data Scenario:**  
Implementing real-time incremental loading from Azure SQL Silver to Delta Lake Bronze table using CDC, capturing only changed rows since last ADF run rather than full table scans — reducing pipeline runtime from 2 hours to 5 minutes.

**Optimizer Invariants & Performance Traps:**
- CDC reads transaction log — zero overhead on source table, unlike triggers which add per-row overhead
- net_changes function returns only final state per row — eliminates intermediate UPDATE noise
- Store the last processed LSN in a control table — enables resumable, incremental CDC pipelines
- ADF has native CDC source connector for Azure SQL — no custom SP needed for standard incremental loads

---

### Q3.4: Query Store & Performance Monitoring (Performance)

**Question & Concept Overview:**  
Query Store captures query plans and runtime statistics, enabling identification of plan regressions, parameter sniffing issues, and the most resource-intensive queries. Essential for FinOps Azure SQL cost optimization.

**SQL Implementation & Query Plan:**
```sql
-- Enable Query Store (Azure SQL has it on by default)
ALTER DATABASE [bfsi_dw]
SET QUERY_STORE = ON
(
    OPERATION_MODE = READ_WRITE,
    CLEANUP_POLICY = (STALE_QUERY_THRESHOLD_DAYS = 30),
    DATA_FLUSH_INTERVAL_SECONDS = 3000,
    INTERVAL_LENGTH_MINUTES = 15,
    MAX_STORAGE_SIZE_MB = 1000,
    QUERY_CAPTURE_MODE = AUTO,  -- only captures queries with significant impact
    SIZE_BASED_CLEANUP_MODE = AUTO
);

-- Top 10 most expensive queries by CPU (FinOps: identify cost drivers)
SELECT TOP 10
    q.query_id,
    qt.query_sql_text,
    SUM(rs.avg_cpu_time) AS total_cpu_ms,
    SUM(rs.avg_duration) AS total_duration_ms,
    SUM(rs.avg_logical_io_reads) AS total_logical_reads,
    SUM(rs.count_executions) AS execution_count,
    SUM(rs.avg_cpu_time) / NULLIF(SUM(rs.count_executions), 0) AS avg_cpu_per_exec_ms
FROM sys.query_store_query q
JOIN sys.query_store_query_text qt ON q.query_text_id = qt.query_text_id
JOIN sys.query_store_plan p ON q.query_id = p.query_id
JOIN sys.query_store_runtime_stats rs ON p.plan_id = rs.plan_id
JOIN sys.query_store_runtime_stats_interval rsi ON rs.runtime_stats_interval_id = rsi.runtime_stats_interval_id
WHERE rsi.start_time >= DATEADD(HOUR, -24, GETUTCDATE())
GROUP BY q.query_id, qt.query_sql_text
ORDER BY total_cpu_ms DESC;

-- Force a specific (known-good) plan for a problematic query
-- Use Query Store UI in SSMS or Azure Portal → Query Performance Insight
EXEC sp_query_store_force_plan @query_id = 123, @plan_id = 456;

-- Detect plan regressions (same query, new worse plan)
SELECT
    q.query_id,
    p.plan_id,
    rs.avg_duration,
    rs.avg_cpu_time,
    p.is_forced_plan,
    p.is_parallel_plan
FROM sys.query_store_plan p
JOIN sys.query_store_query q ON p.query_id = q.query_id
JOIN sys.query_store_runtime_stats rs ON p.plan_id = rs.plan_id
WHERE q.query_id IN (
    SELECT query_id FROM sys.query_store_plan GROUP BY query_id HAVING COUNT(DISTINCT plan_id) > 1
)
ORDER BY q.query_id, rs.avg_duration DESC;
```

**Enterprise Data Scenario:**  
Using Query Store to identify the top 10 most expensive Power BI Direct Query queries on the Azure SQL Gold layer, forcing known-good plans to prevent regressions after index rebuilds during maintenance windows.

**Optimizer Invariants & Performance Traps:**
- Query Store is the Azure SQL equivalent of AWR in Oracle — captures 30 days of query history by default
- Plan forcing (sp_query_store_force_plan) stabilizes performance during schema changes or statistics updates
- QUERY_CAPTURE_MODE=AUTO ignores ad-hoc queries and focuses on recurring, impactful queries
- Azure Portal's Query Performance Insight provides visual version of Query Store — share with stakeholders

---

### Q3.5: Partitioning & Data Archival (Data Engineering)

**Question & Concept Overview:**  
Table partitioning on date columns enables partition elimination (query reads only relevant partitions), efficient archival via partition switching, and load isolation for large financial transaction tables.

**SQL Implementation & Query Plan:**
```sql
-- Partition function: monthly ranges for transaction history
CREATE PARTITION FUNCTION pf_monthly_transactions (DATE)
AS RANGE RIGHT FOR VALUES (
    '2023-01-01', '2023-02-01', '2023-03-01', '2023-04-01',
    '2023-05-01', '2023-06-01', '2023-07-01', '2023-08-01',
    '2023-09-01', '2023-10-01', '2023-11-01', '2023-12-01',
    '2024-01-01', '2024-02-01', '2024-03-01'
);

-- Partition scheme: map partitions to filegroups
CREATE PARTITION SCHEME ps_monthly_transactions
AS PARTITION pf_monthly_transactions
ALL TO ([PRIMARY]);  -- in production: map to separate filegroups for tiered storage

-- Create partitioned fact table
CREATE TABLE dbo.fact_transactions_partitioned (
    transaction_id   NVARCHAR(50) NOT NULL,
    amount_eur       DECIMAL(18,2) NOT NULL,
    currency         CHAR(3) NOT NULL,
    status           NVARCHAR(20) NOT NULL,
    transaction_date DATE NOT NULL,
    customer_id      NVARCHAR(50) NULL,
    _load_ts         DATETIME2 NOT NULL DEFAULT GETUTCDATE()
) ON ps_monthly_transactions(transaction_date);  -- partition by date column

-- Add clustered columnstore (partition-aligned)
CREATE CLUSTERED COLUMNSTORE INDEX CCI_fact_transactions_partitioned
ON dbo.fact_transactions_partitioned
ON ps_monthly_transactions(transaction_date);

-- Partition elimination — query reads only January 2024 partition
SELECT COUNT(*), SUM(amount_eur)
FROM dbo.fact_transactions_partitioned
WHERE transaction_date BETWEEN '2024-01-01' AND '2024-01-31';
-- SQL Server reads ONLY the January 2024 partition — not all 15 partitions

-- Add new month partition (maintenance window)
ALTER PARTITION FUNCTION pf_monthly_transactions() SPLIT RANGE ('2024-04-01');

-- Partition switch: instant archival (no data movement)
ALTER TABLE dbo.fact_transactions_partitioned
SWITCH PARTITION 1 TO dbo.fact_transactions_archive PARTITION 1;
```

**Enterprise Data Scenario:**  
Implementing monthly partitioning on the Azure SQL Silver fact_transactions table at TCS EU BFSI — reducing daily reporting query I/O by 96% through partition elimination and enabling instant monthly archival via partition switching.

**Optimizer Invariants & Performance Traps:**
- Partition elimination reduces I/O by 90%+ on date-filtered queries — SQL Server reads only matching partitions
- SPLIT RANGE adds a new partition — takes seconds; no data movement required
- Partition SWITCH is instantaneous metadata operation — archive 1 month of data in milliseconds
- Always partition on the same column as the most common WHERE filter — usually transaction_date in BFSI

---

### Q3.6: In-Memory OLTP for High-Throughput Staging (Performance)

**Question & Concept Overview:**  
In-Memory OLTP (Hekaton) stores tables in CPU-optimized memory structures, enabling 10-30x faster INSERT throughput for high-volume staging tables and lock-free concurrent writes — critical for real-time payment event ingestion.

**SQL Implementation & Query Plan:**
```sql
-- Create memory-optimized filegroup (required for In-Memory OLTP)
ALTER DATABASE [bfsi_dw]
ADD FILEGROUP fg_inmemory CONTAINS MEMORY_OPTIMIZED_DATA;
GO
ALTER DATABASE [bfsi_dw]
ADD FILE (NAME='bfsi_inmemory', FILENAME='C:\Data\bfsi_inmemory')
TO FILEGROUP fg_inmemory;
GO

-- Create memory-optimized staging table (lock-free, latch-free)
CREATE TABLE dbo.stage_transactions_inmem (
    stage_id        BIGINT IDENTITY(1,1)  NOT NULL,
    transaction_id  NVARCHAR(50)          NOT NULL,
    amount          DECIMAL(18,4)         NOT NULL,
    currency        CHAR(3)               NOT NULL,
    status          NVARCHAR(20)          NOT NULL,
    received_ts     DATETIME2             NOT NULL DEFAULT SYSUTCDATETIME(),
    payload_json    NVARCHAR(MAX)         NULL,

    INDEX ix_txn_id_hash HASH (transaction_id) WITH (BUCKET_COUNT = 1000000),
    INDEX ix_received_ts NONCLUSTERED (received_ts)
)
WITH (
    MEMORY_OPTIMIZED = ON,
    DURABILITY = SCHEMA_AND_DATA  -- survives restart; SCHEMA_ONLY for pure cache
);

-- Natively compiled stored procedure: maximum throughput insert
CREATE PROCEDURE dbo.usp_insert_staged_transaction
    @transaction_id NVARCHAR(50),
    @amount DECIMAL(18,4),
    @currency CHAR(3),
    @status NVARCHAR(20)
WITH NATIVE_COMPILATION, SCHEMABINDING, EXECUTE AS OWNER
AS
BEGIN ATOMIC WITH (TRANSACTION ISOLATION LEVEL = SNAPSHOT, LANGUAGE = N'english')
    INSERT INTO dbo.stage_transactions_inmem
        (transaction_id, amount, currency, status)
    VALUES
        (@transaction_id, @amount, @currency, @status);
END;

-- Bulk drain from In-Memory staging to disk-based Silver table
INSERT INTO dbo.fact_transactions (transaction_id, amount, currency, status, _load_ts)
SELECT transaction_id, amount, currency, status, GETUTCDATE()
FROM dbo.stage_transactions_inmem
WHERE received_ts < DATEADD(MINUTE, -5, SYSUTCDATETIME());  -- drain older than 5 min

DELETE FROM dbo.stage_transactions_inmem
WHERE received_ts < DATEADD(MINUTE, -5, SYSUTCDATETIME());
```

**Enterprise Data Scenario:**  
Using In-Memory OLTP staging table to buffer high-frequency payment events from Azure Event Hubs before draining to Silver Delta Lake via ADF, handling 50,000+ transactions/second without lock contention.

**Optimizer Invariants & Performance Traps:**
- In-Memory OLTP inserts are lock-free — 10-30x faster than disk-based tables for high-concurrency staging
- HASH indexes are O(1) lookup by exact equality — ideal for transaction_id dedup checks
- Natively compiled SPs are compiled to machine code — max throughput for the critical hot path
- SCHEMA_AND_DATA durability survives restart; SCHEMA_ONLY (faster) loses data — use for pure staging cache

---

### Q3.7: Always Encrypted for GDPR Sensitive Columns (Security & Governance)

**Question & Concept Overview:**  
Always Encrypted ensures sensitive financial data (account numbers, SSNs) is encrypted on the client side before reaching Azure SQL. The server never sees plaintext — enabling secure processing of GDPR personal data.

**SQL Implementation & Query Plan:**
```sql
-- Always Encrypted column encryption (done via SSMS wizard or PowerShell)
-- Step 1: Create Column Master Key (stored in Azure Key Vault)
CREATE COLUMN MASTER KEY CMK_EU_BFSI
WITH (
    KEY_STORE_PROVIDER_NAME = 'AZURE_KEY_VAULT',
    KEY_PATH = 'https://eu-keyvault.vault.azure.net/keys/cmk-bfsi/abc123'
);

-- Step 2: Create Column Encryption Key (encrypted with CMK)
CREATE COLUMN ENCRYPTION KEY CEK_PII_Data
WITH VALUES (
    COLUMN_MASTER_KEY = CMK_EU_BFSI,
    ALGORITHM = 'RSA_OAEP',
    ENCRYPTED_VALUE = 0x01670000... -- encrypted CEK value
);

-- Step 3: Table with Always Encrypted columns
CREATE TABLE dbo.dim_customers_secure (
    customer_sk     INT IDENTITY(1,1) NOT NULL,
    customer_id     NVARCHAR(50) NOT NULL,
    customer_name   NVARCHAR(200) NOT NULL,
    country_code    CHAR(2) NOT NULL,
    tier            NVARCHAR(20) NULL,

    -- Deterministic: allows equality filter (WHERE account_no = ?)
    account_number  NVARCHAR(50)
        ENCRYPTED WITH (
            ENCRYPTION_TYPE = DETERMINISTIC,
            ALGORITHM = 'AEAD_AES_256_CBC_HMAC_SHA_256',
            COLUMN_ENCRYPTION_KEY = CEK_PII_Data
        ),

    -- Randomized: more secure, no equality filter (for SSN, DOB)
    national_id     NVARCHAR(20)
        ENCRYPTED WITH (
            ENCRYPTION_TYPE = RANDOMIZED,
            ALGORITHM = 'AEAD_AES_256_CBC_HMAC_SHA_256',
            COLUMN_ENCRYPTION_KEY = CEK_PII_Data
        ),

    CONSTRAINT PK_customers_secure PRIMARY KEY (customer_sk)
);

-- Python client with Always Encrypted (decryption happens client-side)
-- import pyodbc; conn_str += ";Column Encryption Setting=enabled;"
-- query returns decrypted values transparently to authorized client

-- Check encryption status
SELECT
    c.name AS column_name,
    cek.name AS encryption_key_name,
    c.encryption_type_desc,
    c.encryption_algorithm_name
FROM sys.columns c
JOIN sys.column_encryption_keys cek ON c.column_encryption_key_id = cek.column_encryption_key_id
WHERE OBJECT_NAME(c.object_id) = 'dim_customers_secure';
```

**Enterprise Data Scenario:**  
Encrypting EU customer account numbers and national IDs in Azure SQL at the column level using Always Encrypted, ensuring GDPR compliance even if the database server is compromised — required for TCS EU BFSI client contracts.

**Optimizer Invariants & Performance Traps:**
- Always Encrypted encrypts data BEFORE it leaves the client app — Azure SQL server never sees plaintext
- Deterministic encryption allows equality filtering (WHERE) — use for account numbers you need to query
- Randomized encryption is more secure — use for fields that never need filtering (national ID, DOB)
- Column Master Key in Azure Key Vault — only authorized applications with Key Vault access can decrypt

---

### Q3.8: Query Plan Analysis & Index Tuning (Performance)

**Question & Concept Overview:**  
Reading and interpreting execution plans identifies performance bottlenecks — key lookups, nested loops, sort spills, and missing indexes. Systematic index tuning reduces query cost for Power BI and analytical workloads.

**SQL Implementation & Query Plan:**
```sql
-- Capture actual execution plan + runtime stats
SET STATISTICS IO ON;
SET STATISTICS TIME ON;

-- Query to analyze
SELECT
    c.country_code,
    t.currency,
    SUM(t.amount_eur) AS total_volume,
    COUNT(*) AS txn_count
FROM dbo.fact_transactions t
JOIN dbo.dim_customers c ON t.customer_id = c.customer_id
WHERE t.transaction_date BETWEEN '2024-01-01' AND '2024-01-31'
  AND t.status = 'SETTLED'
GROUP BY c.country_code, t.currency;

SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;

-- Check missing index recommendations (from DMV)
SELECT TOP 20
    ROUND(migs.avg_total_user_cost * migs.avg_user_impact * (migs.user_seeks + migs.user_scans), 0) AS improvement_measure,
    'CREATE INDEX IX_' + OBJECT_NAME(mid.object_id) + '_' +
        REPLACE(REPLACE(REPLACE(mid.equality_columns + ISNULL('_' + mid.inequality_columns, ''), '[', ''), ']', ''), ', ', '_')
    AS suggested_index_ddl,
    mid.equality_columns,
    mid.inequality_columns,
    mid.included_columns,
    migs.avg_user_impact AS estimated_impact_pct,
    migs.user_seeks,
    OBJECT_NAME(mid.object_id) AS table_name
FROM sys.dm_db_missing_index_details mid
JOIN sys.dm_db_missing_index_groups mig ON mid.index_handle = mig.index_handle
JOIN sys.dm_db_missing_index_group_stats migs ON mig.index_group_handle = migs.group_handle
ORDER BY improvement_measure DESC;

-- Check index fragmentation (determine REBUILD vs REORGANIZE threshold)
SELECT
    i.name AS index_name,
    ROUND(ips.avg_fragmentation_in_percent, 2) AS fragmentation_pct,
    ips.page_count,
    CASE
        WHEN ips.avg_fragmentation_in_percent > 30 THEN 'REBUILD'
        WHEN ips.avg_fragmentation_in_percent > 10 THEN 'REORGANIZE'
        ELSE 'OK'
    END AS action_needed
FROM sys.dm_db_index_physical_stats(DB_ID(), OBJECT_ID('dbo.fact_transactions'), NULL, NULL, 'SAMPLED') ips
JOIN sys.indexes i ON ips.object_id = i.object_id AND ips.index_id = i.index_id
ORDER BY fragmentation_pct DESC;
```

**Enterprise Data Scenario:**  
Systematic index tuning exercise on Azure SQL Gold layer at TCS — using missing index DMVs to identify and create 8 covering indexes that reduced Power BI report load time from 45s to 3s for C-level dashboards.

**Optimizer Invariants & Performance Traps:**
- Key Lookup in execution plan = the index doesn't include all needed columns — add INCLUDE columns
- Nested Loops on large tables = missing index on join column — causes row-by-row lookups
- improvement_measure in missing index DMV combines seek frequency and impact — sort descending
- Fragmentation > 30%: REBUILD ONLINE; 10-30%: REORGANIZE; < 10%: leave alone (I/O cost not worth it)

---

### Q3.9: Top-N Per Group via CROSS APPLY / LATERAL Iterator (Analytical Functions)

**Question & Concept Overview:**  
Correlated inline iterator pattern utilizing CROSS APPLY to fetch the Top-N records per category with targeted index seeks instead of full-table window scans.

**SQL Implementation & Query Plan:**
```sql
-- Top-3 Recent Transactions per Customer
-- Supporting Index: CREATE INDEX idx_cust_txn ON dbo.transactions (customer_id, transaction_date DESC) INCLUDE (amount, status);

SELECT 
    c.customer_id,
    c.customer_name,
    t.transaction_id,
    t.transaction_date,
    t.amount,
    t.status
FROM dbo.dim_customers c
CROSS APPLY (
    -- Evaluated iteratively per customer using targeted B-Tree seeks
    SELECT TOP 3
        tx.transaction_id,
        tx.transaction_date,
        tx.amount,
        tx.status
    FROM dbo.transactions tx
    WHERE tx.customer_id = c.customer_id
    ORDER BY tx.transaction_date DESC
) t;

-- Use OUTER APPLY to preserve customers who have 0 transactions!
```

**Enterprise Data Scenario:**  
Customer 360 profiling, recent order previews in e-commerce portals, and top fraud alerts per merchant.

**Optimizer Invariants & Performance Traps:**
- Reads exactly 3 leaf rows per customer instead of scanning millions of rows
- Bypasses full-table Sort/Segment operators required by ROW_NUMBER() window functions
- OUTER APPLY functions identically to LEFT JOIN LATERAL in PostgreSQL

---

### Q3.10: Multidimensional Aggregation with GROUPING SETS & ROLLUP (Aggregation)

**Question & Concept Overview:**  
Computing multi-level hierarchical sub-totals and cross-tabulations in a single physical data scan using GROUPING SETS and ROLLUP.

**SQL Implementation & Query Plan:**
```sql
-- Single-Pass Financial Revenue Rollup
-- Hierarchy: Year -> Quarter -> Region -> Channel -> Total

SELECT
    CASE 
        WHEN GROUPING(r.region_name) = 1 THEN 'All Regions' 
        ELSE r.region_name 
    END AS region,
    CASE 
        WHEN GROUPING(d.fiscal_year) = 1 THEN 'All Years' 
        ELSE CAST(d.fiscal_year AS VARCHAR(10)) 
    END AS fiscal_year,
    CASE 
        WHEN GROUPING(c.channel_name) = 1 THEN 'All Channels' 
        ELSE c.channel_name 
    END AS sales_channel,
    SUM(f.gross_revenue) AS total_gross_revenue,
    SUM(f.net_revenue) AS total_net_revenue,
    GROUPING_ID(r.region_name, d.fiscal_year, c.channel_name) AS aggregation_level_bitmap
FROM dbo.fact_sales f
INNER JOIN dbo.dim_date d ON f.date_key = d.date_key
INNER JOIN dbo.dim_regions r ON f.region_key = r.region_key
INNER JOIN dbo.dim_channels c ON f.channel_key = c.channel_key
GROUP BY ROLLUP (
    r.region_name,
    d.fiscal_year,
    c.channel_name
)
ORDER BY 
    r.region_name, 
    d.fiscal_year, 
    c.channel_name;
```

**Enterprise Data Scenario:**  
Executive financial reporting, matrix balance sheets, and fast pre-aggregation for OLAP cubes.

**Optimizer Invariants & Performance Traps:**
- ROLLUP generates hierarchical sub-totals in a single physical pass over source fact tables
- GROUPING() detects whether a column is collapsed into a sub-total or represents a detail row
- GROUPING_ID() emits an integer bitmask identifying the exact dimensional grouping level

---

### Q3.11: Synapse Dedicated SQL Pool COPY INTO with Parquet & Error Logging (Bulk Ingestion)

**Question & Concept Overview:**  
Production-grade T-SQL pattern for high-throughput parallel bulk loading from ADLS Gen2 Parquet files into an MPP Clustered Columnstore table, featuring Managed Identity, column ordinal mapping, and quarantine error logging.

**SQL Implementation & Query Plan:**
```sql
-- =====================================================================
-- Production COPY INTO Pipeline: ADLS Gen2 Parquet to Synapse Dedicated
-- Scenario: EU BFSI Daily Transaction Settlement Ingestion (50M rows)
-- =====================================================================

-- 1. Ensure target table is optimized with Hash Distribution and Columnstore
CREATE TABLE dbo.FactTransactions_Staging (
    transaction_id      VARCHAR(64)     NOT NULL,
    account_id          BIGINT          NOT NULL,
    customer_id         BIGINT          NOT NULL,
    transaction_amount  DECIMAL(18, 2)  NOT NULL,
    currency_code       CHAR(3)         NOT NULL,
    transaction_ts      DATETIME2(3)    NOT NULL,
    ingest_batch_id     INT             DEFAULT 20240315
)
WITH (
    DISTRIBUTION = HASH(account_id),
    CLUSTERED COLUMNSTORE INDEX
);

-- 2. Execute parallel high-throughput COPY INTO
-- Uses Azure Managed Identity (zero secrets embedded in code)
COPY INTO dbo.FactTransactions_Staging (
    transaction_id      1,
    account_id          2,
    customer_id         3,
    transaction_amount  4,
    currency_code       5,
    transaction_ts      6
)
FROM 'https://eubfsidatalakeprod.dfs.core.windows.net/curated/transactions/year=2024/month=03/*.parquet'
WITH (
    FILE_TYPE       = 'PARQUET',
    CREDENTIAL      = (IDENTITY = 'Managed Identity'),
    COMPRESSION     = 'snappy',
    MAXERRORS       = 100,               -- Allow up to 100 corrupted records before rollback
    ERRORFILE       = '/quarantine/errors_fact_txns_20240315/', -- Output directory in ADLS
    AUTO_CREATE_TABLE = 'OFF'
);

-- 3. Validate row counts and verify zero memory spill across distributions
SELECT 
    COUNT(*) AS total_loaded_rows,
    MIN(transaction_ts) AS earliest_txn,
    MAX(transaction_ts) AS latest_txn
FROM dbo.FactTransactions_Staging;

-- Check Columnstore row group health (aiming for ~1M rows per active rowgroup)
SELECT 
    state_desc, 
    COUNT(*) AS row_group_count,
    SUM(total_rows) AS total_rows,
    SUM(size_in_bytes) / 1024 / 1024 AS total_size_mb
FROM sys.pdw_nodes_column_store_row_groups
WHERE object_id = OBJECT_ID('dbo.FactTransactions_Staging')
GROUP BY state_desc;
```

**Enterprise Data Scenario:**  
Daily high-throughput bulk ingestion of 50M settled financial transactions from curated ADLS Gen2 Parquet files into Azure Synapse Dedicated SQL Pools for EU banking regulatory reporting.

**Optimizer Invariants & Performance Traps:**
- Always map column ordinals explicitly (col 1, col 2) when source Parquet schema order might drift
- Managed Identity eliminates Key Vault credential rotation overhead and secures network communication
- MAXERRORS quarantines malformed records in the ERRORFILE storage path for automated DLQ inspection
- Target table should be pre-created with HASH distribution to prevent expensive shuffle data movement post-load

---

### Q3.12: Synapse Serverless T-SQL OPENROWSET with Parquet Pushdown (Data Lake Virtualization)

**Question & Concept Overview:**  
Querying raw and curated Parquet files directly in ADLS Gen2 using Synapse Serverless SQL OPENROWSET. Demonstrates column projection pushdown, filepath() partition pruning, and CETAS materialization.

**SQL Implementation & Query Plan:**
```sql
-- =====================================================================
-- Synapse Serverless SQL: Querying Parquet Directly with Zero Infrastructure
-- Scenario: Fraud Detection Analytics across multi-terabyte ADLS Lake
-- =====================================================================

-- 1. Direct query with column projection and partition pruning via filepath()
SELECT
    r.filepath(1) AS txn_year,
    r.filepath(2) AS txn_month,
    r.account_id,
    COUNT(*) AS high_risk_count,
    SUM(r.transaction_amount) AS total_flagged_eur
FROM OPENROWSET(
    BULK 'https://eubfsidatalakeprod.dfs.core.windows.net/curated/transactions/year=*/month=*/*.parquet',
    FORMAT = 'PARQUET'
) WITH (
    account_id          BIGINT,
    transaction_amount  DECIMAL(18, 2),
    risk_score          TINYINT,
    is_flagged          BIT
) AS [r]
WHERE
    r.filepath(1) = '2024'               -- Partition pruning: only scans 2024 directories
    AND r.filepath(2) IN ('01', '02', '03') -- Pruning Q1 months
    AND r.is_flagged = 1
    AND r.risk_score >= 8
GROUP BY
    r.filepath(1),
    r.filepath(2),
    r.account_id
HAVING
    SUM(r.transaction_amount) > 50000
ORDER BY
    total_flagged_eur DESC;

-- 2. CETAS: Materialize aggregated results directly back into curated Parquet
CREATE EXTERNAL TABLE gold.Q1HighRiskSummary
WITH (
    LOCATION = 'gold/fraud_summaries/q1_2024/',
    DATA_SOURCE = ADLSGen2_Curated_Source,
    FILE_FORMAT = ParquetFormatSnappy
)
AS
SELECT
    account_id,
    COUNT(*) AS total_txns,
    SUM(transaction_amount) AS total_volume_eur
FROM OPENROWSET(
    BULK 'curated/transactions/year=2024/month=03/*.parquet',
    DATA_SOURCE = 'ADLSGen2_Curated_Source',
    FORMAT = 'PARQUET'
) WITH (
    account_id BIGINT,
    transaction_amount DECIMAL(18,2)
) AS [txns]
GROUP BY account_id;
```

**Enterprise Data Scenario:**  
Ad-hoc compliance investigation on 100TB of historical banking records in ADLS Gen2, achieving sub-10 second query execution without provisioning dedicated warehouse compute.

**Optimizer Invariants & Performance Traps:**
- filepath(1), filepath(2) dynamically extract directory partition values without reading file contents
- WITH clause enforces strict schema casting and tells serverless engine which exact column chunks to fetch
- Serverless billing ($5/TB) is directly reduced by Parquet column projection and partition pruning
- CETAS writes results in parallel as clean Snappy-compressed Parquet files ready for Power BI or downstream tools

---

### Q3.13: PolyBase External Data Source, File Format & External Table Setup (Data Lake Virtualization)

**Question & Concept Overview:**  
Complete end-to-end DDL blueprint for configuring PolyBase to query and ingest Parquet files in Azure Synapse or SQL Server 2022, including master key, scoped credential, and CTAS ingestion.

**SQL Implementation & Query Plan:**
```sql
-- =====================================================================
-- PolyBase Configuration Blueprint for Enterprise Parquet Ingestion
-- =====================================================================

-- 1. Create Database Master Key if not already present
IF NOT EXISTS (SELECT * FROM sys.symmetric_keys WHERE name LIKE '%DatabaseMasterKey%')
    CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'SecureComplexMasterKey#2024!';

-- 2. Create Database Scoped Credential using Managed Identity
CREATE DATABASE SCOPED CREDENTIAL PolyBase_MSI_Cred
WITH IDENTITY = 'Managed Identity';

-- 3. Define External Data Source pointing to ADLS Gen2 container
CREATE EXTERNAL DATA SOURCE ADLS_Curated_Lake
WITH (
    TYPE = HADOOP,
    LOCATION = 'abfss://curated@eubfsidatalakeprod.dfs.core.windows.net',
    CREDENTIAL = PolyBase_MSI_Cred
);

-- 4. Define External File Format for Snappy-compressed Parquet
CREATE EXTERNAL FILE FORMAT Parquet_Snappy_Format
WITH (
    FORMAT_TYPE = PARQUET,
    DATA_COMPRESSION = 'org.apache.hadoop.io.compress.SnappyCodec'
);

-- 5. Create External Table over ADLS Gen2 Parquet dataset
CREATE EXTERNAL TABLE ext.FactTransactions (
    transaction_id      VARCHAR(64)     NOT NULL,
    account_id          BIGINT          NOT NULL,
    transaction_amount  DECIMAL(18, 2)  NOT NULL,
    currency_code       CHAR(3)         NOT NULL,
    transaction_date    DATE            NOT NULL
)
WITH (
    LOCATION = '/transactions/active/',
    DATA_SOURCE = ADLS_Curated_Lake,
    FILE_FORMAT = Parquet_Snappy_Format
);

-- 6. Ingest into internal Clustered Columnstore fact table via CTAS
CREATE TABLE dbo.FactTransactions_Internal
WITH (
    DISTRIBUTION = HASH(account_id),
    CLUSTERED COLUMNSTORE INDEX
)
AS
SELECT * FROM ext.FactTransactions;
```

**Enterprise Data Scenario:**  
Enterprise hybrid data lake virtualization architecture allowing on-premises SQL Server 2022 and Synapse Dedicated Pools to ingest Azure Data Lake Parquet files directly via T-SQL.

**Optimizer Invariants & Performance Traps:**
- PolyBase requires all 3 foundation objects: Credential, Data Source, and File Format
- FORMAT_TYPE = PARQUET automatically utilizes Snappy decompression natively
- CTAS distributes the read across all 60 MPP compute nodes, transforming external files into native columnstore
- For SQL Server 2022 on-premises, PolyBase connects to S3-compatible storage using S3 credentials

---

### Q3.14: Safe Chunked Batch Deletion Pattern (Production Operations & Maintenance)

**Question & Concept Overview:**  
Purges millions of historical records from high-throughput tables in iterative small chunks to prevent transaction log full errors and avoid table lock escalation.

**SQL Implementation & Query Plan:**
```sql
SET NOCOUNT ON;
DECLARE @BatchSize INT = 5000;
DECLARE @RowsDeleted INT = 1;
DECLARE @TotalDeleted INT = 0;

WHILE @RowsDeleted > 0
BEGIN
    BEGIN TRANSACTION;
    
    DELETE TOP (@BatchSize)
    FROM dbo.fact_audit_log WITH (ROWLOCK)
    WHERE log_date < DATEADD(month, -6, GETUTCDATE());
    
    SET @RowsDeleted = @@ROWCOUNT;
    SET @TotalDeleted = @TotalDeleted + @RowsDeleted;
    
    COMMIT TRANSACTION;
    
    -- Optional: checkpoint log breath and reduce CPU throttling
    WAITFOR DELAY '00:00:01';
END;

PRINT CONCAT('Successfully deleted total records: ', @TotalDeleted);
```

**Enterprise Data Scenario:**  
Archiving historical telemetry, GDPR data deletion, and high-throughput production table maintenance without downtime.

**Optimizer Invariants & Performance Traps:**
- Keeps transaction size strictly under 5,000 rows to prevent lock escalation from ROWLOCK to TABLOCK
- Short transactions allow the database checkpoint engine to truncate the transaction log (.ldf)
- WAITFOR DELAY yields CPU cycles back to concurrent OLTP workloads

---

### Q3.15: Mitigating Parameter Sniffing via OPTIMIZE FOR and RECOMPILE (Performance Tuning)

**Question & Concept Overview:**  
Hardens stored procedures against cached execution plan regressions caused by parameter sniffing across heavily skewed datasets.

**SQL Implementation & Query Plan:**
```sql
CREATE OR ALTER PROCEDURE dbo.usp_get_orders_by_status
    @order_status VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Strategy 1: Standard query with OPTIMIZE FOR UNKNOWN
    -- Generates a stable plan based on average statistical distribution
    SELECT 
        order_id,
        customer_id,
        order_date,
        total_amount_eur
    FROM dbo.fact_orders
    WHERE order_status = @order_status
    OPTION (OPTIMIZE FOR (@order_status UNKNOWN));
    
    -- Strategy 2: For extreme cardinality differences, force statement-level recompile
    -- SELECT * FROM dbo.fact_orders WHERE order_status = @order_status OPTION (RECOMPILE);
END;
```

**Enterprise Data Scenario:**  
Production OLTP APIs and ETL stored procedures filtering on volatile status or flag columns.

**Optimizer Invariants & Performance Traps:**
- OPTIMIZE FOR UNKNOWN instructs the query optimizer to use the density vector rather than sniffing the runtime value
- OPTION (RECOMPILE) produces an optimal plan per call at the cost of a few milliseconds of CPU compilation time
- Prevents production latency spikes where a 50ms procedure intermittently stalls for 60 seconds

---

### Q3.16: Production Stored Procedure Template with TRY...CATCH & RCSI (Stored Procedures & Concurrency)

**Question & Concept Overview:**  
Standard enterprise stored procedure template incorporating atomic transaction management, error throwing, and deadlock resilience.

**SQL Implementation & Query Plan:**
```sql
CREATE OR ALTER PROCEDURE dbo.TransferFunds
    @SourceAccountID      INT,
    @DestinationAccountID INT,
    @Amount               DECIMAL(18, 2)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON; -- Automatically rolls back transaction if run-time error occurs

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Enforce uniform object access order (lock lower ID first to prevent deadlocks):
        IF @SourceAccountID > @DestinationAccountID
        BEGIN
            -- Swap to guarantee uniform lock sequence:
            DECLARE @TempID INT = @SourceAccountID;
            SET @SourceAccountID = @DestinationAccountID;
            SET @DestinationAccountID = @TempID;
        END

        UPDATE dbo.Accounts SET Balance = Balance - @Amount WHERE AccountID = @SourceAccountID;
        UPDATE dbo.Accounts SET Balance = Balance + @Amount WHERE AccountID = @DestinationAccountID;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        -- Re-throw the original error with line number and state:
        THROW;
    END CATCH
END;
```

**Enterprise Data Scenario:**  
High-throughput financial and transactional processing procedures.

**Optimizer Invariants & Performance Traps:**
- SET XACT_ABORT ON ensures orphaned locks are released if connection aborts.
- Locking accounts in uniform numerical order mathematically prevents cyclic deadlock chains.
- Structured THROW preserves original error number, severity, and call stack.

---

### Q3.17: Gaps & Islands Consecutive Sequence Analysis (Analytical Window Functions)

**Question & Concept Overview:**  
Identifies contiguous active streaks (e.g. users logging in >= 3 consecutive days) using the Date - ROW_NUMBER() island grouping invariant.

**SQL Implementation & Query Plan:**
```sql
WITH DailyLogins AS (
    SELECT DISTINCT UserID, CAST(LoginTime AS DATE) AS LoginDate
    FROM dbo.UserActivity
),
IslandGrouped AS (
    SELECT 
        UserID,
        LoginDate,
        -- The invariant: Date - RowNumber produces a static anchor for consecutive days:
        DATEADD(day, -ROW_NUMBER() OVER (PARTITION BY UserID ORDER BY LoginDate), LoginDate) AS IslandAnchor
    FROM DailyLogins
)
SELECT 
    UserID,
    MIN(LoginDate) AS StreakStart,
    MAX(LoginDate) AS StreakEnd,
    COUNT(*)       AS ConsecutiveDays
FROM IslandGrouped
GROUP BY UserID, IslandAnchor
HAVING COUNT(*) >= 3
ORDER BY UserID, StreakStart;
```

**Enterprise Data Scenario:**  
Product engagement tracking, customer loyalty gamification, and machine sensor SLA monitoring.

**Optimizer Invariants & Performance Traps:**
- DISTINCT in CTE ensures duplicate logins on the same calendar day do not corrupt the sequence.
- DATEADD(day, -rn, date) evaluates in a single pass without expensive self-joins.
- Applicable to sensor telemetry uptime, recurring billing streaks, and gaming engagement.

---

### Q3.18: MERGE INTO for SCD Type 2 (Slowly Changing Dimensions) (Delta Lake Patterns)

**Question & Concept Overview:**  
SCD Type 2 preserves full history by closing old records and inserting new versions when dimension attributes change. Delta's MERGE INTO with multiple WHEN clauses implements SCD2 atomically. This pattern is critical for financial systems where account and customer attribute history must be preserved for regulatory audit trails.

**SQL Implementation & Query Plan:**
```sql
-- =============================================
-- SCD Type 2 with MERGE INTO
-- EU BFSI — Customer Risk Profile History
-- =============================================

USE CATALOG eu_bfsi_prod;
USE SCHEMA silver;

-- Target SCD2 table structure:
-- CREATE TABLE silver_dim_customer (
--     surrogate_key   BIGINT GENERATED ALWAYS AS IDENTITY,
--     customer_id     STRING NOT NULL,
--     customer_name   STRING,
--     risk_tier       STRING,
--     kyc_status      STRING,
--     pep_flag        BOOLEAN,
--     nationality     STRING,
--     effective_from  TIMESTAMP NOT NULL,
--     effective_to    TIMESTAMP,  -- NULL = current active record
--     is_current      BOOLEAN NOT NULL,
--     record_hash     STRING NOT NULL,  -- MD5 of SCD2 attributes
--     created_ts      TIMESTAMP,
--     updated_ts      TIMESTAMP
-- ) USING DELTA
-- TBLPROPERTIES ('delta.enableChangeDataFeed' = 'true');

-- Stage incoming changes with hash for change detection
CREATE OR REPLACE TEMPORARY VIEW v_customer_changes AS
SELECT
    customer_id,
    customer_name,
    risk_tier,
    kyc_status,
    pep_flag,
    nationality,
    current_timestamp()                                         AS effective_from,
    MD5(CONCAT_WS('|',
        COALESCE(risk_tier, ''),
        COALESCE(kyc_status, ''),
        COALESCE(CAST(pep_flag AS STRING), ''),
        COALESCE(nationality, '')
    ))                                                          AS record_hash
FROM bronze_customer_updates
WHERE batch_date = current_date();

-- Step 1: Close existing active records that have changed
MERGE INTO silver_dim_customer AS target
USING (
    SELECT
        src.customer_id,
        src.record_hash                 AS new_hash,
        tgt.surrogate_key               AS old_surrogate_key
    FROM v_customer_changes src
    JOIN silver_dim_customer tgt
        ON  src.customer_id = tgt.customer_id
        AND tgt.is_current = true
        AND src.record_hash != tgt.record_hash  -- Attribute change detected
) AS changed_records
ON target.surrogate_key = changed_records.old_surrogate_key
WHEN MATCHED THEN
    UPDATE SET
        target.effective_to = current_timestamp() - INTERVAL 1 MILLISECOND,
        target.is_current   = false,
        target.updated_ts   = current_timestamp();

-- Step 2: Insert new versions for changed records + new customers
MERGE INTO silver_dim_customer AS target
USING (
    -- New versions for changed existing records
    SELECT
        src.customer_id,
        src.customer_name,
        src.risk_tier,
        src.kyc_status,
        src.pep_flag,
        src.nationality,
        src.effective_from,
        NULL                AS effective_to,
        true                AS is_current,
        src.record_hash,
        current_timestamp() AS created_ts,
        current_timestamp() AS updated_ts
    FROM v_customer_changes src
    -- Rows that had existing records but changed
    WHERE EXISTS (
        SELECT 1 FROM silver_dim_customer tgt
        WHERE tgt.customer_id = src.customer_id
          AND tgt.is_current = false
          AND tgt.updated_ts >= current_timestamp() - INTERVAL 5 MINUTES
    )
    UNION ALL
    -- Entirely new customers
    SELECT
        src.customer_id,
        src.customer_name,
        src.risk_tier,
        src.kyc_status,
        src.pep_flag,
        src.nationality,
        src.effective_from,
        NULL                AS effective_to,
        true                AS is_current,
        src.record_hash,
        current_timestamp() AS created_ts,
        current_timestamp() AS updated_ts
    FROM v_customer_changes src
    WHERE NOT EXISTS (
        SELECT 1 FROM silver_dim_customer tgt
        WHERE tgt.customer_id = src.customer_id
    )
) AS new_records
ON 1 = 0  -- Never match — always INSERT
WHEN NOT MATCHED THEN
    INSERT (
        customer_id, customer_name, risk_tier, kyc_status,
        pep_flag, nationality, effective_from, effective_to,
        is_current, record_hash, created_ts, updated_ts
    )
    VALUES (
        new_records.customer_id, new_records.customer_name,
        new_records.risk_tier, new_records.kyc_status,
        new_records.pep_flag, new_records.nationality,
        new_records.effective_from, new_records.effective_to,
        new_records.is_current, new_records.record_hash,
        new_records.created_ts, new_records.updated_ts
    );
```

**Enterprise Data Scenario:**  
Customer risk profile history at a European private bank — SCD2 preserves complete audit trail of risk tier changes required by MiFID II suitability assessments, allowing retrospective analysis of whether a customer was classified correctly at the time of each investment recommendation.

**Optimizer Invariants & Performance Traps:**
- Two-step MERGE is required for SCD2: Step 1 closes old records, Step 2 inserts new versions — keeps logic clear
- MD5/SHA hash on SCD2 attributes enables efficient change detection without comparing every column individually
- ON 1 = 0 is the 'insert-only MERGE' pattern — forces all rows to go to the WHEN NOT MATCHED branch
- is_current flag + NULL effective_to identifies current records; always index/cluster on (customer_id, is_current)
- Consider GENERATED ALWAYS AS IDENTITY for surrogate keys — Delta natively supports identity columns since DBR 10.4

---

### Q3.19: OPTIMIZE and Z-ORDER BY for Delta Performance (Delta Lake Optimization)

**Question & Concept Overview:**  
OPTIMIZE compacts small Delta files into optimal-sized Parquet files (typically 1GB target), dramatically improving query scan performance. Z-ORDER BY co-locates data with similar values of specified columns within files, enabling data skipping. Together they are the primary performance tuning levers for Delta tables in Databricks.

**SQL Implementation & Query Plan:**
```sql
-- =============================================
-- OPTIMIZE & Z-ORDER — Delta Table Tuning
-- EU BFSI — Transaction Table Optimization
-- =============================================

USE CATALOG eu_bfsi_prod;
USE SCHEMA silver;

-- 1. Basic OPTIMIZE — compact small files
OPTIMIZE silver_transactions;

-- 2. OPTIMIZE with Z-ORDER (co-locate data by query columns)
OPTIMIZE silver_transactions
ZORDER BY (account_id, txn_currency, txn_date);
-- Tip: Z-ORDER on columns most used in WHERE/JOIN predicates

-- 3. OPTIMIZE a specific partition (incremental — new data only)
OPTIMIZE silver_transactions
WHERE txn_date = current_date() - INTERVAL 1 DAY
ZORDER BY (account_id, txn_currency);

-- 4. Check optimization statistics
DESCRIBE DETAIL silver_transactions;
-- Shows: numFiles, sizeInBytes, numPartitions, minReaderVersion

-- 5. ANALYZE TABLE — compute statistics for the query optimizer
ANALYZE TABLE silver_transactions COMPUTE STATISTICS;
ANALYZE TABLE silver_transactions COMPUTE STATISTICS FOR COLUMNS
    account_id, txn_currency, txn_amount, txn_date;

-- 6. Set auto-optimize properties
ALTER TABLE silver_transactions
SET TBLPROPERTIES (
    'delta.autoOptimize.optimizeWrite'  = 'true',  -- Compact on write
    'delta.autoOptimize.autoCompact'    = 'true',  -- Background compaction
    'delta.targetFileSize'              = '134217728',  -- 128MB target
    'delta.tuneFileSizesForRewrites'    = 'true'   -- Optimize for MERGE
);

-- 7. VACUUM — remove old/deleted files (safe to run after OPTIMIZE)
-- Default retention = 7 days. Never set to 0 in production.
VACUUM silver_transactions RETAIN 168 HOURS;  -- 7 days
-- Dry run first:
VACUUM silver_transactions DRY RUN;           -- Shows files to be deleted

-- 8. Liquid Clustering (DBR 13.3+) — dynamic, incremental clustering
-- Applied at CREATE time:
-- CREATE TABLE ... CLUSTER BY (account_id, txn_currency);

-- Add/change cluster keys on existing table:
ALTER TABLE silver_transactions
CLUSTER BY (account_id, txn_currency, txn_date);

-- Run clustering (equivalent to OPTIMIZE for liquid clustering)
OPTIMIZE silver_transactions;
-- Databricks auto-selects Z-ORDER columns from CLUSTER BY definition

-- 9. Bloom filter index for equality predicates
CREATE BLOOMFILTER INDEX ON TABLE silver_transactions
FOR COLUMNS (txn_id OPTIONS (fpp=0.01, numItems=1000000000));
-- fpp = false positive probability; lower = larger index but better filtering
```

**Enterprise Data Scenario:**  
Post-load optimization for a European bank's silver transaction table receiving 50M+ daily records — OPTIMIZE with Z-ORDER on (account_id, txn_currency) reduces AML query scan time from 4 minutes to 18 seconds by enabling Delta data skipping to eliminate 94% of files for account-specific queries.

**Optimizer Invariants & Performance Traps:**
- ZORDER BY significantly improves data skipping — Delta skips entire files when min/max column statistics don't overlap the query predicate
- Z-ORDER is most effective on high-cardinality columns used in WHERE clauses; avoid low-cardinality columns (e.g., boolean flags)
- Liquid Clustering is the modern replacement for both static partitioning and Z-ORDER — supports incremental re-clustering without full rewrites
- VACUUM permanently deletes files — ensure no active time travel queries or streaming checkpoints reference older versions before running
- OPTIMIZE is idempotent — run it in production pipelines after bulk loads; use WHERE clause to target only new partitions

---

### Q3.20: Delta Change Data Feed (CDF) — SQL (Delta Lake Features)

**Question & Concept Overview:**  
Delta Change Data Feed (CDF) captures row-level change events (insert, update_preimage, update_postimage, delete) on Delta tables. It enables efficient incremental propagation through Medallion layers, CDC pipelines, and audit logging without full table scans. CDF is enabled per table and queryable via SQL.

**SQL Implementation & Query Plan:**
```sql
-- =============================================
-- Delta Change Data Feed (CDF)
-- EU BFSI — Incremental Silver→Gold Propagation
-- =============================================

USE CATALOG eu_bfsi_prod;
USE SCHEMA silver;

-- 1. Enable CDF on existing table
ALTER TABLE silver_accounts
SET TBLPROPERTIES ('delta.enableChangeDataFeed' = 'true');

-- 2. Read changes since a specific version
SELECT
    _change_type,       -- insert | update_preimage | update_postimage | delete
    _commit_version,    -- Delta version of the commit
    _commit_timestamp,  -- Timestamp of the commit
    account_id,
    risk_tier,
    kyc_status,
    account_status
FROM table_changes('eu_bfsi_prod.silver.silver_accounts', 150)
ORDER BY _commit_version, _change_type;

-- 3. Read changes between version range
SELECT *
FROM table_changes('eu_bfsi_prod.silver.silver_accounts', 100, 200);

-- 4. Read changes since a timestamp
SELECT *
FROM table_changes(
    'eu_bfsi_prod.silver.silver_accounts',
    '2024-12-01T00:00:00.000+00:00'
);

-- 5. Practical: Only get UPDATES (before/after pair)
SELECT
    pre.account_id,
    pre.risk_tier         AS old_risk_tier,
    post.risk_tier        AS new_risk_tier,
    pre.kyc_status        AS old_kyc_status,
    post.kyc_status       AS new_kyc_status,
    post._commit_timestamp AS change_ts
FROM table_changes('eu_bfsi_prod.silver.silver_accounts',
                   '2024-12-01T00:00:00.000+00:00') pre
JOIN table_changes('eu_bfsi_prod.silver.silver_accounts',
                   '2024-12-01T00:00:00.000+00:00') post
    ON pre.account_id = post.account_id
    AND pre._commit_version  = post._commit_version
    AND pre._change_type  = 'update_preimage'
    AND post._change_type = 'update_postimage'
WHERE pre.risk_tier != post.risk_tier;  -- Only risk tier changes

-- 6. CDF for incremental gold layer propagation
INSERT INTO eu_bfsi_prod.gold.gold_account_risk_changes
SELECT
    account_id,
    _change_type            AS change_type,
    _commit_version         AS source_version,
    _commit_timestamp       AS change_ts,
    risk_tier,
    kyc_status,
    current_timestamp()     AS processed_ts
FROM table_changes(
    'eu_bfsi_prod.silver.silver_accounts',
    (
        SELECT COALESCE(MAX(source_version), 0)
        FROM eu_bfsi_prod.gold.gold_account_risk_changes
    )  -- Start from last processed version
)
WHERE _change_type IN ('update_postimage', 'insert');
```

**Enterprise Data Scenario:**  
Incremental silver→gold propagation at a European asset management firm — CDF eliminates the need to full-scan the 2-billion-row silver_accounts table nightly; instead the gold layer processes only the ~50,000 daily changed rows, reducing pipeline runtime from 2 hours to 3 minutes.

**Optimizer Invariants & Performance Traps:**
- CDF captures update_preimage (before) and update_postimage (after) for each UPDATE — join them on account_id + _commit_version for before/after comparison
- CDF storage overhead is minimal — it stores only the changed rows, not full snapshots
- Use _commit_version watermarking pattern (MAX of last processed version) for idempotent incremental loads
- CDF works with streaming: spark.readStream.format('delta').option('readChangeFeed', 'true').load(path)
- CDF requires minReaderVersion=2 and minWriterVersion=4 — automatically set when enabling CDF

---

### Q3.21: Streaming Queries in Spark SQL (Streaming)

**Question & Concept Overview:**  
Spark Structured Streaming exposes a SQL interface for building real-time pipelines. In Databricks, streaming SQL queries can read from Delta tables, Kafka, or Event Hubs as sources and write to Delta as sinks. Trigger options control micro-batch frequency, enabling near-real-time fraud detection and payment processing.

**SQL Implementation & Query Plan:**
```sql
-- =============================================
-- Structured Streaming in Spark SQL
-- EU BFSI — Real-time Payment Fraud Detection
-- =============================================

-- Note: Full streaming setup done via PySpark API;
-- SQL cells in Databricks can run streaming queries
-- using CREATE STREAMING TABLE (DLT) or via SQL API.

-- ── In Databricks SQL (non-DLT) ─────────────────
-- Use spark.sql() from PySpark notebook:

-- PySpark bootstrap for streaming:
-- stream_df = (
--   spark.readStream
--     .format('delta')
--     .option('readChangeFeed', 'true')
--     .option('startingVersion', 'latest')
--     .table('eu_bfsi_prod.bronze.bronze_transactions')
-- )
-- stream_df.createOrReplaceTempView('streaming_transactions')

-- ── Then query with SQL ──────────────────────────

-- 1. Streaming aggregation with watermark (SQL via spark.sql)
-- SELECT
--     window(txn_timestamp, '5 minutes').start  AS window_start,
--     window(txn_timestamp, '5 minutes').end    AS window_end,
--     account_id,
--     COUNT(*)                                  AS txn_count_5min,
--     SUM(txn_amount)                           AS volume_5min,
--     MAX(txn_amount)                           AS max_txn_5min
-- FROM streaming_transactions
-- GROUP BY window(txn_timestamp, '5 minutes'), account_id

-- ── Full PySpark Streaming Example ──────────────
/*
from pyspark.sql import functions as F

# Read stream from Delta CDF
stream = (
    spark.readStream
        .format('delta')
        .option('readChangeFeed', 'true')
        .option('startingTimestamp', '2024-01-01')
        .table('eu_bfsi_prod.bronze.bronze_transactions')
        .where("_change_type = 'insert'")
)

# Apply fraud detection aggregation
fraud_alerts = (
    stream
    .withWatermark('txn_timestamp', '10 minutes')
    .groupBy(
        F.window('txn_timestamp', '5 minutes'),
        'account_id'
    )
    .agg(
        F.count('*').alias('txn_count'),
        F.sum('txn_amount').alias('total_amount'),
        F.collect_set('counterparty_country').alias('countries')
    )
    .where('txn_count > 10 OR total_amount > 100000')
)

# Write to Delta alert table
query = (
    fraud_alerts.writeStream
        .format('delta')
        .outputMode('append')
        .option('checkpointLocation',
                'abfss://checkpoints@euadlsprod.dfs.core.windows.net/fraud_stream/')
        .trigger(processingTime='30 seconds')
        .toTable('eu_bfsi_prod.gold.gold_realtime_fraud_alerts')
)
*/

-- ── Foreground streaming Delta table query ───────
-- After streaming writes, query the output table normally:
SELECT
    window_start,
    window_end,
    account_id,
    txn_count_5min,
    volume_5min,
    SIZE(countries)         AS unique_countries,
    CASE
        WHEN txn_count_5min > 50  THEN 'HIGH_VELOCITY'
        WHEN volume_5min > 500000 THEN 'HIGH_VALUE'
        ELSE 'STANDARD'
    END                     AS alert_type,
    current_timestamp()     AS alerted_ts
FROM eu_bfsi_prod.gold.gold_realtime_fraud_alerts
WHERE window_start >= current_timestamp() - INTERVAL 1 HOUR
ORDER BY volume_5min DESC;
```

**Enterprise Data Scenario:**  
Real-time payment fraud detection at a European payments processor — 5-minute tumbling windows on transaction streams detect velocity attacks (>10 transactions in 5 minutes) and high-value anomalies, triggering fraud alerts to Visa/Mastercard within 30 seconds of suspicious activity.

**Optimizer Invariants & Performance Traps:**
- Watermarks define how late data is tolerated before a streaming window closes — critical for out-of-order payment events
- Trigger(processingTime='30 seconds') creates micro-batches; Trigger(once=True) processes all available data once (batch-streaming hybrid)
- Checkpoints store streaming state — always use ADLS Gen2 paths for fault-tolerant, resumable streams in Azure Databricks
- Delta's exactly-once semantics with idempotent writes ensure no duplicate alerts even after stream failures and restarts
- Use Delta Live Tables (DLT) for production streaming — it manages checkpoints, restarts, and monitoring automatically

---

### Q3.22: Schema Enforcement and Schema Evolution in Delta (Delta Lake Features)

**Question & Concept Overview:**  
Delta Lake enforces schema on write by default, rejecting data that doesn't match the table schema. Schema evolution allows controlled schema changes (adding columns, widening types) via configuration or DDL. Understanding when to enforce vs evolve schemas is critical for data quality and pipeline reliability in BFSI environments.

**SQL Implementation & Query Plan:**
```sql
-- =============================================
-- Schema Enforcement & Evolution
-- EU BFSI — Handling Source Schema Changes
-- =============================================

USE CATALOG eu_bfsi_prod;
USE SCHEMA silver;

-- 1. Schema enforcement is ON by default
-- This INSERT will FAIL if source has extra/missing columns:
-- INSERT INTO silver_transactions SELECT * FROM bronze_with_new_cols;
-- Error: A schema mismatch detected when writing to the Delta table

-- 2. Enable schema evolution for MERGE/INSERT
-- Option A: Session-level config
SET spark.databricks.delta.schema.autoMerge.enabled = true;

-- 3. Add columns via ALTER TABLE (preferred explicit approach)
ALTER TABLE silver_transactions
    ADD COLUMN iban_sender  STRING COMMENT 'IBAN of sending account (SEPA mandate)',
    ADD COLUMN iban_receiver STRING COMMENT 'IBAN of receiving account (SEPA mandate)',
    ADD COLUMN sepa_mandate_ref STRING COMMENT 'SEPA direct debit mandate reference';

-- 4. Rename column (requires columnMapping mode = name)
ALTER TABLE silver_transactions
    RENAME COLUMN txn_status TO transaction_status;

-- 5. Drop column (soft-drop with column mapping)
ALTER TABLE silver_transactions
    DROP COLUMN legacy_batch_code;
-- Note: Data is NOT physically removed — column mapping hides it
-- Physical removal requires REORG TABLE ... APPLY (PURGE)

REORG TABLE silver_transactions APPLY (PURGE);
-- This rewrites Parquet files without dropped columns

-- 6. Change column comment
ALTER TABLE silver_transactions
    ALTER COLUMN txn_amount
    COMMENT 'Transaction amount in originating currency — DECIMAL(18,4)';

-- 7. Column mapping modes
ALTER TABLE silver_transactions
SET TBLPROPERTIES (
    'delta.columnMapping.mode' = 'name',  -- Enables rename/drop
    'delta.minReaderVersion'   = '2',
    'delta.minWriterVersion'   = '5'
);

-- 8. Schema evolution in MERGE (with autoMerge enabled)
-- Source has new column 'sepa_mandate_ref' not in target:
MERGE INTO silver_transactions AS t
USING bronze_transactions_v2 AS s
ON t.txn_id = s.txn_id
WHEN MATCHED THEN UPDATE SET *  -- Includes new columns if autoMerge enabled
WHEN NOT MATCHED THEN INSERT *;  -- Inserts all source columns

-- 9. Type widening (DBR 14.1+)
ALTER TABLE silver_transactions
    ALTER COLUMN processing_fee TYPE DECIMAL(18,6);
-- Widening DECIMAL(10,4) → DECIMAL(18,6) is safe
-- Narrowing (18,6 → 10,4) is NOT supported

-- 10. Check current schema evolution settings
SHOW TBLPROPERTIES silver_transactions;
```

**Enterprise Data Scenario:**  
Handling SWIFT ISO 20022 schema migration at a European correspondent bank — the message format added 15 new optional fields in the 2024 standard update. Delta column mapping allows adding new columns without table rewrites, while existing consumers continue reading the old schema without code changes.

**Optimizer Invariants & Performance Traps:**
- Schema enforcement protects data quality — never disable autoMerge globally; enable per-session or per-table carefully
- Column mapping (mode=name) is required for RENAME and DROP column operations — enables physical-logical column name decoupling
- REORG TABLE ... APPLY (PURGE) physically rewrites files to remove dropped columns — needed for GDPR column-level erasure
- Type widening (INT→BIGINT, DECIMAL scale increase) is safe; type narrowing is never allowed in Delta
- Schema evolution in MERGE with * wildcard is powerful but risky — new source columns silently propagate to target; validate source schema changes explicitly

---

### Q3.23: External Tables vs Managed Tables and Hive vs Unity Catalog (Metadata & Catalog)

**Question & Concept Overview:**  
Understanding the distinction between managed and external tables, and between Hive Metastore and Unity Catalog, is fundamental for enterprise data governance. Each has different behavior on DROP TABLE, storage ownership, and access control. Unity Catalog adds catalog-level governance, lineage, and fine-grained access controls not available in Hive.

**SQL Implementation & Query Plan:**
```sql
-- =============================================
-- Managed vs External Tables
-- Hive Metastore vs Unity Catalog
-- EU BFSI — Data Governance Architecture
-- =============================================

-- ── MANAGED TABLE (Unity Catalog manages storage) ──
CREATE TABLE IF NOT EXISTS eu_bfsi_prod.silver.silver_transactions
(
    txn_id      STRING NOT NULL,
    txn_amount  DECIMAL(18,4),
    txn_date    DATE
)
USING DELTA
COMMENT 'Managed table — UC owns storage lifecycle';
-- Storage: auto-assigned under schema MANAGED LOCATION
-- DROP TABLE: deletes BOTH metadata AND data files !

-- ── EXTERNAL TABLE (you own the storage) ──────────
CREATE TABLE IF NOT EXISTS eu_bfsi_prod.bronze.bronze_swift_messages
USING DELTA
LOCATION 'abfss://bronze@euadlsprod.dfs.core.windows.net/swift/'
COMMENT 'External table — ADLS path controlled independently';
-- DROP TABLE: deletes ONLY metadata. Data files remain.

-- ── Convert external to managed (via CLONE) ───────
CREATE TABLE eu_bfsi_prod.silver.silver_swift_messages
DEEP CLONE eu_bfsi_prod.bronze.bronze_swift_messages;

-- ── Hive Metastore table (legacy) ─────────────────
-- USE CATALOG hive_metastore;
-- USE SCHEMA default;
-- CREATE TABLE hms_transactions USING DELTA LOCATION '/mnt/silver/transactions/';
-- Note: No catalog-level governance, no column-level security,
--       no automated lineage in Hive Metastore

-- ── Unity Catalog migration pattern ───────────────
-- SYNC from Hive Metastore to UC using SYNC command:
SYNC SCHEMA eu_bfsi_prod.silver
FROM hive_metastore.eu_bfsi_silver
DRY RUN;  -- Preview before executing

-- ── Unity Catalog governance features ─────────────
-- 1. Table owner
ALTER TABLE eu_bfsi_prod.silver.silver_transactions
    SET OWNER TO `data-engineering-team`;

-- 2. Column-level comment for data catalog
ALTER TABLE eu_bfsi_prod.silver.silver_transactions
    ALTER COLUMN txn_amount
    COMMENT 'Transaction monetary amount; classified as PII-adjacent financial data';

-- 3. Table tags (Unity Catalog)
ALTER TABLE eu_bfsi_prod.silver.silver_transactions
    SET TAGS ('data_classification' = 'CONFIDENTIAL',
              'data_domain' = 'payments',
              'retention_years' = '7',
              'gdpr_relevant' = 'true');

-- 4. View table lineage (via UI or API)
-- SELECT * FROM system.access.table_lineage
-- WHERE target_table_full_name = 'eu_bfsi_prod.silver.silver_transactions';

-- 5. Cross-catalog query (Unity Catalog)
SELECT
    a.account_id,
    a.risk_tier,
    b.txn_count,
    b.total_amount_eur
FROM eu_bfsi_prod.silver.silver_accounts a
JOIN eu_bfsi_analytics.gold.gold_account_metrics b
    ON a.account_id = b.account_id
WHERE a.risk_tier = 'HIGH';
```

**Enterprise Data Scenario:**  
Migrating a European bank's Databricks workspace from Hive Metastore to Unity Catalog — external Delta tables are preserved during migration (data untouched), while Unity Catalog's GRANT/REVOKE and column masking replace the legacy IP-based access controls that couldn't scale to 400+ data consumers across 12 EU jurisdictions.

**Optimizer Invariants & Performance Traps:**
- DROP on managed table = data loss; DROP on external table = metadata only — this difference is critical for production governance
- Unity Catalog's three-level namespace (catalog.schema.table) enables cross-workspace and cross-environment queries
- External tables are preferred when data is shared with non-Databricks consumers (ADF, Synapse, Fabric) or when storage lifecycle is managed independently
- Unity Catalog provides automated data lineage — column-level lineage tracks transformation across notebooks, jobs, and SQL queries
- Hive Metastore is workspace-scoped; Unity Catalog is account-scoped — enabling cross-workspace governance from a single control plane

---

### Q3.24: EXPLAIN EXTENDED and Query Hints (Query Optimization)

**Question & Concept Overview:**  
EXPLAIN EXTENDED reveals the full logical, analyzed, optimized, and physical execution plan for a Spark SQL query. Query hints allow engineers to override Spark's optimizer decisions for joins and aggregations. These tools are essential for diagnosing performance issues in complex BFSI pipelines where the optimizer makes suboptimal choices.

**SQL Implementation & Query Plan:**
```sql
-- =============================================
-- EXPLAIN & Query Hints — Performance Tuning
-- EU BFSI — Optimizing COREP Report Queries
-- =============================================

USE CATALOG eu_bfsi_prod;
USE SCHEMA gold;

-- 1. EXPLAIN — show physical plan only
EXPLAIN
SELECT account_id, SUM(txn_amount_eur)
FROM silver_transactions
WHERE txn_date = '2024-12-31'
GROUP BY account_id;

-- 2. EXPLAIN EXTENDED — full plan (logical, analyzed, optimized, physical)
EXPLAIN EXTENDED
SELECT
    t.account_id,
    a.risk_tier,
    SUM(t.txn_amount_eur) AS total_eur
FROM silver_transactions t
JOIN silver_accounts a ON t.account_id = a.account_id
WHERE t.txn_date BETWEEN '2024-01-01' AND '2024-12-31'
GROUP BY t.account_id, a.risk_tier;
-- Look for: FileScan (partition pruning), BroadcastHashJoin vs SortMergeJoin

-- 3. EXPLAIN FORMATTED — structured output for parsing
EXPLAIN FORMATTED
SELECT * FROM silver_transactions WHERE account_id = 'ACC-123456';

-- 4. EXPLAIN COST — includes estimated row counts and sizes
EXPLAIN COST
SELECT account_id, COUNT(*) FROM silver_transactions GROUP BY account_id;

-- ─────────────────────────────────────────────
-- QUERY HINTS
-- ─────────────────────────────────────────────

-- 5. BROADCAST hint — force small table broadcast
SELECT /*+ BROADCAST(a) */
    t.txn_id,
    t.txn_amount,
    a.account_type,
    a.risk_tier
FROM silver_transactions t
JOIN silver_accounts a ON t.account_id = a.account_id
WHERE t.txn_date = current_date();
-- Use when: silver_accounts < 10MB (small dim), auto-broadcast not triggered

-- 6. MERGE join hint — force sort-merge join
SELECT /*+ MERGE(t, r) */
    t.txn_id,
    r.regulation_code
FROM silver_transactions t
JOIN dim_regulation_mappings r
    ON t.txn_amount BETWEEN r.min_amount AND r.max_amount
WHERE t.txn_date = current_date();

-- 7. SHUFFLE_HASH hint — use shuffle hash join
SELECT /*+ SHUFFLE_HASH(t) */
    t.account_id,
    s.statement_month,
    SUM(t.txn_amount) AS total
FROM silver_transactions t
JOIN silver_statements s ON t.account_id = s.account_id
GROUP BY t.account_id, s.statement_month;

-- 8. COALESCE / REPARTITION hints
SELECT /*+ REPARTITION(50, account_id) */
    account_id,
    txn_currency,
    SUM(txn_amount_eur) AS total
FROM silver_transactions
WHERE txn_date >= '2024-01-01'
GROUP BY account_id, txn_currency;

-- 9. REBALANCE — adaptive output file sizing (Databricks)
SELECT /*+ REBALANCE(10) */
    *
FROM silver_transactions
WHERE txn_date = current_date();

-- 10. Skew join hint — handle data skew
SELECT /*+ SKEW('t', 'account_id', ('HIGH_VOLUME_ACCT_001', 'HIGH_VOLUME_ACCT_002')) */
    t.txn_id,
    t.txn_amount,
    a.risk_tier
FROM silver_transactions t
JOIN silver_accounts a ON t.account_id = a.account_id;
```

**Enterprise Data Scenario:**  
A TCS data engineer debugging a COREP regulatory report query that's taking 45 minutes due to a SortMergeJoin on a 500MB accounts dimension table — EXPLAIN EXTENDED reveals the auto-broadcast threshold was breached by 2MB; adding BROADCAST(a) hint drops runtime to 4 minutes.

**Optimizer Invariants & Performance Traps:**
- Look for 'BroadcastHashJoin' vs 'SortMergeJoin' in EXPLAIN output — SortMergeJoin on small tables indicates auto-broadcast threshold needs raising
- EXPLAIN EXTENDED shows 4 plans: Parsed → Analyzed → Optimized → Physical; the Physical plan is what actually runs
- BROADCAST hint is the most commonly needed — add it when joining a large fact table to a small dimension where auto-broadcast fails
- SKEW hint splits skewed partition keys into sub-partitions — critical for accounts with millions of transactions causing one executor to stall
- AQE (Adaptive Query Execution) handles many cases automatically in Spark 3.x — use EXPLAIN to verify AQE optimizations fired before adding hints

---

### Q3.25: Generated Columns, Column Masking, and TBLPROPERTIES (Delta Lake Features)

**Question & Concept Overview:**  
Generated columns are computed automatically from other columns on write, enabling derived partition keys without application changes. Column masking applies dynamic data redaction based on the querying user's permissions — critical for PII/GDPR compliance in BFSI environments. TBLPROPERTIES store feature flags and custom metadata.

**SQL Implementation & Query Plan:**
```sql
-- =============================================
-- Generated Columns, Column Masking, TBLPROPERTIES
-- EU BFSI — PII-Safe Transaction Analytics
-- =============================================

USE CATALOG eu_bfsi_prod;
USE SCHEMA silver;

-- 1. Generated columns — auto-derived on INSERT
CREATE TABLE IF NOT EXISTS silver_transactions_v2 (
    txn_id              STRING          NOT NULL,
    account_id          STRING          NOT NULL,
    txn_amount          DECIMAL(18, 4)  NOT NULL,
    txn_currency        STRING(3)       NOT NULL,
    txn_timestamp       TIMESTAMP       NOT NULL,

    -- Generated columns (computed from other columns)
    txn_date            DATE            GENERATED ALWAYS AS (DATE(txn_timestamp))
                        COMMENT 'Derived partition key from txn_timestamp',

    txn_year_month      STRING          GENERATED ALWAYS AS
                        (DATE_FORMAT(txn_timestamp, 'yyyy-MM'))
                        COMMENT 'Year-month label for reporting',

    amount_eur_band     STRING          GENERATED ALWAYS AS (
                        CASE
                            WHEN txn_amount <  1000   THEN 'MICRO'
                            WHEN txn_amount <  10000  THEN 'SMALL'
                            WHEN txn_amount <  100000 THEN 'MEDIUM'
                            WHEN txn_amount <  1000000 THEN 'LARGE'
                            ELSE                          'WHALE'
                        END)
                        COMMENT 'Amount band for regulatory bucketing',

    is_high_value       BOOLEAN         GENERATED ALWAYS AS (txn_amount >= 15000)
                        COMMENT 'CTR threshold flag (EU: 15,000 EUR)'
)
USING DELTA
PARTITIONED BY (txn_date)  -- Generated column used as partition key!
COMMENT 'Silver transactions with generated columns';

-- Insert works without specifying generated columns
INSERT INTO silver_transactions_v2 (txn_id, account_id, txn_amount, txn_currency, txn_timestamp)
VALUES ('TXN-001', 'ACC-001', 25000.00, 'EUR', '2024-12-15T14:30:00');
-- txn_date, txn_year_month, amount_eur_band, is_high_value are auto-computed

-- 2. Column Masking (Unity Catalog — DBR 12.2+)
-- Create a masking function
CREATE FUNCTION IF NOT EXISTS eu_bfsi_prod.security.mask_iban (
    iban STRING
)
RETURNS STRING
RETURN CASE
    WHEN is_member('data-analysts-gdpr')   THEN '****' || RIGHT(iban, 4)
    WHEN is_member('compliance-officers')  THEN LEFT(iban, 4) || '****' || RIGHT(iban, 4)
    ELSE iban  -- Full access for privileged users
END;

-- Apply mask to column
ALTER TABLE eu_bfsi_prod.silver.silver_accounts
    ALTER COLUMN iban
    SET MASK eu_bfsi_prod.security.mask_iban;

-- Unset mask
-- ALTER TABLE eu_bfsi_prod.silver.silver_accounts
--     ALTER COLUMN iban UNSET MASK;

-- 3. TBLPROPERTIES — feature flags and custom metadata
ALTER TABLE silver_transactions
SET TBLPROPERTIES (
    -- Delta feature flags
    'delta.enableChangeDataFeed'              = 'true',
    'delta.autoOptimize.optimizeWrite'        = 'true',
    'delta.autoOptimize.autoCompact'          = 'true',
    'delta.columnMapping.mode'                = 'name',
    'delta.enableDeletionVectors'             = 'true',  -- Faster DELETEs
    'delta.enableRowTracking'                 = 'true',  -- Row-level provenance
    -- Custom business metadata
    'data.owner'                              = 'payments-engineering@bank.eu',
    'data.classification'                     = 'CONFIDENTIAL',
    'data.gdpr'                               = 'true',
    'data.retention.years'                    = '7',
    'data.pii.columns'                        = 'account_id,iban_sender,iban_receiver',
    'pipeline.source'                         = 'AUTO_LOADER_V2',
    'pipeline.sla.hours'                      = '4',
    'business.domain'                         = 'PAYMENTS',
    'business.regulation'                     = 'PSD2,GDPR,AML5'
);
```

**Enterprise Data Scenario:**  
GDPR-compliant transaction analytics platform at a European bank — generated columns automatically derive CTR flags and amount bands from raw amounts, while column masking ensures IBAN numbers shown to analysts are redacted to last-4-digits, with full values visible only to compliance officers with the appropriate Unity Catalog group membership.

**Optimizer Invariants & Performance Traps:**
- Generated columns are enforced on write — if you INSERT a different value for a generated column, Spark throws an error
- Generated columns as partition keys eliminate the need for application code to extract partition values from timestamps
- Column masking is evaluated at query time per user/group — zero data movement, pure access control layer
- is_member() in masking functions checks Unity Catalog group membership dynamically at query runtime
- Deletion Vectors (TBLPROPERTIES 'delta.enableDeletionVectors'='true') make DELETE/UPDATE operations 10-100x faster by using soft-delete markers instead of file rewrites

---

---

### Q3.26: Databricks SQL Native GenAI Functions (Mosaic AI & GenAI SQL)

**Scenario & System Overview:**  
An enterprise data warehouse must automate customer feedback triage and PII anonymization directly in SQL ELT pipelines. How to use Databricks SQL AI Functions (`ai_query`, `ai_summarize`, `ai_classify`, `ai_extract`, `ai_mask`) to replace complex external Python microservices.

**Technical Deep-Dive & Architecture:**  
Databricks SQL AI functions execute serverless inference directly within the Photon query execution pipeline. The warehouse worker threads send batched vector/text payloads to Mosaic AI Model Serving endpoints over internal high-speed networks, caching repeated evaluations. Functions like `ai_classify` evaluate against an array of categories, `ai_extract` parses structured JSON from free-form text, and `ai_mask` redacts PII before data lands in reporting marts.

**Production Implementation:**
```sql
-- Production SQL ELT pipeline with in-database GenAI enrichment
WITH raw_feedback AS (
    SELECT 
        feedback_id,
        customer_id,
        feedback_text
    FROM prod_catalog.silver.raw_customer_feedback
    WHERE feedback_text IS NOT NULL AND length(trim(feedback_text)) > 10
)
SELECT 
    feedback_id,
    customer_id,
    -- Classify urgency category using zero-shot LLM inference
    ai_classify(feedback_text, ARRAY('critical_bug', 'billing_issue', 'feature_request', 'praise')) AS urgency_tier,
    -- Extract product SKU and price mentions as typed JSON
    ai_extract(feedback_text, ARRAY('sku_code', 'quoted_price', 'store_location')) AS parsed_attributes,
    -- Automatically redact credit card numbers and email addresses
    ai_mask(feedback_text, ARRAY('credit_card_number', 'email_address', 'phone_number')) AS sanitized_feedback,
    -- Generate 10-word executive summary for dashboard display
    ai_summarize(feedback_text, 10) AS executive_blurb
FROM raw_feedback;
```

**Key Invariants & Performance Traps:**
- Filter out empty or whitespace-only strings before invoking AI functions to save DBU cost.
- Wrap `ai_query` calls with `TRY_CAST` or `COALESCE` to prevent query aborts on payload timeouts.
- Set `temperature = 0.0` for deterministic classification tasks across repeatable pipeline runs.

---

### Q3.27: In-Database Vector Similarity Joins with vector_search() Table Functions (Mosaic AI SQL)

**Scenario & System Overview:**  
A global ecommerce catalog requires real-time semantic duplicate detection and product recommendation queries written in pure SQL without external vector database SDKs.

**Technical Deep-Dive & Architecture:**  
Databricks SQL exposes the `vector_search()` table function, allowing queries to perform Approximate Nearest Neighbor (ANN) vector similarity searches directly against Mosaic AI Vector Search indexes. The query engine passes query text or vector embeddings into the index and joins nearest-neighbor metadata back to dimension tables in a single unified distributed SQL query plan.

**Production Implementation:**
```sql
-- Semantic product search joining Vector Search index with catalog
SELECT 
    vs.search_score,
    p.product_id,
    p.product_name,
    p.category,
    p.unit_price
FROM vector_search(
    index => 'prod_catalog.ai_schema.product_catalog_vector_idx',
    query_text => 'wireless noise-canceling over-ear travel headphones with USB-C',
    num_results => 10
) AS vs
JOIN prod_catalog.gold.dim_products AS p
    ON vs.product_id = p.product_id
WHERE p.is_active = true AND p.unit_price < 350.00
ORDER BY vs.search_score DESC;
```

**Key Invariants & Performance Traps:**
- The underlying Vector Search index must be created and granted `CAN_USE` in Unity Catalog.
- Combining metadata filters inside `vector_search()` reduces latency vs post-filtering in `WHERE`.
- Scores range between 0.0 and 1.0 for cosine similarity metrics.

---

### Q3.28: AI/BI Genie Conversational Semantic Models & SQL Metric Governance (Mosaic AI SQL)

**Scenario & System Overview:**  
Non-technical business stakeholders require natural-language ad-hoc queries over enterprise revenue tables. How to structure Databricks AI/BI Genie spaces, define Unity Catalog semantic annotations, and verify SQL query generation accuracy.

**Technical Deep-Dive & Architecture:**  
Databricks AI/BI Genie leverages Mosaic AI to translate plain-English user prompts into validated Databricks SQL queries. Rather than querying raw schemas blindly, Genie uses Unity Catalog table comments, column descriptions, and primary/foreign key relationships as semantic context. Data teams provide curated SQL benchmark queries and metric formulas (`gross_margin = (revenue - cogs) / revenue`), ensuring Genie generates verified, certified SQL without hallucinations.

**Production Implementation:**
```sql
-- Semantic table annotations guiding AI/BI Genie conversational queries
COMMENT ON TABLE prod_catalog.gold.fact_financial_performance IS 
    'Certified financial performance mart. Grain: one row per customer invoice line item. Use for revenue, COGS, and gross margin calculations.';

ALTER TABLE prod_catalog.gold.fact_financial_performance ALTER COLUMN invoice_date 
    COMMENT 'Transaction timestamp in UTC. Used for fiscal year and monthly run-rate calculations.';

ALTER TABLE prod_catalog.gold.fact_financial_performance ALTER COLUMN net_revenue_usd 
    COMMENT 'Net billable revenue after deducting promo discounts and customer returns. Always sum this column for total revenue.';
```

**Key Invariants & Performance Traps:**
- Comprehensive column comments in Unity Catalog improve Genie SQL generation accuracy from $\sim 65\%$ to $> 95\%$.
- Specify certified SQL examples inside the Genie Space settings to guide complex join topologies.
- Enforce Unity Catalog row filters to prevent unauthorized users from viewing restricted rows via Genie prompts.
