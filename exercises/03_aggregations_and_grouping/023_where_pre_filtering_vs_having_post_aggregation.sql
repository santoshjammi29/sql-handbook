-- ============================================================================
-- EXERCISE: 023_where_pre_filtering_vs_having_post_aggregation.sql
-- MODULE:   03_aggregations_and_grouping
-- LEVEL:    🟢<br>Beginner
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ROLE:     Lead FinOps Cloud Architect & Cost Optimization Lead
-- ----------------------------------------------------------------------------
-- ARCHITECTURAL CONTEXT & SYSTEM TOPOLOGY:
--   Multi-Cloud FinOps Infrastructure Spend Attribution & Outlier Detection.
--   Processing cloud billing records across Amazon Web Services, Google Cloud, and Azure.
--
-- BUSINESS CONTEXT:
--   1. WHERE pre-filters unaggregated row-level attributes: Discard dev/sandbox/trial
--      test clusters BEFORE heavy aggregations run, saving massive memory & CPU.
--   2. HAVING post-filters aggregated metrics: Threshold aggregate spend (e.g. only
--      report production departments whose monthly bill exceeds 10,000 USD).
--   3. Putting row filters into HAVING forces the database to aggregate billions of
--      worthless dev rows before discarding them!
--
-- PROBLEM STATEMENT:
--   Construct an optimal FinOps spend report that pre-filters non-production resources
--   in WHERE, and identifies high-spend department anomalies in HAVING.
-- ============================================================================

DROP TABLE IF EXISTS cloud_resource_billing;

CREATE TABLE cloud_resource_billing (
    resource_id VARCHAR(32) PRIMARY KEY,
    department_name VARCHAR(50) NOT NULL,
    environment_tier VARCHAR(20) NOT NULL, -- 'PRODUCTION', 'STAGING', 'SANDBOX'
    monthly_cost_usd DECIMAL(12, 2) NOT NULL,
    cloud_provider VARCHAR(20) NOT NULL
);

INSERT INTO cloud_resource_billing VALUES
('RES-001', 'Core Engineering', 'PRODUCTION', 15000.00, 'AWS'),
('RES-002', 'Core Engineering', 'PRODUCTION', 8500.00,  'AWS'),
('RES-003', 'Core Engineering', 'SANDBOX',    1200.00,  'AWS'), -- Discard in WHERE!
('RES-004', 'Machine Learning', 'PRODUCTION', 24000.00, 'GCP'),
('RES-005', 'Machine Learning', 'PRODUCTION', 12000.00, 'GCP'),
('RES-006', 'Customer Support', 'PRODUCTION', 2500.00,  'AZURE'),
('RES-007', 'Marketing Tech',   'PRODUCTION', 3200.00,  'AWS'),
('RES-008', 'Data Platform',    'PRODUCTION', 18000.00, 'AWS'),
('RES-009', 'Data Platform',    'STAGING',    4000.00,  'AWS'); -- Discard in WHERE!

-- --- [SOLUTION QUERY] ---
-- Production FinOps query:
-- 1. WHERE pre-filters environment = 'PRODUCTION' before grouping (reducing memory shuffle)
-- 2. HAVING post-filters aggregated department spend >= 20,000 USD
SELECT 
    department_name,
    COUNT(resource_id) AS active_prod_clusters,
    SUM(monthly_cost_usd) AS total_prod_spend_usd,
    ROUND(AVG(monthly_cost_usd), 2) AS avg_cluster_cost_usd,
    'EXCEEDS_BUDGET_CAP' AS finops_review_status
FROM cloud_resource_billing
WHERE environment_tier = 'PRODUCTION' -- Pre-aggregation row filter!
GROUP BY department_name
HAVING SUM(monthly_cost_usd) >= 20000.00 -- Post-aggregation threshold!
ORDER BY total_prod_spend_usd DESC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 2
-- ASSERT: COL[department_name] = Machine Learning
