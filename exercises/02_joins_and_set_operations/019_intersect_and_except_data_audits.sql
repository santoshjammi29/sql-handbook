-- ============================================================================
-- EXERCISE: 019_intersect_and_except_data_audits.sql
-- MODULE:   02_joins_and_set_operations
-- LEVEL:    🟡<br>Intermediate
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ROLE:     Lead Data Architect & Cloud Migration Lead
-- ----------------------------------------------------------------------------
-- ARCHITECTURAL CONTEXT & SYSTEM TOPOLOGY:
--   Legacy On-Prem Data Warehouse to Modern Cloud Lakehouse Migration.
--   During an enterprise migration, automated regression suites must verify data parity
--   between the legacy Oracle/Teradata mart and the target Snowflake/Databricks Delta table.
--
-- BUSINESS CONTEXT:
--   Set operations provide the mathematical foundation for zero-defect data validation:
--   1. INTERSECT: Returns only identical records present in BOTH legacy and cloud tables (Verified Parity).
--   2. EXCEPT (MINUS in Oracle): Returns records present in Table A but missing from Table B (Drift Detection).
--
-- PROBLEM STATEMENT:
--   Perform a bidirectional data parity audit using INTERSECT and EXCEPT to verify
--   successful data migration and isolate drift records.
-- ============================================================================

DROP TABLE IF EXISTS target_cloud_lakehouse;
DROP TABLE IF EXISTS source_legacy_dw;

CREATE TABLE source_legacy_dw (
    account_id VARCHAR(32) PRIMARY KEY,
    customer_tier VARCHAR(20) NOT NULL,
    current_balance_usd DECIMAL(12, 2) NOT NULL
);

CREATE TABLE target_cloud_lakehouse (
    account_id VARCHAR(32) PRIMARY KEY,
    customer_tier VARCHAR(20) NOT NULL,
    current_balance_usd DECIMAL(12, 2) NOT NULL
);

INSERT INTO source_legacy_dw VALUES
('ACC-101', 'ENTERPRISE', 50000.00), -- Identical
('ACC-102', 'MID_MARKET', 12500.00), -- Identical
('ACC-103', 'GROWTH',     3400.00),  -- Balance drifted in cloud!
('ACC-104', 'ENTERPRISE', 89000.00); -- Missing in cloud!

INSERT INTO target_cloud_lakehouse VALUES
('ACC-101', 'ENTERPRISE', 50000.00), -- Identical
('ACC-102', 'MID_MARKET', 12500.00), -- Identical
('ACC-103', 'GROWTH',     4100.00),  -- Drifted!
('ACC-105', 'GROWTH',     1500.00);  -- Only in cloud!

-- --- [SOLUTION QUERY] ---
-- Audit 1: Records in Legacy DW but missing/differing in Cloud Lakehouse (Source Parity Loss)
SELECT account_id, customer_tier, current_balance_usd, 'MISSING_OR_DRIFTED_IN_CLOUD' AS audit_result
FROM (
    SELECT account_id, customer_tier, current_balance_usd FROM source_legacy_dw
    EXCEPT
    SELECT account_id, customer_tier, current_balance_usd FROM target_cloud_lakehouse
)

UNION ALL

-- Audit 2: Records in Cloud Lakehouse but missing/differing in Legacy DW (Unsanctioned Additions)
SELECT account_id, customer_tier, current_balance_usd, 'UNSANCTIONED_ADDITION_IN_CLOUD' AS audit_result
FROM (
    SELECT account_id, customer_tier, current_balance_usd FROM target_cloud_lakehouse
    EXCEPT
    SELECT account_id, customer_tier, current_balance_usd FROM source_legacy_dw
)
ORDER BY account_id ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 4
-- ASSERT: COL[account_id] = ACC-103
