-- ============================================================================
-- EXERCISE: 086_snowflake_micropartition_pruning.sql
-- MODULE:   09_mpp_and_cloud_warehouses
-- LEVEL:    Advanced
-- ENGINES:  Snowflake, Databricks Spark SQL, BigQuery, PostgreSQL, DuckDB, SQLite
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   Cloud data warehouses (Snowflake, BigQuery) divide multi-terabyte tables
--   into immutable micro-partitions / row-groups. Metadata tracks min/max values
--   per column per micro-partition.
-- PROBLEM STATEMENT:
--   Simulate micro-partition metadata pruning: filter candidate partitions
--   using min/max bounds before scanning actual records.
-- ============================================================================

DROP TABLE IF EXISTS micropartition_metadata;
CREATE TABLE micropartition_metadata (
    partition_id INT PRIMARY KEY,
    min_event_date TEXT,
    max_event_date TEXT,
    row_count INT
);

INSERT INTO micropartition_metadata VALUES
(1, '2024-01-01', '2024-01-15', 500000),
(2, '2024-01-16', '2024-01-31', 650000),
(3, '2024-02-01', '2024-02-15', 450000);

-- --- [SOLUTION QUERY] ---
-- Query targeting '2024-01-20': Prunes partition 1 and 3 via metadata alone!
SELECT 
    partition_id,
    min_event_date,
    max_event_date,
    row_count AS rows_to_scan
FROM micropartition_metadata
WHERE '2024-01-20' BETWEEN min_event_date AND max_event_date;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 1
-- ASSERT: COL[partition_id] = 2
