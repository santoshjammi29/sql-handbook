-- ============================================================================
-- EXERCISE: 089_detecting_distribution_skew_in_parallel_shards.sql
-- MODULE:   09_mpp_and_cloud_warehouses
-- LEVEL:    🔴<br>Advanced
-- ENGINES:  Azure Synapse, Snowflake, Databricks, PostgreSQL, DuckDB, SQLite
-- ROLE:     Staff Cloud Performance Engineer & MPP Systems Administrator
-- ----------------------------------------------------------------------------
-- ARCHITECTURAL CONTEXT & SYSTEM TOPOLOGY:
--   Distributed Data Shard Telemetry & Straggler Task Diagnostics.
--   In Massively Parallel Processing (MPP) clusters and distributed engines (Spark, Synapse, Trino):
--   - Compute tasks run in parallel across worker shards / partitions.
--   - When a distribution key exhibits severe data skew (e.g., millions of events assigned
--     to customer_id = 0 or NULL), one worker node receives 50%+ of all records.
--   - That single worker becomes the "Straggler Node". While other nodes finish in 30 seconds,
--     the entire cluster stays blocked at 99% waiting for the straggler to complete.
--
-- BUSINESS CONTEXT:
--   Unmonitored shard skew causes unexpected cloud autoscaling spikes, query timeouts,
--   and breached SLAs in client-facing real-time dashboards.
--
-- PROBLEM STATEMENT:
--   Write an enterprise DBA audit query that calculates the distribution of rows across
--   distributed worker shards. Compute the mean shard row count, calculate the percentage
--   variance from the mean, and flag any shard operating above 150% of the cluster average
--   as a CRITICAL_STRAGGLER_HAZARD.
-- ============================================================================

DROP TABLE IF EXISTS mpp_shard_telemetry;

CREATE TABLE mpp_shard_telemetry (
    shard_id INT PRIMARY KEY,
    worker_host VARCHAR(50) NOT NULL,
    row_count INT NOT NULL,
    storage_bytes INT NOT NULL
);

INSERT INTO mpp_shard_telemetry VALUES
(1, 'worker-node-01.ec2.internal',  1200000,  62914560),
(2, 'worker-node-02.ec2.internal',  1150000,  60293120),
(3, 'worker-node-03.ec2.internal',  1180000,  61865984),
(4, 'worker-node-04.ec2.internal',  5800000, 304087040); -- Severe Skew Hotspot on Node 4!

-- --- [SOLUTION QUERY] ---
-- Diagnostic query identifying straggler nodes via statistical variance
WITH cluster_metrics AS (
    SELECT 
        AVG(row_count) AS avg_shard_rows,
        SUM(row_count) AS total_cluster_rows
    FROM mpp_shard_telemetry
)
SELECT 
    s.shard_id,
    s.worker_host,
    s.row_count,
    ROUND(100.0 * s.row_count / c.total_cluster_rows, 2) AS pct_of_total_cluster_rows,
    ROUND(1.0 * s.row_count / c.avg_shard_rows, 2) AS skew_multiplier_vs_mean,
    CASE 
        WHEN s.row_count > 1.5 * c.avg_shard_rows THEN 'CRITICAL_STRAGGLER_HAZARD'
        ELSE 'BALANCED_DISTRIBUTION'
    END AS shard_health_status
FROM mpp_shard_telemetry s
CROSS JOIN cluster_metrics c
ORDER BY s.row_count DESC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 4
-- ASSERT: COL[shard_id] = 4
-- ASSERT: COL[skew_multiplier_vs_mean] = 2.49
-- ASSERT: COL[shard_health_status] = CRITICAL_STRAGGLER_HAZARD\n