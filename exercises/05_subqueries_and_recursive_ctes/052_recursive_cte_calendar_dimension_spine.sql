-- ============================================================================
-- EXERCISE: 052_recursive_cte_calendar_dimension_spine.sql
-- MODULE:   05_subqueries_and_recursive_ctes
-- LEVEL:    Intermediate
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   Sales fact tables are sparse: if no sales occur on a weekend, no row exists.
--   When generating daily trend graphs, missing dates cause visual gaps.
-- PROBLEM STATEMENT:
--   Generate a continuous calendar date spine using a Recursive CTE, then
--   LEFT JOIN sales to ensure zero-revenue days display $0.00.
-- ============================================================================

DROP TABLE IF EXISTS daily_orders;
CREATE TABLE daily_orders (
    order_date TEXT PRIMARY KEY,
    amount DECIMAL(10, 2)
);

INSERT INTO daily_orders VALUES
('2024-05-01', 500.00),
('2024-05-04', 300.00); -- May 2 and May 3 are missing!

-- --- [SOLUTION QUERY] ---
WITH RECURSIVE date_spine AS (
    SELECT '2024-05-01' AS cal_date
    UNION ALL
    SELECT DATE(cal_date, '+1 day')
    FROM date_spine
    WHERE cal_date < '2024-05-04'
)
SELECT 
    s.cal_date,
    COALESCE(o.amount, 0.00) AS daily_revenue
FROM date_spine s
LEFT JOIN daily_orders o ON s.cal_date = o.order_date
ORDER BY s.cal_date ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 4
-- ASSERT: COL[daily_revenue] = 500.00
