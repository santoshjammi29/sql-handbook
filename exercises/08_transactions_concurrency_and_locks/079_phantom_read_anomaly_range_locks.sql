-- ============================================================================
-- EXERCISE: 079_phantom_read_anomaly_range_locks.sql
-- MODULE:   08_transactions_concurrency_and_locks
-- LEVEL:    🔴<br>Advanced
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ROLE:     Lead Financial Systems Architect & Risk Engine Specialist
-- ----------------------------------------------------------------------------
-- ARCHITECTURAL CONTEXT & SYSTEM TOPOLOGY:
--   Commercial Underwriting Exposure Management & Range Lock Semantics.
--   Phantom Read Anomaly:
--   - Transaction 1 queries a range predicate: SELECT COUNT(*) WHERE risk_tier = 'TIER_1_CRITICAL'
--     AND facility_limit_usd >= 1000000. It reads 2 matching rows.
--   - Concurrently, Transaction 2 inserts a brand-new facility for $2,500,000 matching that predicate, and commits.
--   - Transaction 1 re-runs the range query: It now sees 3 rows! The new row is a "phantom".
--
-- BUSINESS CONTEXT:
--   In regulatory Basel III capital adequacy testing, if a credit underwriting risk ceiling
--   is calculated over a range, phantom inserts can breach capital buffers unnoticed.
--   Under SERIALIZABLE isolation (or InnoDB Next-Key Locks / PostgreSQL SSI), the engine
--   places a predicate lock or gap lock on the index range to block phantom insertions.
--
-- PROBLEM STATEMENT:
--   Model a commercial lending book and an active regulatory compliance evaluation window.
--   Demonstrate how the risk engine detects and audits phantom row occurrences across
--   transaction boundary timestamps (T1 vs T2).
-- ============================================================================

DROP TABLE IF EXISTS commercial_lending_facilities;

CREATE TABLE commercial_lending_facilities (
    facility_id VARCHAR(32) PRIMARY KEY,
    borrower_name VARCHAR(100) NOT NULL,
    risk_tier VARCHAR(20) NOT NULL,
    facility_limit_usd DECIMAL(14, 2) NOT NULL,
    approved_at TEXT NOT NULL,
    booking_tx_id INT NOT NULL
);

INSERT INTO commercial_lending_facilities VALUES
('FAC-101', 'Acme Infrastructure Corp', 'TIER_1_CRITICAL', 1500000.00, '2024-06-01 09:00:00', 801),
('FAC-102', 'Global Energy Holdings',   'TIER_1_CRITICAL', 3000000.00, '2024-06-01 09:30:00', 802),
('FAC-103', 'Starlight Tech Partners',   'TIER_3_LOW',       450000.00, '2024-06-01 09:45:00', 803),
-- Phantom row inserted and committed at 10:15:00 by Transaction 804
('FAC-104', 'Vanguard Aerospace Inc',    'TIER_1_CRITICAL', 2000000.00, '2024-06-01 10:15:00', 804);

-- --- [SOLUTION QUERY] ---
-- Reconstruct the range scan at Audit Time T1 ('2024-06-01 10:00:00') vs T2 ('2024-06-01 10:30:00')
WITH t1_initial_range_scan AS (
    SELECT 
        COUNT(*) AS initial_facility_count,
        COALESCE(SUM(facility_limit_usd), 0.00) AS initial_total_exposure_usd
    FROM commercial_lending_facilities
    WHERE risk_tier = 'TIER_1_CRITICAL'
      AND facility_limit_usd >= 1000000.00
      AND approved_at <= '2024-06-01 10:00:00'
),
t2_subsequent_range_scan AS (
    SELECT 
        COUNT(*) AS subsequent_facility_count,
        COALESCE(SUM(facility_limit_usd), 0.00) AS subsequent_total_exposure_usd
    FROM commercial_lending_facilities
    WHERE risk_tier = 'TIER_1_CRITICAL'
      AND facility_limit_usd >= 1000000.00
      AND approved_at <= '2024-06-01 10:30:00'
)
SELECT 
    t1.initial_facility_count,
    t1.initial_total_exposure_usd,
    t2.subsequent_facility_count,
    t2.subsequent_total_exposure_usd,
    (t2.subsequent_facility_count - t1.initial_facility_count) AS phantom_row_count,
    (t2.subsequent_total_exposure_usd - t1.initial_total_exposure_usd) AS phantom_exposure_delta_usd,
    'SERIALIZABLE_ISOLATION_REQUIRED_TO_PREVENT_PHANTOMS' AS architecture_remediation
FROM t1_initial_range_scan t1
CROSS JOIN t2_subsequent_range_scan t2;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 1
-- ASSERT: COL[initial_facility_count] = 2
-- ASSERT: COL[subsequent_facility_count] = 3
-- ASSERT: COL[phantom_row_count] = 1
-- ASSERT: COL[phantom_exposure_delta_usd] = 2000000.0\n