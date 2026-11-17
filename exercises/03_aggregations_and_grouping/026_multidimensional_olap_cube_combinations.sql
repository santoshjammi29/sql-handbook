-- ============================================================================
-- EXERCISE: 026_multidimensional_olap_cube_combinations.sql
-- MODULE:   03_aggregations_and_grouping
-- LEVEL:    Advanced
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   Merchandise inventory analytics requires examining revenue across all
--   cross-combinations of Product Category and Store Channel.
-- PROBLEM STATEMENT:
--   Emulate multidimensional OLAP CUBE generating (Category, Channel),
--   (Category, ALL), (ALL, Channel), and (ALL, ALL).
-- ============================================================================

DROP TABLE IF EXISTS channel_sales;
CREATE TABLE channel_sales (
    category VARCHAR(50),
    channel VARCHAR(50),
    revenue DECIMAL(10, 2)
);

INSERT INTO channel_sales VALUES
('Electronics', 'Online', 50000.00),
('Electronics', 'Retail', 30000.00),
('Apparel',     'Online', 20000.00),
('Apparel',     'Retail', 15000.00);

-- --- [SOLUTION QUERY] ---
-- Portable CUBE emulation
SELECT category, channel, SUM(revenue) AS total_revenue FROM channel_sales GROUP BY category, channel
UNION ALL
SELECT category, 'ALL_CHANNELS', SUM(revenue) FROM channel_sales GROUP BY category
UNION ALL
SELECT 'ALL_CATEGORIES', channel, SUM(revenue) FROM channel_sales GROUP BY channel
UNION ALL
SELECT 'ALL_CATEGORIES', 'ALL_CHANNELS', SUM(revenue) FROM channel_sales
ORDER BY category ASC, channel ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 9
-- ASSERT: COL[total_revenue] = 35000.00
