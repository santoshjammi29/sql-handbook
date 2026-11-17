-- ============================================================================
-- EXERCISE: 089_detecting_distribution_skew_in_parallel_shards.sql
-- MODULE:   09_mpp_and_cloud_warehouses
-- LEVEL:    Advanced
-- ENGINES:  Azure Synapse, Snowflake, Databricks, PostgreSQL, DuckDB, SQLite
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   In MPP clusters, if rows are not uniformly distributed, one worker processes
--   vastly more data than peers (Skew / Straggler node).
-- PROBLEM STATEMENT:
--   Write an administrative audit query to calculate row variance across worker shards.
-- ============================================================================

DROP TABLE IF EXISTS shard_stats;
CREATE TABLE shard_stats (
    shard_id INT PRIMARY KEY,
    row_count INT
);

INSERT INTO shard_stats VALUES
(1, 1000000),
(2, 980000),
(3, 1020000),
(4, 5500000); -- Severe Skew on Shard 4!

-- --- [SOLUTION QUERY] ---
SELECT 
    shard_id,
    row_count,
    ROUND(100.0 * row_count / (SELECT SUM(row_count) FROM shard_stats), 2) AS pct_of_total_rows,
    CASE 
        WHEN row_count > 2.0 * (SELECT AVG(row_count) FROM shard_stats) THEN 'CRITICAL_SKEW_STRAGGLER'
        ELSE 'BALANCED'
    END AS skew_status
FROM shard_stats
ORDER BY row_count DESC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 4
-- ASSERT: COL[skew_status] = CRITICAL_SKEW_STRAGGLER
