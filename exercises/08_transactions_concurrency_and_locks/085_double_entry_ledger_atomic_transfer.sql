-- ============================================================================
-- EXERCISE: 085_double_entry_ledger_atomic_transfer.sql
-- MODULE:   08_transactions_concurrency_and_locks
-- LEVEL:    Advanced
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   Fintech Double-Entry Bookkeeping Invariant: Every financial transaction
--   must have matching debit and credit entries. The sum of all entries across
--   the entire ledger must mathematically equal 0.
-- PROBLEM STATEMENT:
--   Execute an atomic double-entry transfer and verify the zero-balance invariant.
-- ============================================================================

DROP TABLE IF EXISTS journal_entries;
CREATE TABLE journal_entries (
    entry_id INT PRIMARY KEY,
    txn_id VARCHAR(50),
    account_name VARCHAR(50),
    amount DECIMAL(10, 2) -- Positive = Debit, Negative = Credit
);

BEGIN TRANSACTION;
-- $250 transfer from Cash to Accounts Payable
INSERT INTO journal_entries VALUES 
(1, 'TXN_901', 'Cash', -250.00),
(2, 'TXN_901', 'Accounts Payable', 250.00);
COMMIT;

-- --- [SOLUTION QUERY] ---
SELECT 
    txn_id,
    SUM(amount) AS net_ledger_balance,
    COUNT(*)    AS total_journal_legs
FROM journal_entries
GROUP BY txn_id
HAVING SUM(amount) = 0.00; -- Invariant holds!

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 1
-- ASSERT: COL[net_ledger_balance] = 0.0
