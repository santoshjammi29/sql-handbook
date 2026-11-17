-- ============================================================================
-- EXERCISE: 078_non_repeatable_read_anomaly.sql
-- MODULE:   08_transactions_concurrency_and_locks
-- LEVEL:    Advanced
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   Non-Repeatable Read (Fuzzy Read): Under READ COMMITTED, Transaction 1 reads
--   a row ($100). Concurrently, Transaction 2 updates the row to $150 and commits.
--   Transaction 1 re-reads the row and sees $150. REPEATABLE READ snapshot isolation
--   prevents this by freezing visible versions at transaction start.
-- PROBLEM STATEMENT:
--   Demonstrate consistent state reads within a transaction.
-- ============================================================================

DROP TABLE IF EXISTS product_inventory;
CREATE TABLE product_inventory (
    product_id INT PRIMARY KEY,
    stock INT
);

INSERT INTO product_inventory VALUES (1, 50);

BEGIN TRANSACTION;
SELECT stock FROM product_inventory WHERE product_id = 1;
COMMIT;

-- --- [SOLUTION QUERY] ---
SELECT product_id, stock FROM product_inventory WHERE product_id = 1;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 1
-- ASSERT: COL[stock] = 50
