-- ============================================================================
-- EXERCISE: 021_count_semantics_star_one_column.sql
-- MODULE:   03_aggregations_and_grouping
-- LEVEL:    Beginner / Foundation
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   A data quality dashboard needs to report total rows, populated rows,
--   missing values, and unique counts across a customer transactions table.
-- PROBLEM STATEMENT:
--   Demonstrate the exact behavioral differences between COUNT(*), COUNT(1),
--   COUNT(column), and COUNT(DISTINCT column) in the presence of NULL values.
-- ============================================================================

DROP TABLE IF EXISTS audit_transactions;
CREATE TABLE audit_transactions (
    txn_id INT PRIMARY KEY,
    customer_id INT,
    discount_code VARCHAR(20) -- Contains NULLs and duplicate promo codes
);

INSERT INTO audit_transactions VALUES
(1, 101, 'SUMMER10'),
(2, 102, NULL),
(3, 103, 'SUMMER10'),
(4, 104, NULL),
(5, 105, 'WELCOME5');

-- --- [SOLUTION QUERY] ---
SELECT 
    COUNT(*) AS total_rows_star,
    COUNT(1) AS total_rows_one,
    COUNT(discount_code) AS populated_discounts,
    COUNT(*) - COUNT(discount_code) AS missing_discounts,
    COUNT(DISTINCT discount_code) AS unique_discount_codes
FROM audit_transactions;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 1
-- ASSERT: COL[total_rows_star] = 5
-- ASSERT: COL[populated_discounts] = 3
-- ASSERT: COL[unique_discount_codes] = 2
