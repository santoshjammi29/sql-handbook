-- ============================================================================
-- EXERCISE: 035_cumulative_and_running_totals.sql
-- MODULE:   04_window_functions_mastery
-- LEVEL:    Intermediate
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   Cashflow forecasting requires calculating a running bank account balance
--   across chronological credits and debits.
-- PROBLEM STATEMENT:
--   Compute running balance using SUM() OVER (ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW).
-- ============================================================================

DROP TABLE IF EXISTS account_transactions;
CREATE TABLE account_transactions (
    txn_id INT PRIMARY KEY,
    txn_date TEXT,
    amount DECIMAL(10, 2) -- Positive = Credit, Negative = Debit
);

INSERT INTO account_transactions VALUES
(1, '2024-05-01', 1000.00),
(2, '2024-05-02', -200.00),
(3, '2024-05-03', -150.00),
(4, '2024-05-04', 500.00),
(5, '2024-05-05', -100.00);

-- --- [SOLUTION QUERY] ---
SELECT 
    txn_id,
    txn_date,
    amount,
    SUM(amount) OVER (
        ORDER BY txn_date ASC, txn_id ASC
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS running_balance
FROM account_transactions
ORDER BY txn_date ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 5
-- ASSERT: COL[running_balance] = 1000.00
