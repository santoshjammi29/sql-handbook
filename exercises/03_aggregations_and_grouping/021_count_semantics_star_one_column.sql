-- ============================================================================
-- EXERCISE: 021_count_semantics_star_one_column.sql
-- MODULE:   03_aggregations_and_grouping
-- LEVEL:    🟢<br>Beginner
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ROLE:     Lead Data Architect & Data Governance Lead
-- ----------------------------------------------------------------------------
-- ARCHITECTURAL CONTEXT & SYSTEM TOPOLOGY:
--   Enterprise Customer Master Data Management (MDM) & KYC Profiling Engine.
--   A data quality profiling job calculates column population metrics across identity records.
--
-- BUSINESS CONTEXT:
--   1. COUNT(*) counts all physical rows regardless of NULL values.
--   2. COUNT(column_name) counts only non-NULL values in that specific attribute.
--   3. COUNT(DISTINCT column_name) computes unique non-NULL cardinalities.
--   4. COUNT(1) is semantically identical to COUNT(*); query optimizers rewrite both
--      to table metadata row counts when no WHERE clause exists.
--
-- PROBLEM STATEMENT:
--   Profile a Customer KYC identity verification table, computing completeness percentages
--   and cardinality ratios across sensitive verification fields (SSN/Tax ID, Phone, Verified Date).
-- ============================================================================

DROP TABLE IF EXISTS customer_kyc_profiles;

CREATE TABLE customer_kyc_profiles (
    customer_id VARCHAR(32) PRIMARY KEY,
    full_name VARCHAR(100) NOT NULL,
    tax_identifier VARCHAR(50),      -- Nullable
    phone_number VARCHAR(30),        -- Nullable
    risk_rating VARCHAR(20) NOT NULL, -- 'LOW', 'MEDIUM', 'HIGH'
    verified_at TEXT                 -- Nullable
);

INSERT INTO customer_kyc_profiles VALUES
('C-01', 'Alice Morgan',    'TAX-001', '+1-555-0100', 'LOW',    '2024-05-01 10:00:00'),
('C-02', 'Brian Vance',     NULL,      '+1-555-0101', 'MEDIUM', '2024-05-01 11:30:00'),
('C-03', 'Carlos Ortiz',    'TAX-003', NULL,          'HIGH',   NULL),
('C-04', 'Daphne Sterling', 'TAX-004', '+1-555-0102', 'LOW',    '2024-05-02 09:15:00'),
('C-05', 'Edward Hyde',     NULL,      NULL,          'HIGH',   NULL),
('C-06', 'Fiona Gallagher', 'TAX-004', '+1-555-0100', 'LOW',    '2024-05-02 14:00:00'); -- Duplicate tax & phone!

-- --- [SOLUTION QUERY] ---
-- Enterprise Data Quality Profiling Matrix
SELECT 
    risk_rating,
    COUNT(*) AS total_candidate_records,
    COUNT(tax_identifier) AS populated_tax_ids,
    COUNT(DISTINCT tax_identifier) AS unique_tax_ids,
    COUNT(phone_number) AS populated_phones,
    COUNT(DISTINCT phone_number) AS unique_phones,
    COUNT(verified_at) AS verified_identities,
    -- Completeness percentage for tax identifier
    ROUND(CAST(COUNT(tax_identifier) AS DECIMAL) / COUNT(*) * 100.0, 2) AS tax_id_completeness_pct,
    -- Verification completion rate
    ROUND(CAST(COUNT(verified_at) AS DECIMAL) / COUNT(*) * 100.0, 2) AS kyc_verification_rate_pct
FROM customer_kyc_profiles
GROUP BY risk_rating
ORDER BY total_candidate_records DESC, risk_rating ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 3
-- ASSERT: COL[risk_rating] = LOW
