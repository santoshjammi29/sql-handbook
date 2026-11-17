-- ============================================================================
-- EXERCISE: 017_lateral_joins_and_cross_apply_expansions.sql
-- MODULE:   02_joins_and_set_operations
-- LEVEL:    Advanced
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   For an executive summary, retrieve each customer along with their top 2
--   most expensive orders.
-- PROBLEM STATEMENT:
--   Implement Top-N per category using window functions and correlated subqueries.
-- ============================================================================

DROP TABLE IF EXISTS customer_orders;
DROP TABLE IF EXISTS clients;

CREATE TABLE clients (
    client_id INT PRIMARY KEY,
    client_name VARCHAR(100)
);

CREATE TABLE customer_orders (
    order_id INT PRIMARY KEY,
    client_id INT,
    amount DECIMAL(10, 2)
);

INSERT INTO clients VALUES (1, 'Acme Corp'), (2, 'Globex Inc');
INSERT INTO customer_orders VALUES
(1, 1, 500.00), (2, 1, 1200.00), (3, 1, 300.00), (4, 1, 950.00),
(5, 2, 2000.00), (6, 2, 1500.00), (7, 2, 800.00);

-- --- [SOLUTION QUERY] ---
WITH ranked_orders AS (
    SELECT 
        client_id,
        order_id,
        amount,
        ROW_NUMBER() OVER (
            PARTITION BY client_id 
            ORDER BY amount DESC
        ) AS order_rank
    FROM customer_orders
)
SELECT 
    c.client_id,
    c.client_name,
    r.order_id,
    r.amount,
    r.order_rank
FROM clients c
JOIN ranked_orders r 
    ON c.client_id = r.client_id 
    AND r.order_rank <= 2
ORDER BY c.client_id ASC, r.order_rank ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 4
-- ASSERT: COL[amount] = 1200.00
