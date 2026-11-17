-- ============================================================================
-- EXERCISE: 029_relational_unpivoting_columns_to_rows.sql
-- MODULE:   03_aggregations_and_grouping
-- LEVEL:    Intermediate
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   A legacy spreadsheet ingest landed data with quarters as columns
--   (q1_sales, q2_sales, q3_sales). The Lakehouse Kimball schema requires
--   normalizing this into a tall Fact table.
-- PROBLEM STATEMENT:
--   Unpivot wide columns into relational rows using CROSS JOIN / UNION.
-- ============================================================================

DROP TABLE IF EXISTS wide_sales_report;
CREATE TABLE wide_sales_report (
    region VARCHAR(50) PRIMARY KEY,
    q1_sales DECIMAL(10, 2),
    q2_sales DECIMAL(10, 2),
    q3_sales DECIMAL(10, 2)
);

INSERT INTO wide_sales_report VALUES
('North America', 50000.00, 65000.00, 70000.00),
('Europe',        30000.00, 35000.00, 42000.00);

-- --- [SOLUTION QUERY] ---
SELECT region, 'Q1' AS quarter, q1_sales AS sales_amount FROM wide_sales_report
UNION ALL
SELECT region, 'Q2' AS quarter, q2_sales AS sales_amount FROM wide_sales_report
UNION ALL
SELECT region, 'Q3' AS quarter, q3_sales AS sales_amount FROM wide_sales_report
ORDER BY region ASC, quarter ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 6
-- ASSERT: COL[sales_amount] = 30000.00
