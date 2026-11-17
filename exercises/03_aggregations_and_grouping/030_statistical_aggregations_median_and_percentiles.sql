-- ============================================================================
-- EXERCISE: 030_statistical_aggregations_median_and_percentiles.sql
-- MODULE:   03_aggregations_and_grouping
-- LEVEL:    Advanced
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   Compensation benchmarking requires computing median salary per department.
--   Averages are heavily distorted by C-level outliers.
-- PROBLEM STATEMENT:
--   Calculate the statistical median salary using analytical window functions
--   and row numbering across even and odd partition sizes.
-- ============================================================================

DROP TABLE IF EXISTS compensation;
CREATE TABLE compensation (
    emp_id INT PRIMARY KEY,
    dept VARCHAR(50),
    salary DECIMAL(10, 2)
);

INSERT INTO compensation VALUES
(1, 'Engineering', 90000.00),
(2, 'Engineering', 100000.00),
(3, 'Engineering', 110000.00),
(4, 'Engineering', 120000.00),
(5, 'Engineering', 300000.00); -- Extreme outlier!

-- --- [SOLUTION QUERY] ---
WITH ranked_salaries AS (
    SELECT 
        dept,
        salary,
        ROW_NUMBER() OVER (PARTITION BY dept ORDER BY salary ASC) AS rk,
        COUNT(*)     OVER (PARTITION BY dept) AS total_count
    FROM compensation
)
SELECT 
    dept,
    ROUND(AVG(salary), 2) AS median_salary
FROM ranked_salaries
WHERE rk IN ((total_count + 1) / 2, (total_count + 2) / 2)
GROUP BY dept;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 1
-- ASSERT: COL[median_salary] = 110000.0
