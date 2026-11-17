-- ============================================================================
-- EXERCISE: 079_phantom_read_anomaly_range_locks.sql
-- MODULE:   08_transactions_concurrency_and_locks
-- LEVEL:    Advanced
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   Phantom Read anomaly: Transaction 1 queries COUNT(*) WHERE status = 'PENDING'
--   (returns 2). Transaction 2 inserts a brand-new pending row and commits.
--   Transaction 1 re-runs the count and receives 3.
-- PROBLEM STATEMENT:
--   Demonstrate predicate range counting and row insertion effects.
-- ============================================================================

DROP TABLE IF EXISTS approval_queue;
CREATE TABLE approval_queue (
    queue_id INT PRIMARY KEY,
    status VARCHAR(20)
);

INSERT INTO approval_queue VALUES (1, 'PENDING'), (2, 'PENDING');

-- --- [SOLUTION QUERY] ---
SELECT COUNT(*) AS pending_count
FROM approval_queue
WHERE status = 'PENDING';

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 1
-- ASSERT: COL[pending_count] = 2
