-- ============================================================================
-- EXERCISE: 008_conditional_case_logic_and_nullif_coalesce.sql
-- MODULE:   01_core_sql_fundamentals
-- LEVEL:    Beginner / Foundation
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   E-commerce return rate analytics require calculating the ratio of returned
--   items to total sold items. If total sold is 0, the query will crash with a
--   fatal division-by-zero error.
-- PROBLEM STATEMENT:
--   Safely compute the return percentage using NULLIF to transform 0 denominators
--   into NULL, then COALESCE the resulting quotient to 0.00%.
-- ============================================================================

DROP TABLE IF EXISTS product_sales_stats;
CREATE TABLE product_sales_stats (
    product_id INT PRIMARY KEY,
    product_name VARCHAR(100),
    units_sold INT,
    units_returned INT
);

INSERT INTO product_sales_stats VALUES
(1, 'Wireless Mouse', 500, 25),
(2, 'Mechanical Keyboard', 200, 10),
(3, 'USB-C Cable', 0, 0),
(4, 'Noise Cancelling Headphones', 100, 15);

-- --- [SOLUTION QUERY] ---
SELECT 
    product_id,
    product_name,
    units_sold,
    units_returned,
    COALESCE(
        ROUND(CAST(units_returned AS FLOAT) / NULLIF(units_sold, 0) * 100.0, 2),
        0.00
    ) AS return_rate_pct
FROM product_sales_stats
ORDER BY product_id ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 4
-- ASSERT: COL[return_rate_pct] = 5.0
