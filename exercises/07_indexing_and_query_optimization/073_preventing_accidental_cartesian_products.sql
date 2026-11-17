-- ============================================================================
-- EXERCISE: 073_preventing_accidental_cartesian_products.sql
-- MODULE:   07_indexing_and_query_optimization
-- LEVEL:    Beginner / Foundation
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   A developer joined two tables without specifying an ON condition, or joined
--   on non-unique keys, creating a catastrophic Cartesian Product that filled
--   TempDB disk space and crashed the database instance.
-- PROBLEM STATEMENT:
--   Join two parent-child tables ensuring exact join key equality to prevent explosion.
-- ============================================================================

DROP TABLE IF EXISTS departments;
DROP TABLE IF EXISTS staff;

CREATE TABLE departments (dept_id INT PRIMARY KEY, dept_name VARCHAR(50));
CREATE TABLE staff (staff_id INT PRIMARY KEY, dept_id INT, staff_name VARCHAR(50));

INSERT INTO departments VALUES (1, 'HR'), (2, 'Engineering');
INSERT INTO staff VALUES (101, 1, 'Alice'), (102, 2, 'Bob'), (103, 2, 'Charlie');

-- --- [SOLUTION QUERY] ---
-- Strict join prevents 2 x 3 = 6 cartesian explosion
SELECT 
    d.dept_name,
    s.staff_name
FROM departments d
JOIN staff s ON d.dept_id = s.dept_id
ORDER BY d.dept_name ASC, s.staff_name ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 3
-- ASSERT: COL[staff_name] = Bob
