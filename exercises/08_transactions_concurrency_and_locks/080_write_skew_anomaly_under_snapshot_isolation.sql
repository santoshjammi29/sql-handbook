-- ============================================================================
-- EXERCISE: 080_write_skew_anomaly_under_snapshot_isolation.sql
-- MODULE:   08_transactions_concurrency_and_locks
-- LEVEL:    🟣<br>Architect
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ROLE:     Principal Database Architect & Distributed Concurrency Specialist
-- ----------------------------------------------------------------------------
-- ARCHITECTURAL CONTEXT & SYSTEM TOPOLOGY:
--   Hospital Emergency Room On-Call Roster & Snapshot Isolation Invariants.
--   Write Skew Anomaly:
--   - Invariant: At all times, at least 1 physician must remain on call (COUNT(on_call) >= 1).
--   - Currently on call: Dr. Alice and Dr. Bob (COUNT = 2).
--   - Transaction 1 (Dr. Alice): Checks COUNT(*) WHERE is_on_call = 1. Sees 2.
--     Decides it is safe to take leave and sets Dr. Alice's is_on_call = 0.
--   - Concurrently, Transaction 2 (Dr. Bob): Checks COUNT(*) WHERE is_on_call = 1. Sees 2.
--     Decides it is safe to take leave and sets Dr. Bob's is_on_call = 0.
--   - Under Snapshot Isolation, BOTH transactions commit! Why? They modified disjoint rows!
--   - Result: 0 doctors on call. Severe invariant failure (Write Skew)!
--
-- BUSINESS CONTEXT:
--   Snapshot isolation guarantees repeatable reads and prevents dirty/phantom reads,
--   but CANNOT prevent write skew when overlapping transactions make decisions based
--   on overlapping read sets and write to non-overlapping write sets.
--   The permanent architectural solutions:
--   1. SERIALIZABLE isolation (Serializable Snapshot Isolation - SSI).
--   2. Explicit materialized lock table (e.g. SELECT FOR UPDATE on a master shift lock row).
--
-- PROBLEM STATEMENT:
--   Simulate the hospital shift schedule. Implement a conditional state-machine query
--   that checks the on-call invariant and flags whether the concurrent leave requests
--   resulted in an illegal zero-coverage write skew violation.
-- ============================================================================

DROP TABLE IF EXISTS hospital_shift_audit;
DROP TABLE IF EXISTS hospital_on_call_roster;

CREATE TABLE hospital_on_call_roster (
    doctor_id VARCHAR(32) PRIMARY KEY,
    doctor_name VARCHAR(100) NOT NULL,
    department VARCHAR(50) NOT NULL,
    is_on_call INT NOT NULL -- 1 = True, 0 = False
);

CREATE TABLE hospital_shift_audit (
    request_id VARCHAR(32) PRIMARY KEY,
    doctor_id VARCHAR(32) NOT NULL,
    requested_action VARCHAR(20) NOT NULL,
    snapshot_visible_count INT NOT NULL,
    status VARCHAR(20) NOT NULL
);

INSERT INTO hospital_on_call_roster VALUES
('DOC-01', 'Dr. Alice Smith', 'TRAUMA_SURGERY', 1),
('DOC-02', 'Dr. Bob Jones',    'TRAUMA_SURGERY', 1);

-- Simulate the race condition under Snapshot Isolation:
-- Both read snapshot count = 2 at 08:00:00
INSERT INTO hospital_shift_audit VALUES
('REQ-101', 'DOC-01', 'TAKE_OFF_CALL', 2, 'APPLIED'),
('REQ-102', 'DOC-02', 'TAKE_OFF_CALL', 2, 'APPLIED');

-- If both updates execute blindly:
UPDATE hospital_on_call_roster SET is_on_call = 0 WHERE doctor_id = 'DOC-01';
UPDATE hospital_on_call_roster SET is_on_call = 0 WHERE doctor_id = 'DOC-02';

-- --- [SOLUTION QUERY] ---
-- Audit query detecting the write skew anomaly and evaluating active doctor count
WITH on_call_evaluation AS (
    SELECT 
        COUNT(*) AS total_doctors_registered,
        SUM(CASE WHEN is_on_call = 1 THEN 1 ELSE 0 END) AS active_on_call_physicians
    FROM hospital_on_call_roster
    WHERE department = 'TRAUMA_SURGERY'
)
SELECT 
    e.total_doctors_registered,
    e.active_on_call_physicians,
    CASE 
        WHEN e.active_on_call_physicians = 0 THEN 'CRITICAL_WRITE_SKEW_INVARIANT_VIOLATION'
        WHEN e.active_on_call_physicians >= 1 THEN 'COMPLIANT_COVERAGE'
    END AS invariant_health_status,
    'ENFORCE_SERIALIZABLE_OR_MUTEX_ROW_LOCK' AS architectural_remedy
FROM on_call_evaluation e;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 1
-- ASSERT: COL[total_doctors_registered] = 2
-- ASSERT: COL[active_on_call_physicians] = 0
-- ASSERT: COL[invariant_health_status] = CRITICAL_WRITE_SKEW_INVARIANT_VIOLATION\n