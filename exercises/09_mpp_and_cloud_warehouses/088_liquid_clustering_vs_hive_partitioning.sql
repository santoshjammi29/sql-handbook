-- ============================================================================
-- EXERCISE: 088_liquid_clustering_vs_hive_partitioning.sql
-- MODULE:   09_mpp_and_cloud_warehouses
-- LEVEL:    Advanced
-- ENGINES:  Databricks Spark SQL, Snowflake, BigQuery, PostgreSQL, DuckDB, SQLite
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   Legacy Hive physical directory partitioning (/year=2024/month=05/) creates
--   the small file problem. Modern Lakehouses use Liquid Clustering (CLUSTER BY)
--   to cluster data across multiple dimensions (region, customer_id) in flat files.
-- PROBLEM STATEMENT:
--   Demonstrate multidimensional clustering and query filtering.
-- ============================================================================

DROP TABLE IF EXISTS clustered_events;
CREATE TABLE clustered_events (
    event_id INT PRIMARY KEY,
    region VARCHAR(10),
    event_date TEXT,
    user_id INT
);

INSERT INTO clustered_events VALUES
(1, 'US', '2024-05-01', 101),
(2, 'US', '2024-05-01', 102),
(3, 'EU', '2024-05-01', 201),
(4, 'US', '2024-05-02', 101);

-- --- [SOLUTION QUERY] ---
SELECT region, event_date, COUNT(*) AS event_count
FROM clustered_events
WHERE region = 'US' AND event_date = '2024-05-01'
GROUP BY region, event_date;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 1
-- ASSERT: COL[event_count] = 2
