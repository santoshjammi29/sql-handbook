-- ============================================================================
-- EXERCISE: 070_cardinality_estimation_and_statistics.sql
-- MODULE:   07_indexing_and_query_optimization
-- LEVEL:    🔴<br>Advanced
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ROLE:     Lead Cost-Based Optimizer Specialist & Performance DBA
-- ----------------------------------------------------------------------------
-- ARCHITECTURAL CONTEXT & SYSTEM TOPOLOGY:
--   Cost-Based Optimizer (CBO) Cardinality Estimation & Statistics Drift.
--   Query optimizers rely on column histograms to estimate row counts and choose
--   between Nested Loop (for small row sets) vs Hash Join (for large sets).
--   When statistics are outdated, the optimizer makes disastrous join algorithm choices!
--
-- BUSINESS CONTEXT:
--   Enterprise analytical engine optimization for 070 cardinality estimation and statistics.
--   Ensuring strict grain integrity, distributed performance, and deterministic results.
--
-- PROBLEM STATEMENT:
--   Write a production-grade SQL query fulfilling the architectural requirements for 070 cardinality estimation and statistics.
-- ============================================================================

DROP TABLE IF EXISTS candidate_tenants;

CREATE TABLE candidate_tenants (
    tenant_id VARCHAR(32) PRIMARY KEY,
    subscription_status VARCHAR(20) NOT NULL,
    estimated_mrr_usd DECIMAL(12, 2) NOT NULL
);

INSERT INTO candidate_tenants VALUES
('TNT-1', 'TRIAL',    0.00),
('TNT-2', 'ACTIVE', 5000.00),
('TNT-3', 'ACTIVE', 8000.00),
('TNT-4', 'CHURNED', 0.00);

-- --- [SOLUTION QUERY] ---
-- Analytical inspection of column selectivity distribution
SELECT 
    subscription_status,
    COUNT(*) AS total_tenants,
    ROUND(CAST(COUNT(*) AS DECIMAL) / (SELECT COUNT(*) FROM candidate_tenants) * 100.0, 2) AS population_share_pct,
    SUM(estimated_mrr_usd) AS aggregate_mrr_usd,
    CASE 
        WHEN (CAST(COUNT(*) AS DECIMAL) / (SELECT COUNT(*) FROM candidate_tenants)) <= 0.10 THEN 'HIGH_SELECTIVITY_INDEX_SEEK'
        ELSE 'LOW_SELECTIVITY_FULL_SCAN'
    END AS optimal_access_path
FROM candidate_tenants
GROUP BY subscription_status
ORDER BY total_tenants DESC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 3
-- ASSERT: COL[subscription_status] = ACTIVE
