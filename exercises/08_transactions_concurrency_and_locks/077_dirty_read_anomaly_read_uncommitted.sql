-- ============================================================================
-- EXERCISE: 077_dirty_read_anomaly_read_uncommitted.sql
-- MODULE:   08_transactions_concurrency_and_locks
-- LEVEL:    Advanced
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   Dirty Read anomaly occurs under READ UNCOMMITTED: Transaction 1 mutates a row.
--   Transaction 2 reads the uncommitted mutation. Transaction 1 then rolls back.
--   Transaction 2 has acted on phantom data that never committed!
-- PROBLEM STATEMENT:
--   Demonstrate transactional isolation preventing dirty reads.
-- ============================================================================

DROP TABLE IF EXISTS account_balance;
CREATE TABLE account_balance (
    account_id INT PRIMARY KEY,
    balance DECIMAL(10, 2)
);

INSERT INTO account_balance VALUES (1, 1000.00);

BEGIN TRANSACTION;
UPDATE account_balance SET balance = 5000.00 WHERE account_id = 1;
-- Transaction aborts
ROLLBACK;

-- --- [SOLUTION QUERY] ---
-- Validates balance reverted to committed state
SELECT account_id, balance FROM account_balance WHERE account_id = 1;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 1
-- ASSERT: COL[balance] = 1000.00
