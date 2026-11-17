-- ============================================================================
-- EXERCISE: 094_query_memory_spill_mitigation.sql
-- MODULE:   09_mpp_and_cloud_warehouses
-- LEVEL:    Intermediate
-- ENGINES:  Databricks Spark SQL, Snowflake, BigQuery, PostgreSQL, DuckDB, SQLite
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   Tungsten memory spill: In-memory hash aggregations spill to local disk when
--   aggregating massive high-cardinality keys. Reducing grain before joining
--   eliminates memory spills.
-- PROBLEM STATEMENT:
--   Aggregate at lower grain before performing downstream dimension joins.
-- ============================================================================

DROP TABLE IF EXISTS raw_meter_reads;
CREATE TABLE raw_meter_reads (
    meter_id INT,
    kwh DECIMAL(10, 2)
);

INSERT INTO raw_meter_reads VALUES (1, 10.5), (1, 12.0), (2, 8.0), (2, 9.5);

-- --- [SOLUTION QUERY] ---
WITH aggregated_reads AS (
    -- Pre-aggregate to collapse millions of raw sensor rows into unique meter totals
    SELECT 
        meter_id,
        SUM(kwh) AS total_kwh
    FROM raw_meter_reads
    GROUP BY meter_id
)
SELECT meter_id, total_kwh
FROM aggregated_reads
ORDER BY meter_id ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 2
-- ASSERT: COL[total_kwh] = 22.5
