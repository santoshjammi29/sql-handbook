-- ============================================================================
-- EXERCISE: 041_running_peak_and_maximum_drawdown.sql
-- MODULE:   04_window_functions_mastery
-- LEVEL:    Advanced
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   Hedge fund risk systems calculate Maximum Drawdown (MDD) — the maximum peak-to-trough
--   percentage drop in asset portfolio value before a new peak is reached.
-- PROBLEM STATEMENT:
--   Calculate running peak and drawdown percentage using MAX() OVER (...) and arithmetic.
-- ============================================================================

DROP TABLE IF EXISTS portfolio_nav;
CREATE TABLE portfolio_nav (
    nav_date TEXT PRIMARY KEY,
    portfolio_value DECIMAL(10, 2)
);

INSERT INTO portfolio_nav VALUES
('2024-01-01', 10000.00),
('2024-01-02', 12000.00), -- Peak 1
('2024-01-03', 9000.00),  -- Drop 25% from 12k
('2024-01-04', 15000.00), -- New Peak 2
('2024-01-05', 13500.00); -- Drop 10% from 15k

-- --- [SOLUTION QUERY] ---
WITH peaks AS (
    SELECT 
        nav_date,
        portfolio_value,
        MAX(portfolio_value) OVER (
            ORDER BY nav_date ASC
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS running_peak
    FROM portfolio_nav
)
SELECT 
    nav_date,
    portfolio_value,
    running_peak,
    ROUND(100.0 * (portfolio_value - running_peak) / running_peak, 2) AS drawdown_pct
FROM peaks
ORDER BY nav_date ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 5
-- ASSERT: COL[drawdown_pct] = 0.0
