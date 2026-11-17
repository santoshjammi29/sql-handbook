-- ============================================================================
-- EXERCISE: 093_delta_merge_into_multi_condition_matching.sql
-- MODULE:   09_mpp_and_cloud_warehouses
-- LEVEL:    🔴<br>Advanced
-- ENGINES:  Databricks Spark SQL, Snowflake, BigQuery, PostgreSQL, DuckDB, SQLite
-- ROLE:     Lead Data Lakehouse Architect & CDC Pipeline Specialist
-- ----------------------------------------------------------------------------
-- ARCHITECTURAL CONTEXT & SYSTEM TOPOLOGY:
--   Modern Lakehouse ACID Ingestion & ANSI SQL MERGE INTO Mechanics.
--   In Databricks Delta Lake, Apache Iceberg, and Snowflake:
--   Change Data Capture (CDC) feeds from upstream databases emit changes with operation flags:
--   - op_type = 'I' (Insert)
--   - op_type = 'U' (Update)
--   - op_type = 'D' (Delete / Soft Delete)
--   A single multi-condition MERGE statement executes:
--   1. WHEN MATCHED AND source.op_type = 'D' THEN DELETE
--   2. WHEN MATCHED AND source.op_type = 'U' THEN UPDATE SET target.col = source.col, ...
--   3. WHEN NOT MATCHED AND source.op_type != 'D' THEN INSERT (...)
--
-- BUSINESS CONTEXT:
--   Processing CDC events via multiple discrete UPDATE/DELETE passes causes race conditions,
--   partial commits, and massive write amplification. A single atomic MERGE ensures complete
--   data consistency and ACID compliance in the Lakehouse Silver layer.
--
-- PROBLEM STATEMENT:
--   Simulate an atomic multi-condition MERGE upsert pipeline in SQL.
--   Given target customer dimension and incoming CDC batch:
--   - Delete customer CUST-102 (marked 'D')
--   - Update customer CUST-101 with new tier (marked 'U')
--   - Insert new customer CUST-103 (marked 'I')
--   Verify final reconciled state.
-- ============================================================================

DROP TABLE IF EXISTS cdc_silver_customers;
DROP TABLE IF EXISTS cdc_bronze_incoming;

CREATE TABLE cdc_silver_customers (
    customer_id VARCHAR(32) PRIMARY KEY,
    customer_tier VARCHAR(20) NOT NULL,
    lifetime_value_usd DECIMAL(12, 2) NOT NULL,
    last_updated_at TEXT NOT NULL
);

CREATE TABLE cdc_bronze_incoming (
    customer_id VARCHAR(32) PRIMARY KEY,
    op_type VARCHAR(5) NOT NULL, -- I, U, D
    customer_tier VARCHAR(20),
    lifetime_value_usd DECIMAL(12, 2),
    cdc_timestamp TEXT NOT NULL
);

INSERT INTO cdc_silver_customers VALUES
('CUST-101', 'SILVER',  1500.00, '2024-05-01 10:00:00'),
('CUST-102', 'BRONZE',   350.00, '2024-05-01 10:00:00');

-- Incoming CDC batch containing Update, Delete, and Insert
INSERT INTO cdc_bronze_incoming VALUES
('CUST-101', 'U', 'GOLD',     2200.00, '2024-06-01 12:00:00'), -- Update
('CUST-102', 'D', NULL,          0.00, '2024-06-01 12:00:00'), -- Delete
('CUST-103', 'I', 'PLATINUM', 5000.00, '2024-06-01 12:00:00'); -- Insert

-- Emulate atomic MERGE:
-- Stage 1: Execute DELETE for op_type = 'D'
DELETE FROM cdc_silver_customers 
WHERE customer_id IN (SELECT customer_id FROM cdc_bronze_incoming WHERE op_type = 'D');

-- Stage 2: Execute INSERT / UPDATE (UPSERT)
INSERT INTO cdc_silver_customers (customer_id, customer_tier, lifetime_value_usd, last_updated_at)
SELECT customer_id, customer_tier, lifetime_value_usd, cdc_timestamp
FROM cdc_bronze_incoming
WHERE op_type IN ('I', 'U')
ON CONFLICT(customer_id) DO UPDATE SET
    customer_tier = EXCLUDED.customer_tier,
    lifetime_value_usd = EXCLUDED.lifetime_value_usd,
    last_updated_at = EXCLUDED.last_updated_at;

-- --- [SOLUTION QUERY] ---
-- Query verifying reconciled silver customer dimension post-MERGE
SELECT 
    customer_id,
    customer_tier,
    lifetime_value_usd,
    last_updated_at,
    'ACID_MERGE_RECONCILED' AS sync_status
FROM cdc_silver_customers
ORDER BY customer_id ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 2
-- ASSERT: COL[customer_id] = CUST-101
-- ASSERT: COL[customer_tier] = GOLD
-- ASSERT: COL[lifetime_value_usd] = 2200.0\n