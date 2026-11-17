-- ============================================================================
-- EXERCISE: 072_join_algorithms_nested_loop_hash_merge.sql
-- MODULE:   07_indexing_and_query_optimization
-- LEVEL:    Intermediate
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   Database join algorithms:
--   1. Nested Loop: for each outer row, seek inner index (fast for tiny tables)
--   2. Hash Join: build hash table on smaller table, probe with larger table
--   3. Merge Join: both sides sorted on join key, streaming merge
-- PROBLEM STATEMENT:
--   Write an inner join with equality predicates suitable for hash/merge optimization.
-- ============================================================================

DROP TABLE IF EXISTS customers_dim;
DROP TABLE IF EXISTS orders_fact;

CREATE TABLE customers_dim (cust_id INT PRIMARY KEY, cust_name VARCHAR(50));
CREATE TABLE orders_fact (order_id INT PRIMARY KEY, cust_id INT, amount DECIMAL(10, 2));

INSERT INTO customers_dim VALUES (1, 'Alice'), (2, 'Bob');
INSERT INTO orders_fact VALUES (101, 1, 500.00), (102, 1, 300.00), (103, 2, 800.00);

-- --- [SOLUTION QUERY] ---
SELECT 
    c.cust_id,
    c.cust_name,
    COUNT(o.order_id) AS order_count,
    SUM(o.amount)     AS total_order_amount
FROM customers_dim c
JOIN orders_fact o ON c.cust_id = o.cust_id
GROUP BY c.cust_id, c.cust_name
ORDER BY total_order_amount DESC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 2
-- ASSERT: COL[total_order_amount] = 800.00
