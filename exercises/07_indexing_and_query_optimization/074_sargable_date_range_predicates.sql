-- ============================================================================
-- EXERCISE: 074_sargable_date_range_predicates.sql
-- MODULE:   07_indexing_and_query_optimization
-- LEVEL:    🔴<br>Advanced
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ROLE:     Lead Performance Architect & Cloud FinOps Lead
-- ----------------------------------------------------------------------------
-- ARCHITECTURAL CONTEXT & SYSTEM TOPOLOGY:
--   High-Volume Log Auditing SARGable Date Range Predicates.
--   Converting non-SARGable scalar date manipulations into high-performance index range seeks.
--
-- BUSINESS CONTEXT:
--   Enterprise analytical engine optimization for 074 sargable date range predicates.
--   Ensuring strict grain integrity, distributed performance, and deterministic results.
--
-- PROBLEM STATEMENT:
--   Write a production-grade SQL query fulfilling the architectural requirements for 074 sargable date range predicates.
-- ============================================================================

DROP TABLE IF EXISTS system_event_archive;

CREATE TABLE system_event_archive (
    event_id VARCHAR(32) PRIMARY KEY,
    event_time TEXT NOT NULL,
    payload VARCHAR(100) NOT NULL
);

CREATE INDEX idx_system_event_time ON system_event_archive(event_time);

INSERT INTO system_event_archive VALUES
('E-01', '2024-05-01 10:15:00', 'AUTH_SUCCESS'),
('E-02', '2024-05-01 23:59:59', 'DATABASE_BACKUP'),
('E-03', '2024-05-02 00:00:00', 'HEARTBEAT_OK'),
('E-04', '2024-04-30 23:59:59', 'MAINTENANCE_WINDOW');

-- --- [SOLUTION QUERY] ---
-- SARGable half-open date interval [2024-05-01 00:00:00, 2024-05-02 00:00:00)
SELECT 
    event_id,
    event_time,
    payload,
    'SARGABLE_HALF_OPEN_INTERVAL_SEEK' AS query_plan
FROM system_event_archive
WHERE event_time >= '2024-05-01 00:00:00' 
  AND event_time < '2024-05-02 00:00:00'
ORDER BY event_time ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 2
-- ASSERT: COL[event_id] = E-01
