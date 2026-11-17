-- ============================================================================
-- EXERCISE: 096_incident_the_99_percent_straggler_task_disaster.sql
-- MODULE:   10_production_incidents_and_triage
-- LEVEL:    🟣<br>Architect
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ROLE:     Principal Big Data Site Reliability Engineer & Spark Performance Architect
-- ----------------------------------------------------------------------------
-- ARCHITECTURAL CONTEXT & SYSTEM TOPOLOGY:
--   PRODUCTION INCIDENT POSTMORTEM: The 99% Complete Straggler Task Disaster.
--   At 03:15 UTC, the nightly distributed revenue roll-up pipeline stalled at 99%
--   completion (Stage 42, Task 199/200).
--   Worker nodes 1-199 finished in 45 seconds. Worker node 200 ran for 4.5 hours,
--   exhausting memory, triggering 28GB of disk shuffle spill, and blocking executive marts.
--
-- BUSINESS CONTEXT:
--   PRODUCTION INCIDENT ROOT CAUSE:
--   An upstream mobile app release introduced a bug where unauthenticated guest checkouts
--   emitted orders with `customer_id IS NULL`.
--   In the distributed join: `fact_orders JOIN dim_customers ON fact.customer_id = dim.customer_id`,
--   12 million NULL rows hashed to the EXACT SAME PARTITION HASH KEY!
--   All 12 million NULL rows were routed across the network to a single reducer node (Worker 200).
--
-- PROBLEM STATEMENT:
--   SURGICAL TRIAGE & REMEDIATION:
--   Two-Path Execution Architecture:
--   1. Filter valid non-null customer keys: Join them against customer dimension with zero skew.
--   2. Direct pass-through stream: Process NULL/Guest checkouts separately with default attributes,
--      bypassing the customer dimension join entirely.
--   3. UNION ALL the two streams. This eliminates join shuffle skew and restores parallel execution!
-- ============================================================================

DROP TABLE IF EXISTS incident_dim_customers;
DROP TABLE IF EXISTS incident_raw_transactions;

CREATE TABLE incident_raw_transactions (
    txn_id VARCHAR(32) PRIMARY KEY,
    customer_id VARCHAR(32), -- Contains skewed NULL values!
    amount_usd DECIMAL(12, 2) NOT NULL,
    txn_timestamp TEXT NOT NULL
);

CREATE TABLE incident_dim_customers (
    customer_id VARCHAR(32) PRIMARY KEY,
    customer_tier VARCHAR(20) NOT NULL,
    country_code VARCHAR(3) NOT NULL
);

INSERT INTO incident_raw_transactions VALUES
('TXN-101', 'CUST-881', 450.00, '2024-06-01 01:00:00'),
('TXN-102', 'CUST-882', 820.00, '2024-06-01 01:05:00'),
('TXN-103', NULL,        50.00, '2024-06-01 01:10:00'), -- Unassigned guest checkout hotspot
('TXN-104', NULL,        75.00, '2024-06-01 01:15:00'), -- Skewed NULL
('TXN-105', NULL,        90.00, '2024-06-01 01:20:00'); -- Skewed NULL

INSERT INTO incident_dim_customers VALUES
('CUST-881', 'ENTERPRISE', 'USA'),
('CUST-882', 'MID_MARKET', 'DEU');

-- --- [SOLUTION QUERY] ---
-- Production recovery: Two-Path execution eliminating NULL shuffle hotspot
WITH authenticated_orders AS (
    -- Path 1: Join only valid customer keys (no NULL skew)
    SELECT 
        t.txn_id,
        t.customer_id,
        c.customer_tier,
        c.country_code,
        t.amount_usd,
        'AUTHENTICATED_JOIN' AS processing_path
    FROM incident_raw_transactions t
    INNER JOIN incident_dim_customers c ON t.customer_id = c.customer_id
    WHERE t.customer_id IS NOT NULL
),
unassigned_guest_orders AS (
    -- Path 2: Direct bypass of dimension join for NULL keys
    SELECT 
        t.txn_id,
        'GUEST_USER' AS customer_id,
        'UNASSIGNED' AS customer_tier,
        'UNKNOWN'    AS country_code,
        t.amount_usd,
        'DIRECT_GUEST_BYPASS' AS processing_path
    FROM incident_raw_transactions t
    WHERE t.customer_id IS NULL
)
SELECT * FROM authenticated_orders
UNION ALL
SELECT * FROM unassigned_guest_orders
ORDER BY txn_id ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 5
-- ASSERT: COL[txn_id] = TXN-101
-- ASSERT: COL[customer_tier] = ENTERPRISE
-- ASSERT: COL[processing_path] = AUTHENTICATED_JOIN\n