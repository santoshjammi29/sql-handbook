-- ============================================================================
-- EXERCISE: 068_covering_indexes_and_index_only_scans.sql
-- MODULE:   07_indexing_and_query_optimization
-- LEVEL:    Advanced
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   High-frequency trading API: Point queries checking account balance must
--   execute in under 1 millisecond. If an index only contains account_id, the
--   engine must perform a secondary random disk lookup to the table heap page.
--   A Covering Index includes the balance column, eliminating table heap lookups!
-- PROBLEM STATEMENT:
--   Create a covering index and execute an Index-Only Scan.
-- ============================================================================

DROP TABLE IF EXISTS trading_accounts;
CREATE TABLE trading_accounts (
    account_id INT PRIMARY KEY,
    balance DECIMAL(12, 2),
    kyc_status VARCHAR(20),
    unneeded_metadata_blob TEXT
);

INSERT INTO trading_accounts VALUES
(1, 50000.00, 'VERIFIED', 'large binary metadata string...'),
(2, 12000.00, 'VERIFIED', 'large binary metadata string...');

CREATE INDEX idx_covering_balance ON trading_accounts (account_id, balance);

-- --- [SOLUTION QUERY] ---
-- Satisfied entirely from index leaves without touching table heap!
SELECT account_id, balance
FROM trading_accounts
WHERE account_id = 1;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 1
-- ASSERT: COL[balance] = 50000.00
