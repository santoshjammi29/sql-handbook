-- ============================================================================
-- EXERCISE: 012_semi_joins_and_duplicate_multiplier_prevention.sql
-- MODULE:   02_joins_and_set_operations
-- LEVEL:    Intermediate
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   Finance needs to calculate the total credit limit of customers who placed
--   at least one high-value order (> $1,000). Joining customers directly to orders
--   multiplies the customer's credit limit by the number of orders they placed,
--   vastly overstating company risk.
-- PROBLEM STATEMENT:
--   Implement a Semi-Join using EXISTS to qualify customers without row multiplication.
-- ============================================================================

DROP TABLE IF EXISTS order_items;
DROP TABLE IF EXISTS customers;

CREATE TABLE customers (
    customer_id INT PRIMARY KEY,
    customer_name VARCHAR(100),
    credit_limit DECIMAL(10, 2)
);

CREATE TABLE order_items (
    order_id INT PRIMARY KEY,
    customer_id INT,
    order_total DECIMAL(10, 2)
);

INSERT INTO customers VALUES (1, 'Acme Corp', 50000.00), (2, 'Beta LLC', 30000.00), (3, 'Gamma Inc', 20000.00);
INSERT INTO order_items VALUES (101, 1, 1500.00), (102, 1, 2000.00), (103, 1, 1200.00), (104, 2, 500.00);

-- --- [SOLUTION QUERY] ---
-- Semi-Join via EXISTS: zero row multiplication
SELECT 
    c.customer_id,
    c.customer_name,
    c.credit_limit
FROM customers c
WHERE EXISTS (
    SELECT 1 
    FROM order_items o 
    WHERE o.customer_id = c.customer_id 
      AND o.order_total > 1000.00
)
ORDER BY c.customer_id ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 1
-- ASSERT: COL[credit_limit] = 50000.00
