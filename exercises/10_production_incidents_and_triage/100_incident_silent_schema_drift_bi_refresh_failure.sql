-- ============================================================================
-- EXERCISE: 100_incident_silent_schema_drift_bi_refresh_failure.sql
-- MODULE:   10_production_incidents_and_triage
-- LEVEL:    🟡<br>Intermediate
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ROLE:     Lead Data Platform Architect & Data Contract Governance Specialist
-- ----------------------------------------------------------------------------
-- ARCHITECTURAL CONTEXT & SYSTEM TOPOLOGY:
--   PRODUCTION INCIDENT POSTMORTEM: Silent Schema Drift Breaking Executive BI Dashboards.
--   At 06:00 Monday morning, the C-Suite executive revenue dashboard failed to refresh
--   with `ColumnNotFoundException: client_email`. 400 VP and Director reports were delayed.
--
-- BUSINESS CONTEXT:
--   PRODUCTION INCIDENT ROOT CAUSE:
--   An upstream checkout engineering team deployed a database migration that renamed
--   `client_email` to `email_address` without notifying downstream data teams or updating data contracts.
--   Downstream ETL pipelines landed the table, but downstream dbt/BI models broke hard on the missing column.
--
-- PROBLEM STATEMENT:
--   SURGICAL TRIAGE & REMEDIATION:
--   Implement an automated Data Contract Schema Validator query.
--   The pipeline interrogates actual landed table column metadata against the published
--   Data Contract specification, flagging missing required columns, data type shifts,
--   and schema breaches before analytical models execute.
-- ============================================================================

DROP TABLE IF EXISTS actual_landing_table_catalog;
DROP TABLE IF EXISTS enterprise_data_contract_spec;

CREATE TABLE enterprise_data_contract_spec (
    table_name VARCHAR(50) NOT NULL,
    column_name VARCHAR(50) NOT NULL,
    data_type VARCHAR(30) NOT NULL,
    is_required INT NOT NULL -- 1 = Mandatory, 0 = Optional
);

CREATE TABLE actual_landing_table_catalog (
    table_name VARCHAR(50) NOT NULL,
    column_name VARCHAR(50) NOT NULL,
    actual_data_type VARCHAR(30) NOT NULL
);

-- Contract Specification:
INSERT INTO enterprise_data_contract_spec VALUES
('dim_client', 'client_id',    'VARCHAR', 1),
('dim_client', 'client_email', 'VARCHAR', 1), -- Mandatory contract column!
('dim_client', 'created_at',   'TIMESTAMP', 0);

-- Actual Landed Table (client_email was renamed to email_address!):
INSERT INTO actual_landing_table_catalog VALUES
('dim_client', 'client_id',     'VARCHAR'),
('dim_client', 'email_address', 'VARCHAR'), -- Schema Drift!
('dim_client', 'created_at',    'TIMESTAMP');

-- --- [SOLUTION QUERY] ---
-- Automated Data Contract Audit Query detecting schema drift breaches
SELECT 
    s.table_name,
    s.column_name AS required_contract_column,
    s.data_type AS expected_data_type,
    'MISSING_REQUIRED_COLUMN_BREACH' AS contract_violation_type,
    'BLOCK_DOWNSTREAM_PIPELINE_AND_ALERT_ON_CALL' AS remediation_action
FROM enterprise_data_contract_spec s
LEFT JOIN actual_landing_table_catalog a 
    ON s.table_name = a.table_name 
   AND s.column_name = a.column_name
WHERE s.is_required = 1 
  AND a.column_name IS NULL;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 1
-- ASSERT: COL[required_contract_column] = client_email
-- ASSERT: COL[contract_violation_type] = MISSING_REQUIRED_COLUMN_BREACH\n