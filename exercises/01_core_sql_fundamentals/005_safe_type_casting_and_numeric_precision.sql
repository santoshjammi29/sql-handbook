-- ============================================================================
-- EXERCISE: 005_safe_type_casting_and_numeric_precision.sql
-- MODULE:   01_core_sql_fundamentals
-- LEVEL:    Intermediate
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   A financial reporting service computes portfolio performance percentages.
--   Raw input fields contain corrupted string entries ('N/A', 'PENDING', empty)
--   and integers. Integer division truncates percentages to 0, and invalid casts
--   crash the overnight ETL batch.
-- PROBLEM STATEMENT:
--   Implement safe type casting that guards against non-numeric corruptions and
--   prevents integer division truncation without throwing fatal exceptions.
-- ============================================================================

DROP TABLE IF EXISTS raw_portfolio_feed;
CREATE TABLE raw_portfolio_feed (
    holding_id INT PRIMARY KEY,
    shares_count INT,
    total_shares INT,
    raw_valuation VARCHAR(50)
);

INSERT INTO raw_portfolio_feed VALUES
(1, 25, 100, '5000.50'),
(2, 40, 80, 'N/A'),
(3, 10, 10, '1200.00'),
(4, 5, 50, ''),
(5, 0, 100, '0.00');

-- --- [SOLUTION QUERY] ---
-- Demonstrates floating cast to prevent int truncation and safe conversion logic
SELECT 
    holding_id,
    shares_count,
    total_shares,
    -- Prevent integer division (25/100 = 0 in SQL without float conversion)
    ROUND(CAST(shares_count AS FLOAT) / NULLIF(total_shares, 0) * 100.0, 2) AS ownership_pct,
    -- Safe parse: if raw_valuation is numeric string, cast; otherwise default to 0.00
    CASE 
        WHEN raw_valuation GLOB '[0-9]*.[0-9]*' OR raw_valuation GLOB '[0-9]*'
        THEN CAST(raw_valuation AS DECIMAL(10, 2))
        ELSE 0.00
    END AS sanitized_valuation
FROM raw_portfolio_feed
ORDER BY holding_id ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 5
-- ASSERT: COL[ownership_pct] = 25.0
