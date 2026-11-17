-- ============================================================================
-- EXERCISE: 045_windowed_aggregates_without_group_by.sql
-- MODULE:   04_window_functions_mastery
-- LEVEL:    Beginner / Foundation
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   Payroll transparency analysis: Show each employee's salary alongside their
--   department total payroll and their personal percentage contribution, without
--   collapsing the individual employee rows.
-- PROBLEM STATEMENT:
--   Compute ratio-to-report using SUM() OVER (PARTITION BY dept) without GROUP BY.
-- ============================================================================

DROP TABLE IF EXISTS staff_salaries;
CREATE TABLE staff_salaries (
    staff_id INT PRIMARY KEY,
    staff_name VARCHAR(50),
    dept VARCHAR(50),
    salary DECIMAL(10, 2)
);

INSERT INTO staff_salaries VALUES
(1, 'Alice',   'Finance', 8000.00),
(2, 'Bob',     'Finance', 12000.00),
(3, 'Charlie', 'IT',      10000.00),
(4, 'David',   'IT',      15000.00);

-- --- [SOLUTION QUERY] ---
SELECT 
    staff_id,
    staff_name,
    dept,
    salary,
    SUM(salary) OVER (PARTITION BY dept) AS dept_total_payroll,
    ROUND(100.0 * salary / SUM(salary) OVER (PARTITION BY dept), 2) AS pct_of_dept_payroll
FROM staff_salaries
ORDER BY dept ASC, salary DESC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 4
-- ASSERT: COL[dept_total_payroll] = 20000.00
