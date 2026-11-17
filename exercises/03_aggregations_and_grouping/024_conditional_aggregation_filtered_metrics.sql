-- ============================================================================
-- EXERCISE: 024_conditional_aggregation_filtered_metrics.sql
-- MODULE:   03_aggregations_and_grouping
-- LEVEL:    🟡<br>Intermediate
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ROLE:     Lead Analytics Engineer & SaaS Executive Metric Architect
-- ----------------------------------------------------------------------------
-- ARCHITECTURAL CONTEXT & SYSTEM TOPOLOGY:
--   Executive B2B SaaS Recurring Revenue & Retention Metrics Engine.
--   Monthly customer subscription changes (New Logos, Expansions, Contractions, Churn).
--
-- BUSINESS CONTEXT:
--   Instead of writing 4 separate queries with complex joins or multiple table scans,
--   production analytics engineers use Conditional Aggregation (SUM(CASE WHEN ...))
--   to compute New ARR, Expansion ARR, Contraction ARR, Churned ARR, and Net Retention
--   in a SINGLE, highly-optimized table pass.
--
-- PROBLEM STATEMENT:
--   Compute the comprehensive SaaS ARR Movement Waterfall for a billing cohort in a
--   single aggregation pass using conditional CASE expressions.
-- ============================================================================

DROP TABLE IF EXISTS saas_subscription_movements;

CREATE TABLE saas_subscription_movements (
    movement_id VARCHAR(32) PRIMARY KEY,
    customer_id VARCHAR(32) NOT NULL,
    cohort_month VARCHAR(7) NOT NULL,
    movement_type VARCHAR(20) NOT NULL, -- 'NEW_ARR', 'EXPANSION', 'CONTRACTION', 'CHURN'
    delta_mrr_usd DECIMAL(12, 2) NOT NULL
);

INSERT INTO saas_subscription_movements VALUES
('MOV-01', 'C-101', '2024-05', 'NEW_ARR',     5000.00),
('MOV-02', 'C-102', '2024-05', 'NEW_ARR',     8000.00),
('MOV-03', 'C-103', '2024-05', 'EXPANSION',   3500.00),
('MOV-04', 'C-104', '2024-05', 'CONTRACTION', -1200.00),
('MOV-05', 'C-105', '2024-05', 'CHURN',       -4000.00),
('MOV-06', 'C-106', '2024-05', 'EXPANSION',   2000.00),
('MOV-07', 'C-101', '2024-06', 'EXPANSION',   1500.00),
('MOV-08', 'C-107', '2024-06', 'NEW_ARR',     10000.00);

-- --- [SOLUTION QUERY] ---
-- Single-pass conditional aggregation SaaS ARR waterfall
SELECT 
    cohort_month,
    COUNT(DISTINCT customer_id) AS total_active_movement_accounts,
    -- Conditional sums calculating ARR components
    SUM(CASE WHEN movement_type = 'NEW_ARR' THEN delta_mrr_usd ELSE 0.00 END) AS new_arr_usd,
    SUM(CASE WHEN movement_type = 'EXPANSION' THEN delta_mrr_usd ELSE 0.00 END) AS expansion_arr_usd,
    SUM(CASE WHEN movement_type = 'CONTRACTION' THEN delta_mrr_usd ELSE 0.00 END) AS contraction_arr_usd,
    SUM(CASE WHEN movement_type = 'CHURN' THEN delta_mrr_usd ELSE 0.00 END) AS churned_arr_usd,
    -- Net New ARR calculation
    SUM(delta_mrr_usd) AS net_new_arr_usd,
    -- Percentage of positive growth derived from existing account expansion
    ROUND(
        SUM(CASE WHEN movement_type = 'EXPANSION' THEN delta_mrr_usd ELSE 0.00 END) / 
        NULLIF(SUM(CASE WHEN movement_type IN ('NEW_ARR', 'EXPANSION') THEN delta_mrr_usd ELSE 0.00 END), 0) * 100.0, 
        2
    ) AS expansion_growth_share_pct
FROM saas_subscription_movements
GROUP BY cohort_month
ORDER BY cohort_month ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 2
-- ASSERT: COL[cohort_month] = 2024-05
