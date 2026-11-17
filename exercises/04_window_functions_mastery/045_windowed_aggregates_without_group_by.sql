-- ============================================================================
-- EXERCISE: 045_windowed_aggregates_without_group_by.sql
-- MODULE:   04_window_functions_mastery
-- LEVEL:    🟢<br>Beginner
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ROLE:     Lead People Analytics Architect & Compensation Lead
-- ----------------------------------------------------------------------------
-- ARCHITECTURAL CONTEXT & SYSTEM TOPOLOGY:
--   Executive Compensation Transparency & Departmental Proportion Distribution.
--   Showing each employee's salary alongside their department total payroll
--   and their personal percentage contribution, without collapsing the individual
--   employee rows.
--
-- BUSINESS CONTEXT:
--   Enterprise analytical engine optimization for 045 windowed aggregates without group by.
--   Ensuring strict grain integrity, distributed performance, and deterministic results.
--
-- PROBLEM STATEMENT:
--   Write a production-grade SQL query fulfilling the architectural requirements for 045 windowed aggregates without group by.
-- ============================================================================

DROP TABLE IF EXISTS employee_payroll;

CREATE TABLE employee_payroll (
    employee_id VARCHAR(32) PRIMARY KEY,
    employee_name VARCHAR(100) NOT NULL,
    department VARCHAR(50) NOT NULL,
    salary_usd DECIMAL(12, 2) NOT NULL
);

INSERT INTO employee_payroll VALUES
('E-01', 'Alice Vance',    'DATA_PLATFORM', 150000.00),
('E-02', 'Bob Smith',      'DATA_PLATFORM', 130000.00),
('E-03', 'Carlos Gomez',   'DATA_PLATFORM', 120000.00),
('E-04', 'David Zhang',    'INFRASTRUCTURE', 160000.00),
('E-05', 'Elena Rostova',  'INFRASTRUCTURE', 140000.00);

-- --- [SOLUTION QUERY] ---
-- Windowed aggregates preserving leaf row granularity
SELECT 
    employee_id,
    employee_name,
    department,
    salary_usd,
    SUM(salary_usd) OVER (PARTITION BY department) AS department_total_payroll_usd,
    ROUND(
        (salary_usd / SUM(salary_usd) OVER (PARTITION BY department)) * 100.0, 
        2
    ) AS pct_of_department_payroll,
    SUM(salary_usd) OVER () AS company_total_payroll_usd,
    ROUND(
        (salary_usd / SUM(salary_usd) OVER ()) * 100.0, 
        2
    ) AS pct_of_company_payroll
FROM employee_payroll
ORDER BY department ASC, salary_usd DESC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 5
-- ASSERT: COL[employee_id] = E-01
