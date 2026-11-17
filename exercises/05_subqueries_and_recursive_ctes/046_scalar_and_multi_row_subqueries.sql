-- ============================================================================
-- EXERCISE: 046_scalar_and_multi_row_subqueries.sql
-- MODULE:   05_subqueries_and_recursive_ctes
-- LEVEL:    🟢<br>Beginner
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ROLE:     Lead People Analytics Architect & Compensation Auditor
-- ----------------------------------------------------------------------------
-- ARCHITECTURAL CONTEXT & SYSTEM TOPOLOGY:
--   Executive Compensation Governance & Equity Benchmarking Mart.
--   Comparing individual employee salaries against organizational statistical benchmarks
--   (departmental averages and company-wide executive compensation caps).
--
-- BUSINESS CONTEXT:
--   1. Scalar Subquery: Returns exactly 1 row and 1 column, usable in SELECT expressions
--      or WHERE comparisons (e.g. comparing salary to company-wide average).
--   2. Multi-Row Subquery: Returns 1 column with multiple rows, used with IN, ANY/SOME, ALL.
--
-- PROBLEM STATEMENT:
--   Implement an enterprise-grade query to resolve 046 scalar and multi row subqueries.
-- ============================================================================

DROP TABLE IF EXISTS company_staff;

CREATE TABLE company_staff (
    staff_id VARCHAR(32) PRIMARY KEY,
    staff_name VARCHAR(100) NOT NULL,
    department VARCHAR(50) NOT NULL,
    salary_usd DECIMAL(12, 2) NOT NULL
);

INSERT INTO company_staff VALUES
('S-01', 'Alice Vance',    'DATA_PLATFORM', 160000.00),
('S-02', 'Bob Smith',      'DATA_PLATFORM', 130000.00),
('S-03', 'Carlos Gomez',   'SECURITY',      175000.00),
('S-04', 'David Zhang',    'SECURITY',      140000.00),
('S-05', 'Elena Rostova',  'SALES',         110000.00);

-- --- [SOLUTION QUERY] ---
-- Scalar subquery computing department average variance and company benchmark
SELECT 
    s.staff_id,
    s.staff_name,
    s.department,
    s.salary_usd,
    -- Scalar subquery: Company-wide average salary
    (SELECT ROUND(AVG(salary_usd), 2) FROM company_staff) AS company_avg_salary_usd,
    ROUND(s.salary_usd - (SELECT AVG(salary_usd) FROM company_staff), 2) AS variance_from_company_avg,
    CASE 
        WHEN s.salary_usd > (SELECT AVG(salary_usd) FROM company_staff) THEN 'ABOVE_COMPANY_BENCHMARK'
        ELSE 'BELOW_COMPANY_BENCHMARK'
    END AS compensation_tier
FROM company_staff s
ORDER BY s.salary_usd DESC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 5
-- ASSERT: COL[staff_id] = S-03
