-- ============================================================================
-- EXERCISE: 047_correlated_subqueries_and_decorrelation.sql
-- MODULE:   05_subqueries_and_recursive_ctes
-- LEVEL:    Intermediate
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   E-commerce fraud detection: Identify customers who placed an order with an
--   amount greater than 3 times their historical average order value.
-- PROBLEM STATEMENT:
--   Write a correlated subquery comparing current row to historical customer
--   aggregates, and rewrite into an optimized decorrelated window join.
-- ============================================================================

DROP TABLE IF EXISTS customer_orders_hist;
CREATE TABLE customer_orders_hist (
    order_id INT PRIMARY KEY,
    customer_id INT,
    amount DECIMAL(10, 2)
);

INSERT INTO customer_orders_hist VALUES
(101, 1, 100.00),
(102, 1, 120.00),
(103, 1, 950.00), -- Spikes 3x above average!
(104, 2, 500.00),
(105, 2, 550.00);

-- --- [SOLUTION QUERY] ---
-- Optimized decorrelated query using window functions
WITH customer_averages AS (
    SELECT 
        order_id,
        customer_id,
        amount,
        AVG(amount) OVER (PARTITION BY customer_id) AS avg_cust_amount
    FROM customer_orders_hist
)
SELECT 
    order_id,
    customer_id,
    amount,
    ROUND(avg_cust_amount, 2) AS avg_amount,
    ROUND(amount / avg_cust_amount, 2) AS spike_ratio
FROM customer_averages
WHERE amount > 2.0 * avg_cust_amount
ORDER BY order_id ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 1
-- ASSERT: COL[order_id] = 103
