-- ============================================================================
-- EXERCISE: 036_moving_averages_and_rolling_windows.sql
-- MODULE:   04_window_functions_mastery
-- LEVEL:    Intermediate
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   Telemetry anomaly detection requires computing a 3-day trailing moving
--   average of server CPU load to filter out transient micro-spikes.
-- PROBLEM STATEMENT:
--   Compute moving average using ROWS BETWEEN 2 PRECEDING AND CURRENT ROW.
-- ============================================================================

DROP TABLE IF EXISTS server_telemetry;
CREATE TABLE server_telemetry (
    day_id INT PRIMARY KEY,
    day_date TEXT,
    avg_cpu_pct DECIMAL(5, 2)
);

INSERT INTO server_telemetry VALUES
(1, '2024-06-01', 45.00),
(2, '2024-06-02', 55.00),
(3, '2024-06-03', 80.00),
(4, '2024-06-04', 60.00),
(5, '2024-06-05', 50.00);

-- --- [SOLUTION QUERY] ---
SELECT 
    day_id,
    day_date,
    avg_cpu_pct,
    ROUND(
        AVG(avg_cpu_pct) OVER (
            ORDER BY day_id ASC
            ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
        ), 2
    ) AS rolling_3day_avg_cpu
FROM server_telemetry
ORDER BY day_id ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 5
-- ASSERT: COL[rolling_3day_avg_cpu] = 45.0
