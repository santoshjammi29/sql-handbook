-- ============================================================================
-- EXERCISE: 101_incident_parameter_sniffing_query_timeout.sql
-- MODULE:   10_production_incidents_and_triage
-- LEVEL:    🔴<br>Advanced
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ROLE:     Staff Database Performance Architect & Query Optimizer Specialist
-- ----------------------------------------------------------------------------
-- ARCHITECTURAL CONTEXT & SYSTEM TOPOLOGY:
--   PRODUCTION INCIDENT POSTMORTEM: Parameter Sniffing Sudden Query Timeouts.
--   An enterprise SaaS tenant reporting query running 5,000 times/hour historically
--   executed in 15 milliseconds. Suddenly, execution latencies spiked to 45 seconds,
--   triggering database thread starvation and gateway 504 timeouts.
--
-- BUSINESS CONTEXT:
--   PRODUCTION INCIDENT ROOT CAUSE:
--   Parameter Sniffing / Execution Plan Poisoning.
--   The query optimizer compiled and cached an execution plan for a rare "whale" tenant
--   (`tenant_id = 'TNT-MEGA-999'`, containing 15 million rows).
--   Because the whale tenant had high row density, the optimizer chose a Parallel Table Scan.
--   That Table Scan plan was stored in the plan cache. When thousands of standard tenants
--   (`tenant_id = 'TNT-SMALL-001'`, containing only 20 rows) executed the query, the engine
--   reused the cached Table Scan plan instead of using a fast B-Tree index seek!
--
-- PROBLEM STATEMENT:
--   SURGICAL TRIAGE & REMEDIATION:
--   Multi-Tier Query Routing Architecture:
--   Calculate tenant selectivity dynamically. If tenant is high-density (> 100,000 rows),
--   route to a bulk-optimized scan plan; if tenant is low-density, route to an index-seek plan.
-- ============================================================================

DROP TABLE IF EXISTS tenant_traffic_metrics;

CREATE TABLE tenant_traffic_metrics (
    tenant_id VARCHAR(32) PRIMARY KEY,
    tenant_name VARCHAR(100) NOT NULL,
    total_event_rows INT NOT NULL,
    selectivity_pct DECIMAL(5, 2) NOT NULL
);

INSERT INTO tenant_traffic_metrics VALUES
('TNT-SMALL-001', 'Startup Beta Labs',        50,   0.01),
('TNT-SMALL-002', 'Acme FinTech',            200,   0.02),
('TNT-MEGA-999',  'Global Telecomm Corp', 15000000, 99.97); -- Outlier whale tenant

-- --- [SOLUTION QUERY] ---
-- Query routing plan: Isolates outlier tenants to prevent plan cache poisoning
SELECT 
    tenant_id,
    tenant_name,
    total_event_rows,
    selectivity_pct,
    CASE 
        WHEN total_event_rows >= 1000000 THEN 'PARALLEL_TABLE_SCAN_BULK_WORKER'
        ELSE 'INDEX_SEEK_FAST_PATH_OLTP'
    END AS optimal_execution_plan,
    CASE 
        WHEN total_event_rows >= 1000000 THEN 'ISOLATE_INTO_DEDICATED_PLAN_POOL'
        ELSE 'SAFE_FOR_SHARED_CACHE'
    END AS cache_poisoning_mitigation
FROM tenant_traffic_metrics
ORDER BY total_event_rows ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 3
-- ASSERT: COL[tenant_id] = TNT-SMALL-001
-- ASSERT: COL[optimal_execution_plan] = INDEX_SEEK_FAST_PATH_OLTP\n