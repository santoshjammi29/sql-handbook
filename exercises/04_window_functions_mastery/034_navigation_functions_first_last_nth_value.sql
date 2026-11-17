-- ============================================================================
-- EXERCISE: 034_navigation_functions_first_last_nth_value.sql
-- MODULE:   04_window_functions_mastery
-- LEVEL:    Advanced
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   Customer journey attribution requires comparing each touchpoint order amount
--   against both the customer's very first order amount and their latest order amount.
-- PROBLEM STATEMENT:
--   Use FIRST_VALUE() and LAST_VALUE() with explicit window framing
--   (ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) to avoid framing traps.
-- ============================================================================

DROP TABLE IF EXISTS customer_orders_stream;
CREATE TABLE customer_orders_stream (
    order_id INT PRIMARY KEY,
    customer_id INT,
    order_date TEXT,
    order_amount DECIMAL(10, 2)
);

INSERT INTO customer_orders_stream VALUES
(1, 101, '2024-01-10', 50.00),
(2, 101, '2024-02-15', 120.00),
(3, 101, '2024-03-20', 300.00),
(4, 102, '2024-01-15', 200.00),
(5, 102, '2024-04-01', 180.00);

-- --- [SOLUTION QUERY] ---
SELECT 
    order_id,
    customer_id,
    order_date,
    order_amount,
    FIRST_VALUE(order_amount) OVER (
        PARTITION BY customer_id 
        ORDER BY order_date ASC
        ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
    ) AS initial_order_amount,
    LAST_VALUE(order_amount) OVER (
        PARTITION BY customer_id 
        ORDER BY order_date ASC
        ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
    ) AS terminal_order_amount
FROM customer_orders_stream
ORDER BY customer_id ASC, order_date ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 5
-- ASSERT: COL[initial_order_amount] = 50.00
