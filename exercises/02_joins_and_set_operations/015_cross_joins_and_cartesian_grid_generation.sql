-- ============================================================================
-- EXERCISE: 015_cross_joins_and_cartesian_grid_generation.sql
-- MODULE:   02_joins_and_set_operations
-- LEVEL:    Beginner / Foundation
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   Retail store analytics requires generating a continuous reporting grid of
--   all stores for all dates in a promo week, even if a store recorded 0 sales.
-- PROBLEM STATEMENT:
--   Generate a complete Cartesian grid using CROSS JOIN, then LEFT JOIN actual
--   sales to impute 0 for missing store-date combinations.
-- ============================================================================

DROP TABLE IF EXISTS store_sales;
DROP TABLE IF EXISTS dim_stores;
DROP TABLE IF EXISTS dim_dates;

CREATE TABLE dim_stores (
    store_id INT PRIMARY KEY,
    store_name VARCHAR(50)
);

CREATE TABLE dim_dates (
    calendar_date TEXT PRIMARY KEY
);

CREATE TABLE store_sales (
    store_id INT,
    calendar_date TEXT,
    revenue DECIMAL(10, 2),
    PRIMARY KEY (store_id, calendar_date)
);

INSERT INTO dim_stores VALUES (1, 'Downtown'), (2, 'Uptown');
INSERT INTO dim_dates VALUES ('2024-06-01'), ('2024-06-02');
INSERT INTO store_sales VALUES (1, '2024-06-01', 1200.00), (2, '2024-06-02', 1800.00);

-- --- [SOLUTION QUERY] ---
SELECT 
    s.store_id,
    s.store_name,
    d.calendar_date,
    COALESCE(sales.revenue, 0.00) AS daily_revenue
FROM dim_stores s
CROSS JOIN dim_dates d
LEFT JOIN store_sales sales 
    ON s.store_id = sales.store_id 
    AND d.calendar_date = sales.calendar_date
ORDER BY s.store_id ASC, d.calendar_date ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 4
-- ASSERT: COL[daily_revenue] = 1200.00
