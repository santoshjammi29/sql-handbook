-- ============================================================================
-- EXERCISE: 016_non_equi_joins_and_effective_date_matching.sql
-- MODULE:   02_joins_and_set_operations
-- LEVEL:    Intermediate
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   Product pricing changes over time. When an order is placed, it must be
--   joined with the product price active on that specific order timestamp.
-- PROBLEM STATEMENT:
--   Join orders to product price schedules using a Non-Equi Join where
--   order_date BETWEEN valid_from AND valid_to.
-- ============================================================================

DROP TABLE IF EXISTS product_prices;
DROP TABLE IF EXISTS raw_orders;

CREATE TABLE product_prices (
    product_id INT,
    unit_price DECIMAL(10, 2),
    valid_from TEXT,
    valid_to TEXT
);

CREATE TABLE raw_orders (
    order_id INT PRIMARY KEY,
    product_id INT,
    quantity INT,
    order_date TEXT
);

INSERT INTO product_prices VALUES
(1, 19.99, '2024-01-01', '2024-03-31'),
(1, 24.99, '2024-04-01', '2024-12-31'),
(2, 99.00, '2024-01-01', '2024-12-31');

INSERT INTO raw_orders VALUES
(101, 1, 2, '2024-02-15'),
(102, 1, 3, '2024-05-10'),
(103, 2, 1, '2024-05-10');

-- --- [SOLUTION QUERY] ---
SELECT 
    o.order_id,
    o.product_id,
    o.order_date,
    o.quantity,
    p.unit_price,
    ROUND(o.quantity * p.unit_price, 2) AS line_total
FROM raw_orders o
JOIN product_prices p 
    ON o.product_id = p.product_id
    AND o.order_date >= p.valid_from
    AND o.order_date <= p.valid_to
ORDER BY o.order_id ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 3
-- ASSERT: COL[line_total] = 39.98
