-- ============================================================================
-- EXERCISE: 041_running_peak_and_maximum_drawdown.sql
-- MODULE:   04_window_functions_mastery
-- LEVEL:    🔴<br>Advanced
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ROLE:     Lead Quantitative Portfolio Risk Architect
-- ----------------------------------------------------------------------------
-- ARCHITECTURAL CONTEXT & SYSTEM TOPOLOGY:
--   Quantitative Hedge Fund Portfolio Risk & Peak Drawdown Engine.
--   Measuring Maximum Drawdown (MDD): the maximum observed loss from a historical
--   peak to a trough of a portfolio Net Asset Value (NAV).
--
-- BUSINESS CONTEXT:
--   Enterprise analytical engine optimization for 041 running peak and maximum drawdown.
--   Ensuring strict grain integrity, distributed performance, and deterministic results.
--
-- PROBLEM STATEMENT:
--   Write a production-grade SQL query fulfilling the architectural requirements for 041 running peak and maximum drawdown.
-- ============================================================================

DROP TABLE IF EXISTS fund_nav_daily;

CREATE TABLE fund_nav_daily (
    trade_date TEXT PRIMARY KEY,
    fund_ticker VARCHAR(10) NOT NULL,
    nav_per_share DECIMAL(12, 4) NOT NULL
);

INSERT INTO fund_nav_daily VALUES
('2024-05-01', 'ALPHA_FUND', 100.0000),
('2024-05-02', 'ALPHA_FUND', 105.0000), -- Peak 1 (105.00)
('2024-05-03', 'ALPHA_FUND',  98.0000), -- Drawdown -7.00 (-6.67%)
('2024-05-04', 'ALPHA_FUND',  92.0000), -- Drawdown -13.00 (-12.38%)
('2024-05-05', 'ALPHA_FUND', 108.0000), -- New Peak 2 (108.00)
('2024-05-06', 'ALPHA_FUND', 104.0000); -- Drawdown -4.00

-- --- [SOLUTION QUERY] ---
WITH running_peaks AS (
    SELECT 
        trade_date,
        fund_ticker,
        nav_per_share,
        -- Running high watermark peak
        MAX(nav_per_share) OVER (
            PARTITION BY fund_ticker 
            ORDER BY trade_date ASC
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS historical_peak_nav
    FROM fund_nav_daily
),
drawdown_calculations AS (
    SELECT 
        trade_date,
        fund_ticker,
        nav_per_share,
        historical_peak_nav,
        ROUND(nav_per_share - historical_peak_nav, 4) AS dollar_drawdown,
        ROUND(((nav_per_share - historical_peak_nav) / historical_peak_nav) * 100.0, 2) AS drawdown_pct
    FROM running_peaks
)
SELECT 
    trade_date,
    fund_ticker,
    nav_per_share,
    historical_peak_nav,
    dollar_drawdown,
    drawdown_pct,
    CASE 
        WHEN nav_per_share >= historical_peak_nav THEN 'ALL_TIME_HIGH_PEAK'
        WHEN drawdown_pct <= -10.0 THEN 'SEVERE_CORRECTION_DRAWDOWN'
        ELSE 'MINOR_PULLBACK'
    END AS risk_condition
FROM drawdown_calculations
ORDER BY trade_date ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 6
-- ASSERT: COL[trade_date] = 2024-05-01
