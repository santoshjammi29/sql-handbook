-- ============================================================================
-- EXERCISE: 076_acid_atomicity_and_savepoints.sql
-- MODULE:   08_transactions_concurrency_and_locks
-- LEVEL:    Intermediate
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   Multi-step order checkout: Customer places an order and applies a discount.
--   If the discount is invalid, we want to roll back the discount step using a
--   SAVEPOINT while preserving the core order placement.
-- PROBLEM STATEMENT:
--   Execute a transaction with SAVEPOINT and ROLLBACK TO SAVEPOINT.
-- ============================================================================

DROP TABLE IF EXISTS customer_orders_tx;
CREATE TABLE customer_orders_tx (
    order_id INT PRIMARY KEY,
    amount DECIMAL(10, 2),
    status VARCHAR(20)
);

BEGIN TRANSACTION;
INSERT INTO customer_orders_tx VALUES (101, 200.00, 'PENDING');
SAVEPOINT discount_attempt;
INSERT INTO customer_orders_tx VALUES (102, -50.00, 'INVALID_DISCOUNT');
-- Rollback the invalid discount
ROLLBACK TO discount_attempt;
COMMIT;

-- --- [SOLUTION QUERY] ---
SELECT order_id, amount, status FROM customer_orders_tx;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 1
-- ASSERT: COL[order_id] = 101
