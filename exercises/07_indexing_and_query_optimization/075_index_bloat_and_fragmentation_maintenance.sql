-- ============================================================================
-- EXERCISE: 075_index_bloat_and_fragmentation_maintenance.sql
-- MODULE:   07_indexing_and_query_optimization
-- LEVEL:    Advanced
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   High-frequency random inserts and deletes cause B-Tree page splits and
--   table bloat. In production PostgreSQL/SQLite, periodic VACUUM or REINDEX
--   reclaims dead storage space and defragments index leaf pages.
-- PROBLEM STATEMENT:
--   Simulate table mutations and demonstrate index maintenance.
-- ============================================================================

DROP TABLE IF EXISTS volatile_table;
CREATE TABLE volatile_table (
    id INT PRIMARY KEY,
    payload VARCHAR(255)
);

INSERT INTO volatile_table VALUES (1, 'initial data 1'), (2, 'initial data 2');
DELETE FROM volatile_table WHERE id = 1;
INSERT INTO volatile_table VALUES (3, 'new data 3');

-- --- [SOLUTION QUERY] ---
SELECT id, payload FROM volatile_table ORDER BY id ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 2
-- ASSERT: COL[id] = 2
