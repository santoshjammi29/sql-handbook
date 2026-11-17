-- ============================================================================
-- EXERCISE: 001_logical_query_execution_order.sql
-- MODULE:   01_core_sql_fundamentals
-- LEVEL:    Beginner / Foundation
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   An e-commerce finance team needs to calculate gross transaction margins
--   and filter out transactions with margins below $50. Junior analysts keep
--   writing queries that reference calculated column aliases in the WHERE clause,
--   causing database syntax compilation errors.
-- PROBLEM STATEMENT:
--   Demonstrate why a column alias defined in SELECT cannot be referenced in
--   WHERE, but CAN be referenced in ORDER BY. Provide the production-grade fix
--   using both a Common Table Expression (CTE) and subexpression repetition.
-- PRODUCTION PITFALL:
--   Attempting 'WHERE gross_margin > 50' fails because WHERE executes at Step 2
--   while SELECT projections execute at Step 6.
-- ============================================================================

DROP TABLE IF EXISTS orders;
CREATE TABLE orders (
    order_id INT PRIMARY KEY,
    customer_id INT,
    sale_amount DECIMAL(10, 2),
    cost_amount DECIMAL(10, 2),
    status VARCHAR(20)
);

INSERT INTO orders (order_id, customer_id, sale_amount, cost_amount, status) VALUES
(101, 1, 150.00, 80.00, 'COMPLETED'),
(102, 2, 200.00, 160.00, 'COMPLETED'),
(103, 1, 350.00, 200.00, 'COMPLETED'),
(104, 3, 90.00, 70.00, 'CANCELLED'),
(105, 4, 500.00, 320.00, 'COMPLETED');

-- --- [SOLUTION QUERY] ---
-- Using CTE to materialize alias before downstream filtering and sorting
WITH calculated_orders AS (
    SELECT 
        order_id,
        customer_id,
        sale_amount,
        cost_amount,
        (sale_amount - cost_amount) AS gross_margin,
        status
    FROM orders
    WHERE status = 'COMPLETED'
)
SELECT 
    order_id,
    customer_id,
    gross_margin
FROM calculated_orders
WHERE gross_margin >= 50.00
ORDER BY gross_margin DESC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 3
-- ASSERT: COL[gross_margin] = 180.00
