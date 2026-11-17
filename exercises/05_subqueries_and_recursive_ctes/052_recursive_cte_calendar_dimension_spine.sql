-- ============================================================================
-- EXERCISE: 052_recursive_cte_calendar_dimension_spine.sql
-- MODULE:   05_subqueries_and_recursive_ctes
-- LEVEL:    🔴<br>Advanced
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ROLE:     Lead Dimensional Data Architect & EDW Modeler
-- ----------------------------------------------------------------------------
-- ARCHITECTURAL CONTEXT & SYSTEM TOPOLOGY:
--   Enterprise Fiscal Calendar Dimension Spine Generation.
--   Every enterprise data warehouse requires a robust Date Dimension (dim_date).
--   Generating calendar spines recursively ensures deterministic date coverage.
--
-- BUSINESS CONTEXT:
--   Enterprise analytical engine optimization for 052 recursive cte calendar dimension spine.
--   Ensuring strict grain integrity, distributed performance, and deterministic results.
--
-- PROBLEM STATEMENT:
--   Write a production-grade SQL query fulfilling the architectural requirements for 052 recursive cte calendar dimension spine.
-- ============================================================================

-- --- [SOLUTION QUERY] ---
-- Generates a 7-day calendar spine with fiscal attributes using recursive CTE
WITH RECURSIVE calendar_generator AS (
    SELECT DATE('2024-05-01') AS calendar_date
    UNION ALL
    SELECT DATE(calendar_date, '+1 day')
    FROM calendar_generator
    WHERE calendar_date < '2024-05-07'
)
SELECT 
    calendar_date,
    STRFTIME('%Y', calendar_date) AS calendar_year,
    STRFTIME('%m', calendar_date) AS calendar_month,
    STRFTIME('%d', calendar_date) AS day_of_month,
    STRFTIME('%w', calendar_date) AS day_of_week, -- 0=Sunday, 6=Saturday
    CASE 
        WHEN STRFTIME('%w', calendar_date) IN ('0', '6') THEN 'WEEKEND'
        ELSE 'BUSINESS_DAY'
    END AS day_type,
    'Q' || ((CAST(STRFTIME('%m', calendar_date) AS INT) - 1) / 3 + 1) AS fiscal_quarter
FROM calendar_generator
ORDER BY calendar_date ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 7
-- ASSERT: COL[calendar_date] = 2024-05-01
