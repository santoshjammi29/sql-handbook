-- ============================================================================
-- EXERCISE: 083_deadlock_reproduction_and_inverse_locking.sql
-- MODULE:   08_transactions_concurrency_and_locks
-- LEVEL:    Advanced
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   Deadlock (Error 1205): Transaction 1 locks Account A then requests Account B.
--   Transaction 2 locks Account B then requests Account A.
--   The permanent architectural fix is Canonical Resource Ordering: Always lock
--   the smaller account ID first, regardless of transfer direction!
-- PROBLEM STATEMENT:
--   Demonstrate canonical ordering logic to guarantee deadlock-free execution.
-- ============================================================================

DROP TABLE IF EXISTS bank_accounts;
CREATE TABLE bank_accounts (
    account_id INT PRIMARY KEY,
    balance DECIMAL(10, 2)
);

INSERT INTO bank_accounts VALUES (10, 500.00), (20, 800.00);

-- Canonical transfer logic: from Account 20 to Account 10
-- Order IDs: min(10, 20) = 10 first, max(10, 20) = 20 second!
BEGIN TRANSACTION;
UPDATE bank_accounts SET balance = balance + 100.00 WHERE account_id = 10; -- Min ID
UPDATE bank_accounts SET balance = balance - 100.00 WHERE account_id = 20; -- Max ID
COMMIT;

-- --- [SOLUTION QUERY] ---
SELECT account_id, balance FROM bank_accounts ORDER BY account_id ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 2
-- ASSERT: COL[balance] = 600.00
