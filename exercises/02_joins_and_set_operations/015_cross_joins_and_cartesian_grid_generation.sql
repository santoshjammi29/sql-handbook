-- ============================================================================
-- EXERCISE: 015_cross_joins_and_cartesian_grid_generation.sql
-- MODULE:   02_joins_and_set_operations
-- LEVEL:    🟢<br>Beginner
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ROLE:     Lead Machine Learning Data Engineer & Retail Demand Modeler
-- ----------------------------------------------------------------------------
-- ARCHITECTURAL CONTEXT & SYSTEM TOPOLOGY:
--   Retail Machine Learning Demand Forecasting Feature Store.
--   Time-series forecasting models (ARIMA, Prophet, XGBoost) require a continuous,
--   dense grid of all Stores × Products × Dates. If a store sells 0 units of a product
--   on Tuesday, raw POS transaction logs record NO row. If sparse data is fed to ML
--   models, the time series breaks and forecasting algorithms fail.
--
-- BUSINESS CONTEXT:
--   Generate a dense synthetic reporting matrix across 2 regional fulfillment hubs,
--   3 flagship SKUs, and a 3-day promotional window (2 × 3 × 3 = 18 total grid cells).
--   Left join against actual sales so missing dates are explicitly imputed with 0.00.
--
-- PROBLEM STATEMENT:
--   Implement an enterprise-grade query to resolve 015 cross joins and cartesian grid generation.
-- ============================================================================

DROP TABLE IF EXISTS actual_pos_sales;
DROP TABLE IF EXISTS dim_stores;
DROP TABLE IF EXISTS dim_products;
DROP TABLE IF EXISTS dim_dates;

CREATE TABLE dim_stores (store_id VARCHAR(10) PRIMARY KEY, store_name VARCHAR(50));
CREATE TABLE dim_products (sku_id VARCHAR(10) PRIMARY KEY, product_name VARCHAR(50));
CREATE TABLE dim_dates (date_key TEXT PRIMARY KEY);

CREATE TABLE actual_pos_sales (
    store_id VARCHAR(10),
    sku_id VARCHAR(10),
    sale_date TEXT,
    units_sold INT,
    revenue_usd DECIMAL(10, 2),
    PRIMARY KEY (store_id, sku_id, sale_date)
);

INSERT INTO dim_stores VALUES ('STR-01', 'Manhattan Flagship'), ('STR-02', 'Brooklyn Fulfillment');
INSERT INTO dim_products VALUES ('SKU-10', 'Noise-Cancelling Headphones'), ('SKU-20', 'Mechanical Keyboard'), ('SKU-30', 'USB-C Docking Station');
INSERT INTO dim_dates VALUES ('2024-05-01'), ('2024-05-02'), ('2024-05-03');

-- Sparse actual sales: Only 3 combinations recorded sales!
INSERT INTO actual_pos_sales VALUES
('STR-01', 'SKU-10', '2024-05-01', 5, 1250.00),
('STR-01', 'SKU-20', '2024-05-01', 3, 450.00),
('STR-02', 'SKU-10', '2024-05-03', 2, 500.00);

-- --- [SOLUTION QUERY] ---
-- Production dense grid generation:
-- 1. CROSS JOIN store × product × date generates 18 theoretical combinations
-- 2. LEFT JOIN against sparse sales imputes 0 for non-active sales days
WITH dense_scaffold AS (
    SELECT 
        s.store_id,
        s.store_name,
        p.sku_id,
        p.product_name,
        d.date_key AS reporting_date
    FROM dim_stores s
    CROSS JOIN dim_products p
    CROSS JOIN dim_dates d
)
SELECT 
    grid.reporting_date,
    grid.store_id,
    grid.store_name,
    grid.sku_id,
    grid.product_name,
    COALESCE(pos.units_sold, 0) AS units_sold,
    COALESCE(pos.revenue_usd, 0.00) AS revenue_usd,
    CASE WHEN pos.units_sold IS NULL THEN 1 ELSE 0 END AS is_imputed_zero
FROM dense_scaffold grid
LEFT JOIN actual_pos_sales pos 
    ON grid.store_id = pos.store_id 
    AND grid.sku_id = pos.sku_id 
    AND grid.reporting_date = pos.sale_date
ORDER BY grid.reporting_date ASC, grid.store_id ASC, grid.sku_id ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 18
-- ASSERT: COL[store_id] = STR-01
