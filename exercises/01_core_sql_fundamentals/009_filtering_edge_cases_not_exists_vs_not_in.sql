-- ============================================================================
-- EXERCISE: 009_filtering_edge_cases_not_exists_vs_not_in.sql
-- MODULE:   01_core_sql_fundamentals
-- LEVEL:    Intermediate
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   A security audit must locate all internal employee badges that have NEVER
--   accessed secure server facilities. The badge swipe log contains NULL entries
--   for anonymized or unauthenticated gateway attempts.
-- PROBLEM STATEMENT:
--   Write an anti-join query using NOT EXISTS to find employees without swipe
--   logs, and explain why NOT IN fails catastrophically when subquery contains NULL.
-- ============================================================================

DROP TABLE IF EXISTS employees;
DROP TABLE IF EXISTS facility_access_log;

CREATE TABLE employees (
    badge_id INT PRIMARY KEY,
    employee_name VARCHAR(100)
);

CREATE TABLE facility_access_log (
    log_id INT PRIMARY KEY,
    badge_id INT, -- Contains NULLs for guest/unregistered taps
    access_time TEXT
);

INSERT INTO employees VALUES (1, 'Alice'), (2, 'Bob'), (3, 'Charlie'), (4, 'David');
INSERT INTO facility_access_log VALUES (101, 1, '2024-05-01 08:30:00'), (102, 2, '2024-05-01 09:15:00'), (103, NULL, '2024-05-01 10:00:00');

-- --- [SOLUTION QUERY] ---
-- Using NOT EXISTS: resilient to NULL values in the target table
SELECT 
    e.badge_id,
    e.employee_name
FROM employees e
WHERE NOT EXISTS (
    SELECT 1 
    FROM facility_access_log l 
    WHERE l.badge_id = e.badge_id
)
ORDER BY e.badge_id ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 2
-- ASSERT: COL[employee_name] = Charlie
