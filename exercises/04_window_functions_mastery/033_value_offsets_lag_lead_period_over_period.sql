-- ============================================================================
-- EXERCISE: 033_value_offsets_lag_lead_period_over_period.sql
-- MODULE:   04_window_functions_mastery
-- LEVEL:    🔴<br>Advanced
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ROLE:     Lead Financial Systems Architect & Quantitative Analyst
-- ----------------------------------------------------------------------------
-- ARCHITECTURAL CONTEXT & SYSTEM TOPOLOGY:
--   SaaS Monthly Recurring Revenue (MRR) Period-over-Period Variance Engine.
--   Calculating absolute dollar changes and percentage month-over-month growth rates.
--
-- BUSINESS CONTEXT:
--   1. LAG(column, offset, default) fetches the value from N rows prior within the partition.
--   2. LEAD(column, offset, default) looks ahead to future rows.
--   3. Division by previous month's MRR must guard against NULL and zero values.
--
-- PROBLEM STATEMENT:
--   Implement an enterprise-grade query to resolve 033 value offsets lag lead period over period.
-- ============================================================================

DROP TABLE IF EXISTS monthly_subscription_metrics;

CREATE TABLE monthly_subscription_metrics (
    reporting_month VARCHAR(7) PRIMARY KEY, -- 'YYYY-MM'
    mrr_usd DECIMAL(12, 2) NOT NULL
);

INSERT INTO monthly_subscription_metrics VALUES
('2024-01', 100000.00),
('2024-02', 115000.00),
('2024-03', 128000.00),
('2024-04', 124000.00), -- Contraction month!
('2024-05', 142000.00);

-- --- [SOLUTION QUERY] ---
-- MoM Growth analysis using LAG
WITH mom_calculations AS (
    SELECT 
        reporting_month,
        mrr_usd,
        LAG(mrr_usd, 1) OVER (ORDER BY reporting_month ASC) AS prev_month_mrr_usd,
        LEAD(mrr_usd, 1) OVER (ORDER BY reporting_month ASC) AS next_month_projected_mrr_usd
    FROM monthly_subscription_metrics
)
SELECT 
    reporting_month,
    mrr_usd,
    COALESCE(prev_month_mrr_usd, mrr_usd) AS prev_month_mrr_usd,
    ROUND(mrr_usd - COALESCE(prev_month_mrr_usd, mrr_usd), 2) AS mom_dollar_variance_usd,
    ROUND(
        ((mrr_usd - prev_month_mrr_usd) / NULLIF(prev_month_mrr_usd, 0.00)) * 100.0, 
        2
    ) AS mom_growth_pct,
    CASE 
        WHEN prev_month_mrr_usd IS NULL THEN 'BASELINE_MONTH'
        WHEN mrr_usd > prev_month_mrr_usd THEN 'POSITIVE_EXPANSION'
        ELSE 'REVENUE_CONTRACTION'
    END AS trajectory_status
FROM mom_calculations
ORDER BY reporting_month ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 5
-- ASSERT: COL[reporting_month] = 2024-01
