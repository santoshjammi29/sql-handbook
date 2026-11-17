-- ============================================================================
-- EXERCISE: 033_value_offsets_lag_lead_period_over_period.sql
-- MODULE:   04_window_functions_mastery
-- LEVEL:    Intermediate
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   Financial health tracking requires comparing this month's revenue to the
--   previous month to calculate Month-over-Month (MoM) growth rates.
-- PROBLEM STATEMENT:
--   Use LAG() to access the prior month's revenue and compute absolute and
--   percentage change.
-- ============================================================================

DROP TABLE IF EXISTS monthly_mrr;
CREATE TABLE monthly_mrr (
    month_id INT PRIMARY KEY,
    month_str VARCHAR(10),
    mrr_amount DECIMAL(10, 2)
);

INSERT INTO monthly_mrr VALUES
(1, '2024-01', 50000.00),
(2, '2024-02', 55000.00),
(3, '2024-03', 52000.00),
(4, '2024-04', 60000.00);

-- --- [SOLUTION QUERY] ---
SELECT 
    month_id,
    month_str,
    mrr_amount,
    LAG(mrr_amount, 1) OVER (ORDER BY month_id ASC) AS prev_month_mrr,
    (mrr_amount - LAG(mrr_amount, 1) OVER (ORDER BY month_id ASC)) AS mom_absolute_growth,
    ROUND(
        100.0 * (mrr_amount - LAG(mrr_amount, 1) OVER (ORDER BY month_id ASC)) / 
        NULLIF(LAG(mrr_amount, 1) OVER (ORDER BY month_id ASC), 0),
        2
    ) AS mom_growth_pct
FROM monthly_mrr
ORDER BY month_id ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 4
-- ASSERT: COL[mom_growth_pct] = 10.0
