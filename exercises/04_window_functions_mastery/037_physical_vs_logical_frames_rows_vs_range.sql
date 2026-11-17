-- ============================================================================
-- EXERCISE: 037_physical_vs_logical_frames_rows_vs_range.sql
-- MODULE:   04_window_functions_mastery
-- LEVEL:    Advanced
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   When computing running totals over duplicate order dates, the default frame
--   RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW groups peer rows together,
--   producing duplicate running totals on the same date!
-- PROBLEM STATEMENT:
--   Demonstrate the critical semantic difference between ROWS (physical offsets)
--   and RANGE (logical peer groups).
-- ============================================================================

DROP TABLE IF EXISTS peer_orders;
CREATE TABLE peer_orders (
    order_id INT PRIMARY KEY,
    order_date TEXT,
    amount DECIMAL(10, 2)
);

INSERT INTO peer_orders VALUES
(1, '2024-05-01', 100.00),
(2, '2024-05-01', 150.00), -- Same date!
(3, '2024-05-02', 200.00);

-- --- [SOLUTION QUERY] ---
SELECT 
    order_id,
    order_date,
    amount,
    -- ROWS advances row by row
    SUM(amount) OVER (
        ORDER BY order_date ASC
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS rows_running_total,
    -- RANGE advances peer group by peer group
    SUM(amount) OVER (
        ORDER BY order_date ASC
        RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS range_running_total
FROM peer_orders
ORDER BY order_id ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 3
-- ASSERT: COL[rows_running_total] = 100.00
