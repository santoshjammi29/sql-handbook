-- ============================================================================
-- EXERCISE: 054_materialized_vs_inlined_ctes.sql
-- MODULE:   05_subqueries_and_recursive_ctes
-- LEVEL:    Advanced
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   Query optimizer fences: In PostgreSQL and SQLite, an un-materialized CTE is
--   inlined into the main query, allowing predicate pushdown. A MATERIALIZED CTE
--   forces evaluation into a temporary buffer, acting as an optimization fence.
-- PROBLEM STATEMENT:
--   Demonstrate filtering inside CTE versus filtering downstream.
-- ============================================================================

DROP TABLE IF EXISTS raw_logs;
CREATE TABLE raw_logs (
    log_id INT PRIMARY KEY,
    severity VARCHAR(10),
    message TEXT
);

INSERT INTO raw_logs VALUES
(1, 'INFO',  'System started'),
(2, 'ERROR', 'Disk full'),
(3, 'WARN',  'High memory'),
(4, 'ERROR', 'Connection timeout');

-- --- [SOLUTION QUERY] ---
WITH error_logs AS (
    SELECT log_id, severity, message
    FROM raw_logs
    WHERE severity = 'ERROR'
)
SELECT 
    log_id,
    message
FROM error_logs
WHERE log_id > 1
ORDER BY log_id ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 2
-- ASSERT: COL[message] = Disk full
