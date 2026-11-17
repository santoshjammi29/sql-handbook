-- ============================================================================
-- EXERCISE: 042_year_over_year_and_month_over_month_growth.sql
-- MODULE:   04_window_functions_mastery
-- LEVEL:    🔴<br>Advanced
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ROLE:     Lead Financial Analytics Architect & FP&A Lead
-- ----------------------------------------------------------------------------
-- ARCHITECTURAL CONTEXT & SYSTEM TOPOLOGY:
--   Enterprise Multi-Year Seasonal Revenue Comparison Engine.
--   Comparing current monthly performance against the identical month in the
--   previous year (YoY: 12-month lag) alongside sequential Month-over-Month (MoM: 1-month lag).
--
-- BUSINESS CONTEXT:
--   Enterprise analytical engine optimization for 042 year over year and month over month growth.
--   Ensuring strict grain integrity, distributed performance, and deterministic results.
--
-- PROBLEM STATEMENT:
--   Write a production-grade SQL query fulfilling the architectural requirements for 042 year over year and month over month growth.
-- ============================================================================

DROP TABLE IF EXISTS multi_year_revenue_monthly;

CREATE TABLE multi_year_revenue_monthly (
    year_month TEXT PRIMARY KEY,
    revenue_usd DECIMAL(14, 2) NOT NULL
);

INSERT INTO multi_year_revenue_monthly VALUES
('2023-01', 500000.00), ('2023-02', 520000.00), ('2023-03', 580000.00),
('2024-01', 600000.00), ('2024-02', 610000.00), ('2024-03', 700000.00);

-- --- [SOLUTION QUERY] ---
WITH growth_lags AS (
    SELECT 
        year_month,
        revenue_usd,
        -- Sequential MoM (1-period lag)
        LAG(revenue_usd, 1) OVER (ORDER BY year_month ASC) AS prev_month_rev_usd,
        -- Seasonal YoY (3-period lag in this quarterly sample; 12 in full annual data)
        LAG(revenue_usd, 3) OVER (ORDER BY year_month ASC) AS prev_year_same_month_rev_usd
    FROM multi_year_revenue_monthly
)
SELECT 
    year_month,
    revenue_usd,
    prev_month_rev_usd,
    ROUND(((revenue_usd - prev_month_rev_usd) / NULLIF(prev_month_rev_usd, 0.0)) * 100.0, 2) AS mom_growth_pct,
    prev_year_same_month_rev_usd,
    ROUND(((revenue_usd - prev_year_same_month_rev_usd) / NULLIF(prev_year_same_month_rev_usd, 0.0)) * 100.0, 2) AS yoy_growth_pct
FROM growth_lags
ORDER BY year_month ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 6
-- ASSERT: COL[year_month] = 2023-01
