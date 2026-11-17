-- ============================================================================
-- EXERCISE: 046_scalar_and_multi_row_subqueries.sql
-- MODULE:   05_subqueries_and_recursive_ctes
-- LEVEL:    Beginner / Foundation
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   Compensation equity review: identify all employees whose salary is above
--   their department's average salary, and calculate the exact dollar variance.
-- PROBLEM STATEMENT:
--   Implement scalar subqueries in SELECT and multi-row subqueries in WHERE.
-- ============================================================================

DROP TABLE IF EXISTS dept_employees;
CREATE TABLE dept_employees (
    emp_id INT PRIMARY KEY,
    emp_name VARCHAR(50),
    dept_id INT,
    salary DECIMAL(10, 2)
);

INSERT INTO dept_employees VALUES
(1, 'Alice',   10, 95000.00),
(2, 'Bob',     10, 80000.00),
(3, 'Charlie', 20, 110000.00),
(4, 'David',   20, 70000.00);

-- --- [SOLUTION QUERY] ---
SELECT 
    e.emp_id,
    e.emp_name,
    e.dept_id,
    e.salary,
    (SELECT ROUND(AVG(d.salary), 2) FROM dept_employees d WHERE d.dept_id = e.dept_id) AS dept_avg_salary,
    ROUND(e.salary - (SELECT AVG(d.salary) FROM dept_employees d WHERE d.dept_id = e.dept_id), 2) AS salary_variance
FROM dept_employees e
WHERE e.salary > (SELECT AVG(d.salary) FROM dept_employees d WHERE d.dept_id = e.dept_id)
ORDER BY e.salary DESC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 2
-- ASSERT: COL[salary_variance] = 7500.00
