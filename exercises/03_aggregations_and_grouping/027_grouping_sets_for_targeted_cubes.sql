-- ============================================================================
-- EXERCISE: 027_grouping_sets_for_targeted_cubes.sql
-- MODULE:   03_aggregations_and_grouping
-- LEVEL:    Advanced
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   Management requires sales reporting at the Brand level, and at the
--   (Country, Region) level, but explicitly does NOT want a full CUBE.
-- PROBLEM STATEMENT:
--   Implement targeted grouping sets to aggregate specific subsets of dimensions.
-- ============================================================================

DROP TABLE IF EXISTS global_sales;
CREATE TABLE global_sales (
    country VARCHAR(50),
    region VARCHAR(50),
    brand VARCHAR(50),
    units INT
);

INSERT INTO global_sales VALUES
('USA', 'East', 'BrandA', 100),
('USA', 'West', 'BrandA', 150),
('USA', 'East', 'BrandB', 80),
('UK',  'South', 'BrandA', 90);

-- --- [SOLUTION QUERY] ---
-- Emulating GROUPING SETS ((country, region), (brand))
SELECT country, region, 'ALL_BRANDS' AS brand, SUM(units) AS total_units
FROM global_sales
GROUP BY country, region
UNION ALL
SELECT 'ALL_COUNTRIES' AS country, 'ALL_REGIONS' AS region, brand, SUM(units) AS total_units
FROM global_sales
GROUP BY brand
ORDER BY country ASC, brand ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 5
-- ASSERT: COL[total_units] = 340
