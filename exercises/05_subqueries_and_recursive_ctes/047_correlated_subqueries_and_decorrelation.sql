-- ============================================================================
-- EXERCISE: 047_correlated_subqueries_and_decorrelation.sql
-- MODULE:   05_subqueries_and_recursive_ctes
-- LEVEL:    🟡<br>Intermediate
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ROLE:     Lead Query Optimization Architect & Distributed Systems Engineer
-- ----------------------------------------------------------------------------
-- ARCHITECTURAL CONTEXT & SYSTEM TOPOLOGY:
--   E-Commerce Customer Lifetime Value & Order Frequency Engine.
--   A performance hazard: junior developers write correlated subqueries in WHERE:
--   'WHERE order_amount > (SELECT AVG(amount) FROM orders o2 WHERE o2.cust_id = o1.cust_id)'.
--   This creates an O(N^2) nested loop evaluation executing millions of queries!
--
-- BUSINESS CONTEXT:
--   Modern cost-based optimizers attempt "Subquery Decorrelation".
--   Senior data engineers explicitly rewrite correlated subqueries into window functions
--   or pre-aggregated joins, eliminating nested loops and ensuring linear O(N) execution.
--
-- PROBLEM STATEMENT:
--   Implement an enterprise-grade query to resolve 047 correlated subqueries and decorrelation.
-- ============================================================================

DROP TABLE IF EXISTS customer_orders_stream;

CREATE TABLE customer_orders_stream (
    order_id VARCHAR(32) PRIMARY KEY,
    customer_id VARCHAR(32) NOT NULL,
    order_amount_usd DECIMAL(12, 2) NOT NULL,
    order_date TEXT NOT NULL
);

INSERT INTO customer_orders_stream VALUES
('O-101', 'CUST-A', 500.00, '2024-05-01'),
('O-102', 'CUST-A', 800.00, '2024-05-03'), -- Above CUST-A avg (650)
('O-103', 'CUST-B', 120.00, '2024-05-01'),
('O-104', 'CUST-B', 300.00, '2024-05-04'), -- Above CUST-B avg (210)
('O-105', 'CUST-C', 450.00, '2024-05-02');

-- --- [SOLUTION QUERY] ---
-- Production decorrelated pattern using Window AVG()
WITH decorrelated_orders AS (
    SELECT 
        order_id,
        customer_id,
        order_amount_usd,
        order_date,
        -- Single-pass analytical window function replacing correlated subquery
        ROUND(AVG(order_amount_usd) OVER (PARTITION BY customer_id), 2) AS customer_avg_order_value
    FROM customer_orders_stream
)
SELECT 
    order_id,
    customer_id,
    order_amount_usd,
    customer_avg_order_value,
    ROUND(order_amount_usd - customer_avg_order_value, 2) AS dollar_above_customer_avg
FROM decorrelated_orders
WHERE order_amount_usd > customer_avg_order_value
ORDER BY order_amount_usd DESC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 2
-- ASSERT: COL[order_id] = O-102
