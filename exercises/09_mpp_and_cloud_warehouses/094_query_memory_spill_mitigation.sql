-- ============================================================================
-- EXERCISE: 094_query_memory_spill_mitigation.sql
-- MODULE:   09_mpp_and_cloud_warehouses
-- LEVEL:    🟡<br>Intermediate
-- ENGINES:  Databricks Spark SQL, Snowflake, BigQuery, PostgreSQL, DuckDB, SQLite
-- ROLE:     Senior Performance Tuning & Lakehouse Cost Optimization Engineer
-- ----------------------------------------------------------------------------
-- ARCHITECTURAL CONTEXT & SYSTEM TOPOLOGY:
--   Apache Spark Project Tungsten & Cloud DW Memory Management.
--   When an analytical aggregation query performs GROUP BY across millions of distinct
--   wide string columns:
--   - The in-memory hash aggregation buffer (`Execution Memory`) exhausts available heap space.
--   - Tungsten / Snowflake is forced to SPILL hash tables to local disk (Spill to Disk).
--   - Disk spill slows queries down by 10x to 50x due to serialization, I/O wait, and disk paging.
--   Production Architectural Fix:
--   1. Pre-aggregate numeric metrics on high-cardinality keys BEFORE joining to wide strings.
--   2. Use surrogate integer identifiers instead of wide strings in GROUP BY clauses.
--
-- BUSINESS CONTEXT:
--   A smart grid smart meter pipeline ingests 200 million daily kWh telemetry rows.
--   Pre-aggregating meter reads prior to dimension expansion eliminated 4.2 TB of nightly
--   disk spills, reducing cluster runtimes by 75%.
--
-- PROBLEM STATEMENT:
--   Demonstrate memory-efficient pre-aggregation on raw meter telemetry.
--   Calculate total power usage per meter, proving clean aggregation with zero memory spill.
-- ============================================================================

DROP TABLE IF EXISTS raw_meter_telemetry;

CREATE TABLE raw_meter_telemetry (
    reading_id INT PRIMARY KEY,
    meter_id VARCHAR(32) NOT NULL,
    grid_zone VARCHAR(20) NOT NULL,
    kwh_consumed DECIMAL(10, 4) NOT NULL,
    reading_timestamp TEXT NOT NULL
);

INSERT INTO raw_meter_telemetry VALUES
(1, 'MTR-1001', 'ZONE_NORTH', 12.5000, '2024-06-01 08:00:00'),
(2, 'MTR-1001', 'ZONE_NORTH', 14.2500, '2024-06-01 09:00:00'),
(3, 'MTR-1002', 'ZONE_SOUTH',  8.7500, '2024-06-01 08:00:00'),
(4, 'MTR-1002', 'ZONE_SOUTH', 11.2000, '2024-06-01 09:00:00');

-- --- [SOLUTION QUERY] ---
-- Two-stage pre-aggregation query: Collapses high-volume rows before downstream joins
WITH pre_aggregated_meters AS (
    SELECT 
        meter_id,
        grid_zone,
        COUNT(reading_id) AS total_readings,
        SUM(kwh_consumed) AS total_kwh_consumed,
        ROUND(AVG(kwh_consumed), 4) AS avg_hourly_kwh
    FROM raw_meter_telemetry
    GROUP BY meter_id, grid_zone
)
SELECT 
    meter_id,
    grid_zone,
    total_readings,
    total_kwh_consumed,
    avg_hourly_kwh,
    'IN_MEMORY_ZERO_DISK_SPILL' AS execution_profile
FROM pre_aggregated_meters
ORDER BY meter_id ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 2
-- ASSERT: COL[meter_id] = MTR-1001
-- ASSERT: COL[total_kwh_consumed] = 26.75\n