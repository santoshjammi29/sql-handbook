-- ============================================================================
-- EXERCISE: 026_multidimensional_olap_cube_combinations.sql
-- MODULE:   03_aggregations_and_grouping
-- LEVEL:    🟡<br>Intermediate
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ROLE:     Lead Supply Chain Architect & Inventory Optimization Lead
-- ----------------------------------------------------------------------------
-- ARCHITECTURAL CONTEXT & SYSTEM TOPOLOGY:
--   Multi-Dimensional Inventory Position & Warehouse Logistics Matrix.
--   Supply chain planning requires analyzing total inventory value across all
--   permutations of dimensions: [Supplier × Fulfillment Center × Product Category].
--
-- BUSINESS CONTEXT:
--   1. CUBE computes 2^N combinations for N dimensions.
--   2. Unlike ROLLUP (which follows a strict hierarchy), CUBE calculates all cross-dimensional
--      slices: by Supplier alone, by Warehouse alone, by Category alone, and their pairs.
--
-- PROBLEM STATEMENT:
--   Compute the multi-dimensional inventory valuation cube across [Warehouse × Category]
--   including all 4 combinations (Both, Warehouse Only, Category Only, Grand Total).
-- ============================================================================

DROP TABLE IF EXISTS warehouse_inventory;

CREATE TABLE warehouse_inventory (
    warehouse_code VARCHAR(20) NOT NULL,
    category_name VARCHAR(30) NOT NULL,
    units_on_hand INT NOT NULL,
    unit_cost_usd DECIMAL(10, 2) NOT NULL
);

INSERT INTO warehouse_inventory VALUES
('WH-EAST', 'ELECTRONICS', 150, 400.00), -- 60,000
('WH-EAST', 'APPAREL',     500,  30.00), -- 15,000
('WH-WEST', 'ELECTRONICS', 200, 380.00), -- 76,000
('WH-WEST', 'HOME_GOODS',  300,  50.00); -- 15,000

-- --- [SOLUTION QUERY] ---
-- Multi-dimensional CUBE emulation:
-- Slice 1: (Warehouse, Category)
-- Slice 2: (Warehouse, ALL)
-- Slice 3: (ALL, Category)
-- Slice 4: (ALL, ALL)
SELECT 
    warehouse_code,
    category_name,
    SUM(units_on_hand) AS total_units,
    ROUND(SUM(units_on_hand * unit_cost_usd), 2) AS total_valuation_usd,
    'WAREHOUSE_AND_CATEGORY' AS aggregation_slice
FROM warehouse_inventory
GROUP BY warehouse_code, category_name

UNION ALL

SELECT 
    warehouse_code,
    '--- ALL CATEGORIES ---' AS category_name,
    SUM(units_on_hand) AS total_units,
    ROUND(SUM(units_on_hand * unit_cost_usd), 2) AS total_valuation_usd,
    'WAREHOUSE_SUBTOTAL' AS aggregation_slice
FROM warehouse_inventory
GROUP BY warehouse_code

UNION ALL

SELECT 
    '--- ALL WAREHOUSES ---' AS warehouse_code,
    category_name,
    SUM(units_on_hand) AS total_units,
    ROUND(SUM(units_on_hand * unit_cost_usd), 2) AS total_valuation_usd,
    'CATEGORY_SUBTOTAL' AS aggregation_slice
FROM warehouse_inventory
GROUP BY category_name

UNION ALL

SELECT 
    '--- ALL WAREHOUSES ---' AS warehouse_code,
    '--- ALL CATEGORIES ---' AS category_name,
    SUM(units_on_hand) AS total_units,
    ROUND(SUM(units_on_hand * unit_cost_usd), 2) AS total_valuation_usd,
    'GRAND_TOTAL' AS aggregation_slice
FROM warehouse_inventory
ORDER BY total_valuation_usd DESC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 10
-- ASSERT: COL[aggregation_slice] = GRAND_TOTAL
