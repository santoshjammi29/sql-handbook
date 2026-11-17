-- ============================================================================
-- EXERCISE: 048_ctes_vs_temp_tables_vs_subqueries.sql
-- MODULE:   05_subqueries_and_recursive_ctes
-- LEVEL:    🟡<br>Intermediate
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ROLE:     Lead Data Architect & Warehouse Optimization Specialist
-- ----------------------------------------------------------------------------
-- ARCHITECTURAL CONTEXT & SYSTEM TOPOLOGY:
--   Multi-Stage ETL Data Pipeline Architecture.
--   Evaluating structural paradigms: Common Table Expressions (CTEs), Subqueries, and Temp Tables.
--   - CTEs: High readability, declarative syntax, optimized inline by modern CBOs.
--   - Subqueries: High verbosity, difficult to read beyond 2 nested levels.
--   - Temp Tables: Physically written to TempDB/RAM, allows manual secondary indexing.
--
-- BUSINESS CONTEXT:
--   Enterprise analytical engine optimization for 048 ctes vs temp tables vs subqueries.
--   Ensuring strict grain integrity, distributed performance, and deterministic results.
--
-- PROBLEM STATEMENT:
--   Write a production-grade SQL query fulfilling the architectural requirements for 048 ctes vs temp tables vs subqueries.
-- ============================================================================

DROP TABLE IF EXISTS raw_meter_telemetry;

CREATE TABLE raw_meter_telemetry (
    meter_id VARCHAR(20) NOT NULL,
    kwh_consumed DECIMAL(10, 2) NOT NULL,
    reading_timestamp TEXT NOT NULL
);

INSERT INTO raw_meter_telemetry VALUES
('MTR-01', 120.50, '2024-05-01 08:00:00'),
('MTR-01', 145.00, '2024-05-01 12:00:00'),
('MTR-02',  80.00, '2024-05-01 08:00:00'),
('MTR-02',  95.50, '2024-05-01 12:00:00');

-- --- [SOLUTION QUERY] ---
-- Clean modular multi-stage CTE pipeline
WITH stg_daily_consumption AS (
    SELECT 
        meter_id,
        SUM(kwh_consumed) AS total_kwh,
        AVG(kwh_consumed) AS avg_reading_kwh
    FROM raw_meter_telemetry
    GROUP BY meter_id
),
meter_tiered_billing AS (
    SELECT 
        meter_id,
        total_kwh,
        avg_reading_kwh,
        ROUND(total_kwh * 0.15, 2) AS estimated_cost_usd
    FROM stg_daily_consumption
)
SELECT 
    meter_id,
    total_kwh,
    avg_reading_kwh,
    estimated_cost_usd,
    CASE 
        WHEN total_kwh > 200 THEN 'HIGH_CONSUMPTION_INDUSTRIAL'
        ELSE 'STANDARD_COMMERCIAL'
    END AS tariff_tier
FROM meter_tiered_billing
ORDER BY total_kwh DESC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 2
-- ASSERT: COL[meter_id] = MTR-01
