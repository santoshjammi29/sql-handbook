-- ============================================================================
-- EXERCISE: 042_year_over_year_and_month_over_month_growth.sql
-- MODULE:   04_window_functions_mastery
-- LEVEL:    Intermediate
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   Annual financial reporting requires comparing monthly sales against the
--   exact same calendar month from the prior year (YoY Growth).
-- PROBLEM STATEMENT:
--   Calculate Year-over-Year (YoY) revenue percentage using self-joins or LAG(12).
-- ============================================================================

DROP TABLE IF EXISTS annual_monthly_sales;
CREATE TABLE annual_monthly_sales (
    yr INT,
    mo INT,
    sales DECIMAL(10, 2),
    PRIMARY KEY (yr, mo)
);

INSERT INTO annual_monthly_sales VALUES
(2023, 1, 100000.00),
(2023, 2, 110000.00),
(2024, 1, 125000.00),
(2024, 2, 130000.00);

-- --- [SOLUTION QUERY] ---
SELECT 
    curr.yr,
    curr.mo,
    curr.sales AS current_year_sales,
    prev.sales AS prior_year_sales,
    ROUND(100.0 * (curr.sales - prev.sales) / prev.sales, 2) AS yoy_growth_pct
FROM annual_monthly_sales curr
LEFT JOIN annual_monthly_sales prev 
    ON curr.yr = prev.yr + 1 
    AND curr.mo = prev.mo
WHERE curr.yr = 2024
ORDER BY curr.mo ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 2
-- ASSERT: COL[yoy_growth_pct] = 25.0
