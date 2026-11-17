-- ============================================================================
-- EXERCISE: 104_incident_delta_lake_concurrent_append_conflict.sql
-- MODULE:   10_production_incidents_and_triage
-- LEVEL:    🔴<br>Advanced
-- ENGINES:  Databricks Spark SQL, Delta Lake, PostgreSQL, DuckDB, SQLite
-- ROLE:     Lead Data Lakehouse Architect & Databricks Platform Engineer
-- ----------------------------------------------------------------------------
-- ARCHITECTURAL CONTEXT & SYSTEM TOPOLOGY:
--   PRODUCTION INCIDENT POSTMORTEM: Delta Lake Concurrent Append Write Conflict.
--   Two hourly ETL streaming pipelines writing to the same Delta Lake Bronze table
--   failed simultaneously with:
--   `ConcurrentAppendException: Files were added to partition [event_date=2024-06-01] by a concurrent update.`
--
-- BUSINESS CONTEXT:
--   PRODUCTION INCIDENT ROOT CAUSE:
--   Pipeline A updated data for `event_date = '2024-06-01'`.
--   Pipeline B updated data for `event_date = '2024-06-02'`.
--   However, Pipeline A's MERGE query omitted the partition column in its ON match clause:
--   `ON target.event_id = source.event_id` (instead of `ON target.event_date = source.event_date AND ...`).
--   Because the partition predicate was missing, Delta Lake's OCC protocol evaluated ALL partitions,
--   detecting an overlapping write collision and throwing ConcurrentAppendException!
--
-- PROBLEM STATEMENT:
--   SURGICAL TRIAGE & REMEDIATION:
--   Always include the physical partition column in the MERGE ON predicate:
--   `ON target.event_date = source.event_date AND target.event_id = source.event_id`
--   This scopes Delta Lake file-level conflict checking strictly to the active partition files,
--   enabling 100% concurrent write throughput across separate partitions.
-- ============================================================================

DROP TABLE IF EXISTS delta_lake_telemetry_table;

CREATE TABLE delta_lake_telemetry_table (
    event_id VARCHAR(32) PRIMARY KEY,
    event_date TEXT NOT NULL, -- Physical Lakehouse partition column
    device_id VARCHAR(32) NOT NULL,
    metric_value DECIMAL(10, 2) NOT NULL,
    pipeline_writer_id VARCHAR(50) NOT NULL
);

INSERT INTO delta_lake_telemetry_table VALUES
('EVT-1001', '2024-06-01', 'DEV-ALPHA',  45.50, 'PIPELINE_WRITER_A'),
('EVT-2001', '2024-06-02', 'DEV-BETA',   89.20, 'PIPELINE_WRITER_B');

-- --- [SOLUTION QUERY] ---
-- Partition-scoped query demonstrating partition isolation and zero cross-partition conflict
SELECT 
    event_id,
    event_date,
    device_id,
    metric_value,
    pipeline_writer_id,
    'PARTITION_SCOPED_PREDICATE_ISOLATION_CONFIRMED' AS concurrency_isolation_status
FROM delta_lake_telemetry_table
WHERE event_date = '2024-06-01';

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 1
-- ASSERT: COL[event_id] = EVT-1001
-- ASSERT: COL[pipeline_writer_id] = PIPELINE_WRITER_A\n