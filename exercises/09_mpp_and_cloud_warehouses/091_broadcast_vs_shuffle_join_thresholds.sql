-- ============================================================================
-- EXERCISE: 091_broadcast_vs_shuffle_join_thresholds.sql
-- MODULE:   09_mpp_and_cloud_warehouses
-- LEVEL:    🟡<br>Intermediate
-- ENGINES:  Databricks Spark SQL, Snowflake, BigQuery, PostgreSQL, DuckDB, SQLite
-- ROLE:     Senior Distributed Query Optimization Engineer
-- ----------------------------------------------------------------------------
-- ARCHITECTURAL CONTEXT & SYSTEM TOPOLOGY:
--   Distributed Query Planner & Physical Join Strategy Selection.
--   When joining a 500GB Fact Table to a lookup Dimension Table:
--   1. Broadcast Hash Join (BHJ / Map-Side Join):
--      If the dimension table is smaller than the broadcast threshold (e.g. 10MB in Spark,
--      configured via `spark.sql.autoBroadcastJoinThreshold`), the driver transmits a copy
--      of the dimension to every executor. Fact partitions are processed locally with ZERO
--      network shuffle!
--   2. Shuffle Hash Join (SHJ) / Sort-Merge Join (SMJ):
--      If the dimension exceeds the threshold, both tables must be hashed and shuffled
--      across all cluster nodes over the physical network.
--
-- BUSINESS CONTEXT:
--   Broadcasting small lookup tables slashes distributed query latencies from minutes
--   to seconds by completely eliminating the network shuffle stage.
--
-- PROBLEM STATEMENT:
--   Model a cost-based optimizer catalog with table statistics. Write a query that
--   inspects table size metadata against a 10MB (10,485,760 bytes) threshold and chooses
--   the optimal join execution strategy between BHJ and Shuffle Sort-Merge Join.
-- ============================================================================

DROP TABLE IF EXISTS query_planner_table_stats;

CREATE TABLE query_planner_table_stats (
    table_name VARCHAR(50) PRIMARY KEY,
    table_type VARCHAR(20) NOT NULL, -- FACT, DIMENSION
    row_count INT NOT NULL,
    total_bytes INT NOT NULL
);

INSERT INTO query_planner_table_stats VALUES
('fact_web_impressions', 'FACT',      50000000, 2147483648), -- 2 GB
('dim_ad_categories',    'DIMENSION',      500,     102400), -- 100 KB (< 10MB)
('dim_user_profiles',    'DIMENSION',  8000000,  524288000); -- 500 MB (> 10MB)

-- --- [SOLUTION QUERY] ---
-- Planner cost simulation: Determine physical join strategy for fact_web_impressions
SELECT 
    f.table_name AS fact_table,
    d.table_name AS dim_table,
    d.total_bytes AS dim_size_bytes,
    10485760 AS broadcast_threshold_bytes,
    CASE 
        WHEN d.total_bytes <= 10485760 THEN 'BROADCAST_HASH_JOIN'
        ELSE 'SHUFFLE_SORT_MERGE_JOIN'
    END AS selected_physical_join_strategy,
    CASE 
        WHEN d.total_bytes <= 10485760 THEN 'ZERO_NETWORK_SHUFFLE_OPTIMAL'
        ELSE 'NETWORK_SHUFFLE_EXCHANGE_REQUIRED'
    END AS execution_tradeoff
FROM query_planner_table_stats f
CROSS JOIN query_planner_table_stats d
WHERE f.table_type = 'FACT' AND d.table_type = 'DIMENSION'
ORDER BY d.total_bytes ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 2
-- ASSERT: COL[dim_table] = dim_ad_categories
-- ASSERT: COL[selected_physical_join_strategy] = BROADCAST_HASH_JOIN
-- ASSERT: COL[execution_tradeoff] = ZERO_NETWORK_SHUFFLE_OPTIMAL\n