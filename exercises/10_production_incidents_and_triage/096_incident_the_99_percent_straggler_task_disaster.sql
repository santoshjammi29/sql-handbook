-- ============================================================================
-- EXERCISE: 096_incident_the_99_percent_straggler_task_disaster.sql
-- MODULE:   10_production_incidents_and_triage
-- LEVEL:    Advanced
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   PRODUCTION INCIDENT POSTMORTEM: The 99% Complete Straggler Task Disaster.
--   A nightly Spark/MPP pipeline joining 50M transactions stalled for 4 hours
--   at task 199/200. Root cause: 15 million transactions had customer_id IS NULL.
--   All NULLs hashed to the identical worker node!
-- PROBLEM STATEMENT:
--   Triage and execute production recovery.
-- SURGICAL REMEDIATION:
--   Filter out NULL customer keys before hash join, or isolate NULL processing.
-- ============================================================================

DROP TABLE IF EXISTS incident_txns;
DROP TABLE IF EXISTS incident_customers;

CREATE TABLE incident_txns (txn_id INT PRIMARY KEY, cust_id INT, amount DECIMAL(10, 2));
CREATE TABLE incident_customers (cust_id INT PRIMARY KEY, cust_name VARCHAR(50));

INSERT INTO incident_txns VALUES
(1, 10, 100.00), (2, 20, 200.00),
(3, NULL, 50.00), (4, NULL, 75.00), (5, NULL, 90.00); -- Skewed NULLs!

INSERT INTO incident_customers VALUES (10, 'Enterprise Customer A'), (20, 'Enterprise Customer B');

-- --- [SOLUTION QUERY] ---
-- Production fix: Process known valid keys with hash join, union unassigned NULLs directly
SELECT 
    t.txn_id,
    c.cust_name,
    t.amount
FROM incident_txns t
JOIN incident_customers c ON t.cust_id = c.cust_id
WHERE t.cust_id IS NOT NULL

UNION ALL

SELECT 
    t.txn_id,
    'UNASSIGNED_GUEST' AS cust_name,
    t.amount
FROM incident_txns t
WHERE t.cust_id IS NULL
ORDER BY txn_id ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 5
-- ASSERT: COL[cust_name] = Enterprise Customer A
