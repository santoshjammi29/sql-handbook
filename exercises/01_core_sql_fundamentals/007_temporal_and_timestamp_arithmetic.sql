-- ============================================================================
-- EXERCISE: 007_temporal_and_timestamp_arithmetic.sql
-- MODULE:   01_core_sql_fundamentals
-- LEVEL:    Intermediate
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   A subscription platform charges monthly recurring subscriptions. If an
--   account is 30 days overdue, it must be flagged for cancellation. If an
--   invoice was generated within the last 7 days, it is considered in the
--   grace period.
-- PROBLEM STATEMENT:
--   Calculate the exact date difference between invoice date and due date,
--   and categorize billing status based on temporal intervals.
-- ============================================================================

DROP TABLE IF EXISTS billing_schedules;
CREATE TABLE billing_schedules (
    subscription_id INT PRIMARY KEY,
    customer_id INT,
    invoice_date TEXT,
    due_date TEXT,
    paid_date TEXT
);

INSERT INTO billing_schedules VALUES
(1, 101, '2024-05-01', '2024-05-15', '2024-05-10'),
(2, 102, '2024-05-01', '2024-05-15', '2024-05-28'),
(3, 103, '2024-05-01', '2024-05-15', NULL),
(4, 104, '2024-04-01', '2024-04-15', NULL);

-- --- [SOLUTION QUERY] ---
SELECT 
    subscription_id,
    customer_id,
    invoice_date,
    due_date,
    paid_date,
    CASE 
        WHEN paid_date IS NOT NULL AND paid_date <= due_date THEN 'ON_TIME'
        WHEN paid_date IS NOT NULL AND paid_date > due_date THEN 'PAID_LATE'
        WHEN paid_date IS NULL AND due_date < '2024-05-20' THEN 'DEFAULTED_OVERDUE'
        ELSE 'PENDING'
    END AS billing_status
FROM billing_schedules
ORDER BY subscription_id ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 4
-- ASSERT: COL[billing_status] = ON_TIME
