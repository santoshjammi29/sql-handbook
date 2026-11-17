-- ============================================================================
-- EXERCISE: 074_sargable_date_range_predicates.sql
-- MODULE:   07_indexing_and_query_optimization
-- LEVEL:    Intermediate
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   Auditing transactions created in May 2024:
--   Bad: WHERE STRFTIME('%m', created_at) = '05' (Non-SARGable full table scan)
--   Good: WHERE created_at >= '2024-05-01' AND created_at < '2024-06-01' (SARGable)
-- PROBLEM STATEMENT:
--   Implement the SARGable date range pattern.
-- ============================================================================

DROP TABLE IF EXISTS audit_entries;
CREATE TABLE audit_entries (
    entry_id INT PRIMARY KEY,
    created_at TEXT,
    event_type VARCHAR(50)
);

INSERT INTO audit_entries VALUES
(1, '2024-04-30 23:59:59', 'CLOSE'),
(2, '2024-05-01 00:00:00', 'OPEN'),
(3, '2024-05-15 12:00:00', 'TXN'),
(4, '2024-05-31 23:59:59', 'CLOSE'),
(5, '2024-06-01 00:00:00', 'OPEN');

-- --- [SOLUTION QUERY] ---
SELECT entry_id, created_at, event_type
FROM audit_entries
WHERE created_at >= '2024-05-01 00:00:00'
  AND created_at < '2024-06-01 00:00:00'
ORDER BY created_at ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 3
-- ASSERT: COL[entry_id] = 2
