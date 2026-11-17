-- ============================================================================
-- EXERCISE: 013_anti_joins_for_missing_record_detection.sql
-- MODULE:   02_joins_and_set_operations
-- LEVEL:    🟡<br>Intermediate
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ROLE:     Lead Data Architect & Data Quality SRE
-- ----------------------------------------------------------------------------
-- ARCHITECTURAL CONTEXT & SYSTEM TOPOLOGY:
--   Enterprise Lakehouse Reconciliation & Pipeline Data Loss Sentinel.
--   Nightly batch reconciliation between staging landing tables (source truth)
--   and the conformed enterprise data warehouse (EDW) reporting mart.
--
-- BUSINESS CONTEXT:
--   During an upstream network glitch, 15 payment transactions landed in the staging
--   table but failed to load into the EDW fact table due to an unhandled retry exception.
--   Data Quality SREs must immediately detect all missing records, identify the pipeline
--   stage drop-off point, and produce a re-ingestion manifest.
--
-- PROBLEM STATEMENT:
--   Execute a high-performance ANTI-JOIN using NOT EXISTS to isolate missing records
--   between the landing layer and the fact table, verifying audit metadata and payload state.
-- ============================================================================

DROP TABLE IF EXISTS fact_settled_payments;
DROP TABLE IF EXISTS stg_raw_payments_landing;

CREATE TABLE stg_raw_payments_landing (
    payment_uuid VARCHAR(36) PRIMARY KEY,
    merchant_id VARCHAR(32) NOT NULL,
    amount_usd DECIMAL(12, 2) NOT NULL,
    auth_code VARCHAR(20) NOT NULL,
    landed_timestamp TEXT NOT NULL
);

CREATE TABLE fact_settled_payments (
    payment_uuid VARCHAR(36) PRIMARY KEY,
    merchant_id VARCHAR(32) NOT NULL,
    amount_usd DECIMAL(12, 2) NOT NULL,
    settled_timestamp TEXT NOT NULL
);

INSERT INTO stg_raw_payments_landing VALUES
('PAY-001', 'MCH-10', 1500.00, 'AUTH-991', '2024-05-01 10:00:00'),
('PAY-002', 'MCH-20', 2300.00, 'AUTH-992', '2024-05-01 10:05:00'),
('PAY-003', 'MCH-10', 850.00,  'AUTH-993', '2024-05-01 10:10:00'), -- Missing in fact!
('PAY-004', 'MCH-30', 4200.00, 'AUTH-994', '2024-05-01 10:15:00'),
('PAY-005', 'MCH-20', 120.00,  'AUTH-995', '2024-05-01 10:20:00'); -- Missing in fact!

INSERT INTO fact_settled_payments VALUES
('PAY-001', 'MCH-10', 1500.00, '2024-05-01 10:30:00'),
('PAY-002', 'MCH-20', 2300.00, '2024-05-01 10:30:00'),
('PAY-004', 'MCH-30', 4200.00, '2024-05-01 10:30:00');

-- --- [SOLUTION QUERY] ---
-- Anti-Join pattern using NOT EXISTS: Detects all landed payments missing from the EDW
SELECT 
    s.payment_uuid,
    s.merchant_id,
    s.amount_usd,
    s.auth_code,
    s.landed_timestamp,
    'MISSING_FROM_WAREHOUSE_QUARANTINE' AS triage_flag
FROM stg_raw_payments_landing s
WHERE NOT EXISTS (
    SELECT 1 
    FROM fact_settled_payments f
    WHERE f.payment_uuid = s.payment_uuid
)
ORDER BY s.amount_usd DESC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 2
-- ASSERT: COL[payment_uuid] = PAY-003
