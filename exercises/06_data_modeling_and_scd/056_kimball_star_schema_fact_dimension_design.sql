-- ============================================================================
-- EXERCISE: 056_kimball_star_schema_fact_dimension_design.sql
-- MODULE:   06_data_modeling_and_scd
-- LEVEL:    🟢<br>Beginner
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ROLE:     Lead Enterprise Data Architect & Kimball Modeling Specialist
-- ----------------------------------------------------------------------------
-- ARCHITECTURAL CONTEXT & SYSTEM TOPOLOGY:
--   Enterprise Retail Omnichannel Sales Data Mart.
--   Implementing Ralph Kimball's classic Dimensional Modeling architecture:
--   a centralized Fact table containing numeric additive facts and foreign surrogate keys,
--   surrounded by conformed Dimension tables (Date, Store, Customer, Product).
--
-- BUSINESS CONTEXT:
--   Enterprise analytical engine optimization for 056 kimball star schema fact dimension design.
--   Ensuring strict grain integrity, distributed performance, and deterministic results.
--
-- PROBLEM STATEMENT:
--   Write a production-grade SQL query fulfilling the architectural requirements for 056 kimball star schema fact dimension design.
-- ============================================================================

DROP TABLE IF EXISTS fact_retail_sales;
DROP TABLE IF EXISTS dim_product_conformed;
DROP TABLE IF EXISTS dim_store_conformed;
DROP TABLE IF EXISTS dim_date_conformed;

CREATE TABLE dim_date_conformed (
    date_key INT PRIMARY KEY,
    full_date TEXT NOT NULL,
    fiscal_year INT NOT NULL,
    fiscal_quarter VARCHAR(5) NOT NULL
);

CREATE TABLE dim_store_conformed (
    store_key INT PRIMARY KEY,
    store_code VARCHAR(20) NOT NULL,
    store_name VARCHAR(50) NOT NULL,
    market_region VARCHAR(30) NOT NULL
);

CREATE TABLE dim_product_conformed (
    product_key INT PRIMARY KEY,
    sku_code VARCHAR(20) NOT NULL,
    product_category VARCHAR(30) NOT NULL,
    unit_cost_usd DECIMAL(10, 2) NOT NULL
);

CREATE TABLE fact_retail_sales (
    sale_id VARCHAR(32) PRIMARY KEY,
    date_key INT NOT NULL,
    store_key INT NOT NULL,
    product_key INT NOT NULL,
    quantity_sold INT NOT NULL,
    gross_revenue_usd DECIMAL(12, 2) NOT NULL,
    discount_usd DECIMAL(12, 2) NOT NULL,
    FOREIGN KEY (date_key) REFERENCES dim_date_conformed(date_key),
    FOREIGN KEY (store_key) REFERENCES dim_store_conformed(store_key),
    FOREIGN KEY (product_key) REFERENCES dim_product_conformed(product_key)
);

INSERT INTO dim_date_conformed VALUES
(20240501, '2024-05-01', 2024, 'Q2'),
(20240502, '2024-05-02', 2024, 'Q2');

INSERT INTO dim_store_conformed VALUES
(101, 'STR-NY', 'Manhattan 5th Ave', 'NORTH_AMERICA'),
(102, 'STR-LDN', 'London Oxford St', 'EMEA');

INSERT INTO dim_product_conformed VALUES
(501, 'SKU-LAP', 'HARDWARE', 800.00),
(502, 'SKU-MON', 'HARDWARE', 250.00),
(503, 'SKU-ACC', 'ACCESSORIES', 20.00);

INSERT INTO fact_retail_sales VALUES
('S-01', 20240501, 101, 501, 2, 2400.00, 200.00),
('S-02', 20240501, 101, 502, 5, 2000.00, 100.00),
('S-03', 20240502, 102, 501, 1, 1300.00, 50.00),
('S-04', 20240502, 102, 503, 10, 500.00, 0.00);

-- --- [SOLUTION QUERY] ---
-- Kimball Star Schema multi-dimensional OLAP aggregation
SELECT 
    d.fiscal_year,
    d.fiscal_quarter,
    s.market_region,
    s.store_name,
    p.product_category,
    SUM(f.quantity_sold) AS total_units_sold,
    SUM(f.gross_revenue_usd) AS gross_sales_usd,
    SUM(f.discount_usd) AS total_discounts_usd,
    ROUND(SUM(f.gross_revenue_usd - f.discount_usd), 2) AS net_sales_usd,
    ROUND(SUM(f.quantity_sold * p.unit_cost_usd), 2) AS total_cogs_usd,
    ROUND(SUM(f.gross_revenue_usd - f.discount_usd) - SUM(f.quantity_sold * p.unit_cost_usd), 2) AS gross_profit_usd
FROM fact_retail_sales f
INNER JOIN dim_date_conformed d ON f.date_key = d.date_key
INNER JOIN dim_store_conformed s ON f.store_key = s.store_key
INNER JOIN dim_product_conformed p ON f.product_key = p.product_key
GROUP BY 
    d.fiscal_year,
    d.fiscal_quarter,
    s.market_region,
    s.store_name,
    p.product_category
ORDER BY net_sales_usd DESC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 3
-- ASSERT: COL[market_region] = NORTH_AMERICA
