-- ============================================================================
-- EXERCISE: 040_gaps_and_islands_overlapping_interval_merging.sql
-- MODULE:   04_window_functions_mastery
-- LEVEL:    🔴<br>Advanced
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ROLE:     Lead Cloud FinOps Architect & Infrastructure Systems Engineer
-- ----------------------------------------------------------------------------
-- ARCHITECTURAL CONTEXT & SYSTEM TOPOLOGY:
--   Multi-Node Virtual Machine Active Uptime Consolidation.
--   When server instances are leased or containers are scaled, usage intervals
--   frequently overlap (e.g. Server A ran 10:00-12:00, Server B ran 11:00-13:00).
--   Cloud FinOps billing models must merge overlapping intervals into contiguous
--   non-overlapping blocks to calculate exact non-duplicate active hours.
--
-- BUSINESS CONTEXT:
--   Enterprise analytical engine optimization for 040 gaps and islands overlapping interval merging.
--   Ensuring strict grain integrity, distributed performance, and deterministic results.
--
-- PROBLEM STATEMENT:
--   Write a production-grade SQL query fulfilling the architectural requirements for 040 gaps and islands overlapping interval merging.
-- ============================================================================

DROP TABLE IF EXISTS container_lease_intervals;

CREATE TABLE container_lease_intervals (
    cluster_id VARCHAR(20) NOT NULL,
    start_time TEXT NOT NULL,
    end_time TEXT NOT NULL
);

INSERT INTO container_lease_intervals VALUES
-- Overlapping block 1: [08:00, 10:00] and [09:00, 11:30] -> Merged: [08:00, 11:30]
('CL-01', '2024-05-01 08:00:00', '2024-05-01 10:00:00'),
('CL-01', '2024-05-01 09:00:00', '2024-05-01 11:30:00'),
-- Disjoint block 2: [14:00, 16:00]
('CL-01', '2024-05-01 14:00:00', '2024-05-01 16:00:00');

-- --- [SOLUTION QUERY] ---
-- Merging overlapping intervals:
-- 1. Identify previous max end_time using window MAX()
-- 2. Detect boundary break when current start_time > prev max end_time
WITH max_previous_interval AS (
    SELECT 
        cluster_id,
        start_time,
        end_time,
        MAX(end_time) OVER (
            PARTITION BY cluster_id 
            ORDER BY start_time ASC 
            ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
        ) AS max_prev_end_time
    FROM container_lease_intervals
),
interval_groups AS (
    SELECT 
        cluster_id,
        start_time,
        end_time,
        -- New group starts if current start is past previous max end
        CASE 
            WHEN max_prev_end_time IS NULL OR start_time > max_prev_end_time THEN 1 
            ELSE 0 
        END AS is_new_block_flag
    FROM max_previous_interval
),
clustered_blocks AS (
    SELECT 
        cluster_id,
        start_time,
        end_time,
        SUM(is_new_block_flag) OVER (
            PARTITION BY cluster_id 
            ORDER BY start_time ASC
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS block_id
    FROM interval_groups
)
SELECT 
    cluster_id,
    block_id,
    MIN(start_time) AS merged_active_start,
    MAX(end_time)   AS merged_active_end,
    ROUND((JULIANDAY(MAX(end_time)) - JULIANDAY(MIN(start_time))) * 24.0, 2) AS billable_duration_hours
FROM clustered_blocks
GROUP BY cluster_id, block_id
ORDER BY merged_active_start ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 2
-- ASSERT: COL[cluster_id] = CL-01
