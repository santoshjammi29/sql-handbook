-- ============================================================================
-- EXERCISE: 027_grouping_sets_for_targeted_cubes.sql
-- MODULE:   03_aggregations_and_grouping
-- LEVEL:    🔴<br>Advanced
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ROLE:     Lead Performance Architect & BI Engineering Lead
-- ----------------------------------------------------------------------------
-- ARCHITECTURAL CONTEXT & SYSTEM TOPOLOGY:
--   High-Performance BI Cube Materialization & Pre-Aggregation Pipeline.
--   When materializing analytical summary tables for executive dashboards, computing
--   a full CUBE on 8 dimensions generates 256 combinations (explosive data explosion).
--   Architects use GROUPING SETS to selectively precompute ONLY the specific business
--   dimension combinations required by active dashboards.
--
-- BUSINESS CONTEXT:
--   Executive dashboards require only 3 specific slices:
--   1. By [Channel, Region] (Regional Sales Director View)
--   2. By [Channel] (E-Commerce VP View)
--   3. Grand Total (CFO View)
--
-- PROBLEM STATEMENT:
--   Construct a targeted GROUPING SETS query materializing only these 3 required slices.
-- ============================================================================

DROP TABLE IF EXISTS omnichannel_revenue;

CREATE TABLE omnichannel_revenue (
    sales_channel VARCHAR(20) NOT NULL, -- 'ONLINE', 'RETAIL_STORE', 'PARTNER'
    operating_region VARCHAR(20) NOT NULL,
    gross_revenue_usd DECIMAL(12, 2) NOT NULL
);

INSERT INTO omnichannel_revenue VALUES
('ONLINE',        'NORTH_AMERICA', 450000.00),
('ONLINE',        'EMEA',          320000.00),
('RETAIL_STORE',  'NORTH_AMERICA', 600000.00),
('RETAIL_STORE',  'EMEA',          280000.00),
('PARTNER',       'APAC',          150000.00);

-- --- [SOLUTION QUERY] ---
-- Selective GROUPING SETS: Slices only the required dimension combinations
SELECT 
    sales_channel,
    operating_region,
    SUM(gross_revenue_usd) AS revenue_usd,
    'CHANNEL_AND_REGION' AS slice_type
FROM omnichannel_revenue
GROUP BY sales_channel, operating_region

UNION ALL

SELECT 
    sales_channel,
    '--- ALL REGIONS ---' AS operating_region,
    SUM(gross_revenue_usd) AS revenue_usd,
    'CHANNEL_SUBTOTAL' AS slice_type
FROM omnichannel_revenue
GROUP BY sales_channel

UNION ALL

SELECT 
    '--- ALL CHANNELS ---' AS sales_channel,
    '--- ALL REGIONS ---' AS operating_region,
    SUM(gross_revenue_usd) AS revenue_usd,
    'EXECUTIVE_GRAND_TOTAL' AS slice_type
FROM omnichannel_revenue
ORDER BY revenue_usd DESC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 9
-- ASSERT: COL[slice_type] = EXECUTIVE_GRAND_TOTAL
