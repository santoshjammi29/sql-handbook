-- ============================================================================
-- EXERCISE: 080_write_skew_anomaly_under_snapshot_isolation.sql
-- MODULE:   08_transactions_concurrency_and_locks
-- LEVEL:    Advanced
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   The Hospital On-Call Doctor Dilemma (Write Skew): A hospital requires at
--   least 1 doctor on call. Alice and Bob are on call (Count = 2). Alice takes
--   leave because Count >= 2. Concurrently, Bob takes leave because Count >= 2.
--   Under Snapshot Isolation, both commit because they updated distinct rows,
--   leaving 0 doctors on call!
-- PROBLEM STATEMENT:
--   Model the on-call doctor state and enforce the global constraint.
-- ============================================================================

DROP TABLE IF EXISTS on_call_schedule;
CREATE TABLE on_call_schedule (
    doctor_id INT PRIMARY KEY,
    doctor_name VARCHAR(50),
    is_on_call INT
);

INSERT INTO on_call_schedule VALUES (1, 'Dr. Alice', 1), (2, 'Dr. Bob', 1);

-- Safe update guard: Only allow turning off if remaining count > 1
UPDATE on_call_schedule
SET is_on_call = 0
WHERE doctor_id = 1 
  AND (SELECT COUNT(*) FROM on_call_schedule WHERE is_on_call = 1) > 1;

-- --- [SOLUTION QUERY] ---
SELECT 
    doctor_id,
    doctor_name,
    is_on_call,
    (SELECT COUNT(*) FROM on_call_schedule WHERE is_on_call = 1) AS remaining_on_call
FROM on_call_schedule
ORDER BY doctor_id ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 2
-- ASSERT: COL[remaining_on_call] = 1
