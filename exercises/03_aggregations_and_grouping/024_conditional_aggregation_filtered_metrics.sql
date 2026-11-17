-- ============================================================================
-- EXERCISE: 024_conditional_aggregation_filtered_metrics.sql
-- MODULE:   03_aggregations_and_grouping
-- LEVEL:    Intermediate
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   An operations dashboard needs to report total transactions, total completed
--   revenue, total refunded amount, and refund rate in a SINGLE TABLE SCAN.
-- PROBLEM STATEMENT:
--   Implement conditional aggregation using CASE expressions inside SUM() and
--   COUNT() to calculate multiple business metrics simultaneously.
-- ============================================================================

DROP TABLE IF EXISTS gateway_txns;
CREATE TABLE gateway_txns (
    txn_id INT PRIMARY KEY,
    merchant_id INT,
    amount DECIMAL(10, 2),
    status VARCHAR(20) -- 'SUCCESS', 'REFUNDED', 'FAILED'
);

INSERT INTO gateway_txns VALUES
(1, 10, 100.00, 'SUCCESS'),
(2, 10, 250.00, 'SUCCESS'),
(3, 10, 50.00,  'REFUNDED'),
(4, 10, 75.00,  'FAILED'),
(5, 20, 500.00, 'SUCCESS'),
(6, 20, 200.00, 'REFUNDED');

-- --- [SOLUTION QUERY] ---
SELECT 
    merchant_id,
    COUNT(*) AS total_attempts,
    SUM(CASE WHEN status = 'SUCCESS' THEN amount ELSE 0.00 END) AS success_revenue,
    SUM(CASE WHEN status = 'REFUNDED' THEN amount ELSE 0.00 END) AS refunded_amount,
    ROUND(
        100.0 * SUM(CASE WHEN status = 'REFUNDED' THEN 1 ELSE 0 END) / COUNT(*),
        2
    ) AS refund_transaction_rate_pct
FROM gateway_txns
GROUP BY merchant_id
ORDER BY merchant_id ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 2
-- ASSERT: COL[success_revenue] = 350.00
