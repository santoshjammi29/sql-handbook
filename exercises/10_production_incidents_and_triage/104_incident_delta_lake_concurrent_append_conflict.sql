-- ============================================================================
-- EXERCISE: 104_incident_delta_lake_concurrent_append_conflict.sql
-- MODULE:   10_production_incidents_and_triage
-- LEVEL:    Advanced
-- ENGINES:  Databricks Spark SQL, Delta Lake, PostgreSQL, DuckDB, SQLite
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   PRODUCTION INCIDENT POSTMORTEM: Concurrent Append Write Conflict.
--   Two hourly ETL pipelines wrote to the same Delta Lake table simultaneously.
--   Pipeline A modified partition date='2024-05-01' while Pipeline B modified
--   partition date='2024-05-02'. Because table lacked partition predicates in
--   the merge condition, Delta OCC threw ConcurrentAppendException!
-- PROBLEM STATEMENT:
--   Triage and execute production recovery.
-- SURGICAL REMEDIATION:
--   Always scope MERGE/UPDATE conditions strictly to specific partition boundaries.
-- ============================================================================

DROP TABLE IF EXISTS partitioned_lakehouse_log;
CREATE TABLE partitioned_lakehouse_log (
    log_id INT PRIMARY KEY,
    log_date TEXT,
    msg VARCHAR(50)
);

INSERT INTO partitioned_lakehouse_log VALUES
(1, '2024-05-01', 'Pipeline A data'),
(2, '2024-05-02', 'Pipeline B data');

-- --- [SOLUTION QUERY] ---
SELECT log_id, log_date, msg
FROM partitioned_lakehouse_log
WHERE log_date = '2024-05-01';

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 1
-- ASSERT: COL[msg] = Pipeline A data
