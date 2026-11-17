-- ============================================================================
-- EXERCISE: 100_incident_silent_schema_drift_bi_refresh_failure.sql
-- MODULE:   10_production_incidents_and_triage
-- LEVEL:    Intermediate
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   PRODUCTION INCIDENT POSTMORTEM: Silent Schema Drift Breaking BI Dashboards.
--   Upstream application engineers renamed column 'client_email' to 'email_addr'
--   without notice, crashing Monday morning Power BI executive refresh.
-- PROBLEM STATEMENT:
--   Triage and execute production recovery.
-- SURGICAL REMEDIATION:
--   Implement a Data Contract audit query that checks schema column integrity.
-- ============================================================================

DROP TABLE IF EXISTS schema_columns_catalog;
CREATE TABLE schema_columns_catalog (
    table_name VARCHAR(50),
    column_name VARCHAR(50),
    is_required INT
);

INSERT INTO schema_columns_catalog VALUES
('dim_client', 'client_id', 1),
('dim_client', 'client_email', 1),
('dim_client', 'created_at', 0);

-- Actual landing schema
DROP TABLE IF EXISTS landing_table_columns;
CREATE TABLE landing_table_columns (
    column_name VARCHAR(50)
);

INSERT INTO landing_table_columns VALUES ('client_id'), ('email_addr'); -- Drift!

-- --- [SOLUTION QUERY] ---
-- Schema Drift Alert Query
SELECT 
    c.table_name,
    c.column_name AS missing_contract_column
FROM schema_columns_catalog c
LEFT JOIN landing_table_columns l ON c.column_name = l.column_name
WHERE c.is_required = 1 
  AND l.column_name IS NULL;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 1
-- ASSERT: COL[missing_contract_column] = client_email
