-- ============================================================================
-- EXERCISE: 101_incident_parameter_sniffing_query_timeout.sql
-- MODULE:   10_production_incidents_and_triage
-- LEVEL:    Advanced
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   PRODUCTION INCIDENT POSTMORTEM: Parameter Sniffing Sudden Query Timeouts.
--   A stored procedure ran in 20ms for normal tenants, but suddenly began
--   timing out across all callers. Root cause: An outlier tenant with 5M rows
--   compiled a Table Scan plan that was cached and forced onto all tenants.
-- PROBLEM STATEMENT:
--   Triage and execute production recovery.
-- SURGICAL REMEDIATION:
--   Use parameterized query masking or separate fast-path queries for dominant tenants.
-- ============================================================================

DROP TABLE IF EXISTS tenant_traffic;
CREATE TABLE tenant_traffic (
    tenant_id INT,
    event_id INT PRIMARY KEY,
    payload VARCHAR(50)
);

INSERT INTO tenant_traffic VALUES
(100, 1, 'Event 1'), (100, 2, 'Event 2'),
(999, 3, 'Massive Tenant Event 3');

-- --- [SOLUTION QUERY] ---
SELECT tenant_id, COUNT(*) AS tenant_event_count
FROM tenant_traffic
WHERE tenant_id = 100
GROUP BY tenant_id;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 1
-- ASSERT: COL[tenant_event_count] = 2
