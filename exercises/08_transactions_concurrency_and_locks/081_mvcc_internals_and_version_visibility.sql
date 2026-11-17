-- ============================================================================
-- EXERCISE: 081_mvcc_internals_and_version_visibility.sql
-- MODULE:   08_transactions_concurrency_and_locks
-- LEVEL:    Advanced
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   MVCC Internals: In Multi-Version Concurrency Control, row updates do not
--   overwrite disk blocks. Instead, they insert a new row version with xmin/xmax
--   metadata timestamps. Readers read the version visible to their snapshot.
-- PROBLEM STATEMENT:
--   Simulate an MVCC versioning ledger with visible_from and visible_to timestamps.
-- ============================================================================

DROP TABLE IF EXISTS mvcc_simulation;
CREATE TABLE mvcc_simulation (
    row_id INT,
    version INT,
    balance DECIMAL(10, 2),
    created_tx INT,
    expired_tx INT -- 0 = Active
);

INSERT INTO mvcc_simulation VALUES
(1, 1, 100.00, 100, 105), -- Expired at tx 105
(1, 2, 150.00, 105, 0);   -- Active version

-- --- [SOLUTION QUERY] ---
-- Query as of Transaction 102 (Snapshot isolation in the past)
SELECT row_id, balance, version
FROM mvcc_simulation
WHERE created_tx <= 102 AND (expired_tx > 102 OR expired_tx = 0);

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 1
-- ASSERT: COL[balance] = 100.00
