-- ============================================================================
-- EXERCISE: 082_optimistic_concurrency_control_version_checks.sql
-- MODULE:   08_transactions_concurrency_and_locks
-- LEVEL:    Intermediate
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   Web e-commerce inventory: To avoid expensive long-lived database locks,
--   applications use Optimistic Concurrency Control (OCC). Each row has a
--   version number. Updates execute: UPDATE ... WHERE id = 1 AND version = current_version.
--   If 0 rows were updated, a concurrent update occurred and the app retries.
-- PROBLEM STATEMENT:
--   Execute a safe OCC update and verify version incrementation.
-- ============================================================================

DROP TABLE IF EXISTS occ_inventory;
CREATE TABLE occ_inventory (
    item_id INT PRIMARY KEY,
    stock_qty INT,
    lock_version INT
);

INSERT INTO occ_inventory VALUES (1, 100, 1);

-- Worker reads item_id = 1, lock_version = 1.
-- Worker executes CAS update:
UPDATE occ_inventory
SET stock_qty = stock_qty - 5,
    lock_version = lock_version + 1
WHERE item_id = 1 AND lock_version = 1;

-- --- [SOLUTION QUERY] ---
SELECT item_id, stock_qty, lock_version FROM occ_inventory WHERE item_id = 1;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 1
-- ASSERT: COL[stock_qty] = 95
-- ASSERT: COL[lock_version] = 2
