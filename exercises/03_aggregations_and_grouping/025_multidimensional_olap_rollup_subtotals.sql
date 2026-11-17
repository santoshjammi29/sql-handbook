-- ============================================================================
-- EXERCISE: 025_multidimensional_olap_rollup_subtotals.sql
-- MODULE:   03_aggregations_and_grouping
-- LEVEL:    Advanced
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   Financial quarterly reporting requires displaying sales subtotals by Year,
--   subtotals by Year and Quarter, and the Grand Total for all records.
-- PROBLEM STATEMENT:
--   Emulate multidimensional OLAP ROLLUP using unioned grouping sets for
--   universal cross-database engine portability.
-- ============================================================================

DROP TABLE IF EXISTS fiscal_sales;
CREATE TABLE fiscal_sales (
    fiscal_year INT,
    fiscal_quarter VARCHAR(5),
    revenue DECIMAL(10, 2)
);

INSERT INTO fiscal_sales VALUES
(2023, 'Q1', 10000.00),
(2023, 'Q2', 15000.00),
(2024, 'Q1', 20000.00),
(2024, 'Q2', 25000.00);

-- --- [SOLUTION QUERY] ---
-- Emulating ROLLUP(fiscal_year, fiscal_quarter)
SELECT 
    CAST(fiscal_year AS VARCHAR) AS yr,
    fiscal_quarter AS qtr,
    SUM(revenue)   AS total_rev
FROM fiscal_sales
GROUP BY fiscal_year, fiscal_quarter

UNION ALL

SELECT 
    CAST(fiscal_year AS VARCHAR) AS yr,
    'SUBTOTAL'     AS qtr,
    SUM(revenue)   AS total_rev
FROM fiscal_sales
GROUP BY fiscal_year

UNION ALL

SELECT 
    'GRAND TOTAL'  AS yr,
    'ALL'          AS qtr,
    SUM(revenue)   AS total_rev
FROM fiscal_sales
ORDER BY yr ASC, qtr ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 7
-- ASSERT: COL[total_rev] = 25000.00
