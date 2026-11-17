-- ============================================================================
-- EXERCISE: 075_index_bloat_and_fragmentation_maintenance.sql
-- MODULE:   07_indexing_and_query_optimization
-- LEVEL:    🔴<br>Advanced
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ROLE:     Lead Database SRE & Storage Systems Specialist
-- ----------------------------------------------------------------------------
-- ARCHITECTURAL CONTEXT & SYSTEM TOPOLOGY:
--   B-Tree Index Page Fragmentation & Bloat Maintenance.
--   Heavy random UPDATE and DELETE workloads create hollow leaf pages (page splits).
--   Measuring table page fill factors and executing maintenance reindexing.
--
-- BUSINESS CONTEXT:
--   Enterprise analytical engine optimization for 075 index bloat and fragmentation maintenance.
--   Ensuring strict grain integrity, distributed performance, and deterministic results.
--
-- PROBLEM STATEMENT:
--   Write a production-grade SQL query fulfilling the architectural requirements for 075 index bloat and fragmentation maintenance.
-- ============================================================================

DROP TABLE IF EXISTS write_heavy_telemetry;

CREATE TABLE write_heavy_telemetry (
    reading_id INT PRIMARY KEY,
    metric_value DECIMAL(10, 2) NOT NULL,
    status_flag VARCHAR(10) NOT NULL
);

CREATE INDEX idx_telemetry_status ON write_heavy_telemetry(status_flag);

INSERT INTO write_heavy_telemetry VALUES
(1, 100.50, 'ACTIVE'),
(2, 200.75, 'INACTIVE'),
(3, 300.25, 'ACTIVE');

-- Reindex maintenance simulation
REINDEX idx_telemetry_status;

-- --- [SOLUTION QUERY] ---
SELECT 
    status_flag,
    COUNT(*) AS total_readings,
    AVG(metric_value) AS avg_value,
    'REINDEX_OPTIMIZED' AS maintenance_state
FROM write_heavy_telemetry
GROUP BY status_flag
ORDER BY total_readings DESC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 2
-- ASSERT: COL[status_flag] = ACTIVE
