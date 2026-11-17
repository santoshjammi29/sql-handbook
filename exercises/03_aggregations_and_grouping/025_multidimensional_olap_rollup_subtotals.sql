-- ============================================================================
-- EXERCISE: 025_multidimensional_olap_rollup_subtotals.sql
-- MODULE:   03_aggregations_and_grouping
-- LEVEL:    🟡<br>Intermediate
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ROLE:     Lead Data Architect & BI Warehouse Architect
-- ----------------------------------------------------------------------------
-- ARCHITECTURAL CONTEXT & SYSTEM TOPOLOGY:
--   Enterprise Retail Executive Reporting & Hierarchical Rollup Engine.
--   Financial executives require hierarchical subtotals across geographic dimensions:
--   [Global Total] -> [Region Subtotal] -> [Country Subtotal] -> [Store Detail].
--
-- BUSINESS CONTEXT:
--   1. ROLLUP generates N + 1 grouping levels for N hierarchical dimensions.
--   2. In PostgreSQL, Snowflake, and Spark SQL, 'GROUP BY ROLLUP (region, country, store)'
--      automates this in one pass.
--   3. In portable ANSI SQL and SQLite, this is modeled via explicit hierarchical unions
--      computing detailed leaf records, intermediate regional subtotals, and the grand total.
--
-- PROBLEM STATEMENT:
--   Produce a hierarchical sales rollup report displaying store details, regional subtotals,
--   and global totals with clean presentation labels.
-- ============================================================================

DROP TABLE IF EXISTS store_sales_summary;

CREATE TABLE store_sales_summary (
    region VARCHAR(30) NOT NULL,
    country VARCHAR(30) NOT NULL,
    store_name VARCHAR(50) NOT NULL,
    total_sales_usd DECIMAL(12, 2) NOT NULL
);

INSERT INTO store_sales_summary VALUES
('EMEA', 'Germany', 'Munich Flagship',   450000.00),
('EMEA', 'Germany', 'Berlin Mall',       320000.00),
('EMEA', 'France',  'Paris Champs',      580000.00),
('AMER', 'USA',     'NYC 5th Avenue',    920000.00),
('AMER', 'USA',     'SF Market St',      610000.00),
('AMER', 'Canada',  'Toronto Eaton',     340000.00);

-- --- [SOLUTION QUERY] ---
-- Hierarchical ROLLUP emulation:
-- Level 1: [Region, Country, Store] (Detailed Grain)
-- Level 2: [Region, Country, ALL]   (Country Subtotal)
-- Level 3: [Region, ALL, ALL]       (Region Subtotal)
-- Level 4: [ALL, ALL, ALL]          (Grand Global Total)
WITH detailed_leaf AS (
    SELECT region, country, store_name, SUM(total_sales_usd) AS sales_usd, 1 AS hierarchy_level
    FROM store_sales_summary
    GROUP BY region, country, store_name
),
country_subtotals AS (
    SELECT region, country, '--- ALL STORES ---' AS store_name, SUM(total_sales_usd) AS sales_usd, 2 AS hierarchy_level
    FROM store_sales_summary
    GROUP BY region, country
),
region_subtotals AS (
    SELECT region, '--- ALL COUNTRIES ---' AS country, '--- ALL STORES ---' AS store_name, SUM(total_sales_usd) AS sales_usd, 3 AS hierarchy_level
    FROM store_sales_summary
    GROUP BY region
),
grand_total AS (
    SELECT '--- GLOBAL TOTAL ---' AS region, '--- ALL COUNTRIES ---' AS country, '--- ALL STORES ---' AS store_name, SUM(total_sales_usd) AS sales_usd, 4 AS hierarchy_level
    FROM store_sales_summary
)
SELECT region, country, store_name, sales_usd, hierarchy_level
FROM (
    SELECT * FROM detailed_leaf
    UNION ALL
    SELECT * FROM country_subtotals
    UNION ALL
    SELECT * FROM region_subtotals
    UNION ALL
    SELECT * FROM grand_total
)
ORDER BY 
    CASE WHEN region LIKE '---%' THEN 1 ELSE 0 END ASC,
    region ASC,
    CASE WHEN country LIKE '---%' THEN 1 ELSE 0 END ASC,
    country ASC,
    hierarchy_level ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 13
-- ASSERT: COL[region] = AMER
