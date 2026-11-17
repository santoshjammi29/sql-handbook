-- ============================================================================
-- EXERCISE: 067_composite_index_column_ordering_left_prefix.sql
-- MODULE:   07_indexing_and_query_optimization
-- LEVEL:    Advanced
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   Multi-tenant SaaS databases partition customer data by tenant_id. Queries
--   filter by tenant_id and created_at. An index created with columns in the
--   wrong order (created_at, tenant_id) cannot seek on tenant_id alone!
-- PROBLEM STATEMENT:
--   Demonstrate the Left-to-Right Prefix Rule: an index on (tenant_id, created_at)
--   efficiently services filters on (tenant_id) and (tenant_id, created_at).
-- ============================================================================

DROP TABLE IF EXISTS tenant_audit_log;
CREATE TABLE tenant_audit_log (
    log_id INT PRIMARY KEY,
    tenant_id INT,
    created_at TEXT,
    event_action VARCHAR(50)
);

CREATE INDEX idx_tenant_created ON tenant_audit_log (tenant_id, created_at);

INSERT INTO tenant_audit_log VALUES
(1, 100, '2024-05-01 10:00:00', 'LOGIN'),
(2, 100, '2024-05-01 11:30:00', 'UPDATE'),
(3, 200, '2024-05-01 12:00:00', 'LOGIN');

-- --- [SOLUTION QUERY] ---
SELECT log_id, tenant_id, created_at, event_action
FROM tenant_audit_log
WHERE tenant_id = 100 
  AND created_at >= '2024-05-01 10:00:00'
ORDER BY created_at ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 2
-- ASSERT: COL[event_action] = LOGIN
