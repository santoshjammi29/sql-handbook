-- ============================================================================
-- EXERCISE: 056_kimball_star_schema_fact_dimension_design.sql
-- MODULE:   06_data_modeling_and_scd
-- LEVEL:    Beginner / Foundation
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   Enterprise retail reporting uses Kimball Dimensional Modeling: a central
--   Fact table containing numeric additive facts and foreign surrogate keys,
--   surrounded by conformed Dimension tables containing descriptive attributes.
-- PROBLEM STATEMENT:
--   Query a Star Schema joining Fact Sales to Date, Store, and Product dimensions.
-- ============================================================================

DROP TABLE IF EXISTS fact_sales;
DROP TABLE IF EXISTS dim_date;
DROP TABLE IF EXISTS dim_product;
DROP TABLE IF EXISTS dim_store;

CREATE TABLE dim_date (date_key INT PRIMARY KEY, full_date TEXT, calendar_year INT);
CREATE TABLE dim_product (product_key INT PRIMARY KEY, product_name VARCHAR(50), category VARCHAR(50));
CREATE TABLE dim_store (store_key INT PRIMARY KEY, store_name VARCHAR(50), city VARCHAR(50));

CREATE TABLE fact_sales (
    sale_id INT PRIMARY KEY,
    date_key INT,
    product_key INT,
    store_key INT,
    quantity INT,
    revenue DECIMAL(10, 2)
);

INSERT INTO dim_date VALUES (20240501, '2024-05-01', 2024);
INSERT INTO dim_product VALUES (1, '4K Monitor', 'Hardware');
INSERT INTO dim_store VALUES (10, 'Central Store', 'New York');
INSERT INTO fact_sales VALUES (1001, 20240501, 1, 10, 2, 700.00);

-- --- [SOLUTION QUERY] ---
SELECT 
    d.calendar_year,
    s.city,
    p.category,
    p.product_name,
    SUM(f.quantity) AS total_units_sold,
    SUM(f.revenue)  AS total_gross_revenue
FROM fact_sales f
JOIN dim_date d ON f.date_key = d.date_key
JOIN dim_store s ON f.store_key = s.store_key
JOIN dim_product p ON f.product_key = p.product_key
GROUP BY d.calendar_year, s.city, p.category, p.product_name;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 1
-- ASSERT: COL[total_gross_revenue] = 700.00
