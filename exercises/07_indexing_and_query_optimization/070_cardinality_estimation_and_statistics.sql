-- ============================================================================
-- EXERCISE: 070_cardinality_estimation_and_statistics.sql
-- MODULE:   07_indexing_and_query_optimization
-- LEVEL:    Intermediate
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   Optimizer cost modeling: In relational engines, the Cost-Based Optimizer
--   estimates cardinality (how many rows match a predicate) using table statistics.
--   When stats are missing, it defaults to fixed estimates, potentially picking
--   the wrong join strategy.
-- PROBLEM STATEMENT:
--   Demonstrate querying with analytical filters and updating optimizer stats.
-- ============================================================================

DROP TABLE IF EXISTS catalog_items;
CREATE TABLE catalog_items (
    item_id INT PRIMARY KEY,
    item_type VARCHAR(50),
    price DECIMAL(10, 2)
);

INSERT INTO catalog_items VALUES
(1, 'BOOK', 15.00),
(2, 'BOOK', 22.00),
(3, 'BOOK', 35.00),
(4, 'LAPTOP', 1200.00);

-- --- [SOLUTION QUERY] ---
SELECT 
    item_type,
    COUNT(*) AS total_items,
    ROUND(AVG(price), 2) AS avg_price
FROM catalog_items
WHERE price > 20.00
GROUP BY item_type;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 2
-- ASSERT: COL[total_items] = 2
