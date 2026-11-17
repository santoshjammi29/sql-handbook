-- ============================================================================
-- EXERCISE: 103_incident_unindexed_foreign_key_table_lock_cascade.sql
-- MODULE:   10_production_incidents_and_triage
-- LEVEL:    Advanced
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   PRODUCTION INCIDENT POSTMORTEM: Unindexed Foreign Key Table-Lock Cascade.
--   Deleting an inactive customer locked the entire 20M row order_history table
--   for 45 seconds, rejecting all user checkouts.
--   Root cause: Missing index on order_history.customer_id forced a share lock table scan.
-- PROBLEM STATEMENT:
--   Triage and execute production recovery.
-- SURGICAL REMEDIATION:
--   Always index all Foreign Key columns in child tables.
-- ============================================================================

DROP TABLE IF EXISTS child_order_history;
DROP TABLE IF EXISTS parent_customer_registry;

CREATE TABLE parent_customer_registry (
    customer_id INT PRIMARY KEY,
    name VARCHAR(50)
);

CREATE TABLE child_order_history (
    history_id INT PRIMARY KEY,
    customer_id INT,
    amount DECIMAL(10, 2),
    FOREIGN KEY (customer_id) REFERENCES parent_customer_registry(customer_id)
);

CREATE INDEX idx_fk_customer_id ON child_order_history (customer_id);

INSERT INTO parent_customer_registry VALUES (1, 'Alice');
INSERT INTO child_order_history VALUES (101, 1, 50.00);

-- --- [SOLUTION QUERY] ---
SELECT 
    p.customer_id,
    p.name,
    COUNT(c.history_id) AS total_orders
FROM parent_customer_registry p
LEFT JOIN child_order_history c ON p.customer_id = c.customer_id
WHERE p.customer_id = 1
GROUP BY p.customer_id, p.name;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 1
-- ASSERT: COL[total_orders] = 1
