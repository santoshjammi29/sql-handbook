-- ============================================================================
-- EXERCISE: 044_top_n_per_category_deterministic_ties.sql
-- MODULE:   04_window_functions_mastery
-- LEVEL:    🔴<br>Advanced
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ROLE:     Lead Data Architect & People Analytics Lead
-- ----------------------------------------------------------------------------
-- ARCHITECTURAL CONTEXT & SYSTEM TOPOLOGY:
--   Top-N per Category with Strict Determinism & Tie-Breaking.
--   A frequent bug in ETL pipelines: queries returning Top-N per category
--   (e.g., Top-2 highest earners per department) produce fluctuating, non-deterministic
--   results across runs when multiple candidates have identical compensation.
--
-- BUSINESS CONTEXT:
--   Enterprise analytical engine optimization for 044 top n per category deterministic ties.
--   Ensuring strict grain integrity, distributed performance, and deterministic results.
--
-- PROBLEM STATEMENT:
--   Write a production-grade SQL query fulfilling the architectural requirements for 044 top n per category deterministic ties.
-- ============================================================================

DROP TABLE IF EXISTS company_compensation;

CREATE TABLE company_compensation (
    emp_id VARCHAR(32) PRIMARY KEY,
    department VARCHAR(50) NOT NULL,
    salary_usd DECIMAL(12, 2) NOT NULL,
    hire_date TEXT NOT NULL
);

INSERT INTO company_compensation VALUES
('EMP-10', 'AI_RESEARCH', 220000.00, '2021-03-15'),
('EMP-20', 'AI_RESEARCH', 220000.00, '2022-06-01'), -- Tied salary with EMP-10!
('EMP-30', 'AI_RESEARCH', 210000.00, '2020-01-10'),
('EMP-40', 'PLATFORM',    180000.00, '2019-11-20'),
('EMP-50', 'PLATFORM',    180000.00, '2023-02-14'), -- Tied salary with EMP-40!
('EMP-60', 'PLATFORM',    150000.00, '2024-01-05');

-- --- [SOLUTION QUERY] ---
-- Deterministic Top-2 per department breaking ties by seniority (earliest hire date), then emp_id
WITH ranked_staff AS (
    SELECT 
        emp_id,
        department,
        salary_usd,
        hire_date,
        ROW_NUMBER() OVER (
            PARTITION BY department 
            ORDER BY salary_usd DESC, hire_date ASC, emp_id ASC
        ) AS deterministic_rank
    FROM company_compensation
)
SELECT 
    emp_id,
    department,
    salary_usd,
    hire_date,
    deterministic_rank
FROM ranked_staff
WHERE deterministic_rank <= 2
ORDER BY department ASC, deterministic_rank ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 4
-- ASSERT: COL[emp_id] = EMP-10
