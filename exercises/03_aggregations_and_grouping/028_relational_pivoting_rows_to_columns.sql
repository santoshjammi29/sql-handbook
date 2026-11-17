-- ============================================================================
-- EXERCISE: 028_relational_pivoting_rows_to_columns.sql
-- MODULE:   03_aggregations_and_grouping
-- LEVEL:    Intermediate
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   Monthly financial summary tables store sales vertically by month.
--   Executive reporting presentations require pivoting months into horizontal
--   columns (Jan, Feb, Mar) per product.
-- PROBLEM STATEMENT:
--   Pivot relational rows into columns using conditional aggregation.
-- ============================================================================

DROP TABLE IF EXISTS monthly_product_revenue;
CREATE TABLE monthly_product_revenue (
    product_name VARCHAR(50),
    month_name VARCHAR(10),
    revenue DECIMAL(10, 2)
);

INSERT INTO monthly_product_revenue VALUES
('Laptop', 'Jan', 10000.00),
('Laptop', 'Feb', 12000.00),
('Laptop', 'Mar', 15000.00),
('Phone',  'Jan', 8000.00),
('Phone',  'Feb', 9500.00),
('Phone',  'Mar', 11000.00);

-- --- [SOLUTION QUERY] ---
SELECT 
    product_name,
    SUM(CASE WHEN month_name = 'Jan' THEN revenue ELSE 0.00 END) AS jan_rev,
    SUM(CASE WHEN month_name = 'Feb' THEN revenue ELSE 0.00 END) AS feb_rev,
    SUM(CASE WHEN month_name = 'Mar' THEN revenue ELSE 0.00 END) AS mar_rev,
    SUM(revenue) AS q1_total_rev
FROM monthly_product_revenue
GROUP BY product_name
ORDER BY product_name ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 2
-- ASSERT: COL[jan_rev] = 10000.00
