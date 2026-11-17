-- ============================================================================
-- EXERCISE: 013_anti_joins_for_missing_record_detection.sql
-- MODULE:   02_joins_and_set_operations
-- LEVEL:    Intermediate
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   Customer Success needs a report of all accounts that signed up over 90 days
--   ago but have never created an active project.
-- PROBLEM STATEMENT:
--   Implement an Anti-Join comparing NOT EXISTS vs. LEFT JOIN ... WHERE right.id IS NULL.
-- ============================================================================

DROP TABLE IF EXISTS projects;
DROP TABLE IF EXISTS accounts;

CREATE TABLE accounts (
    account_id INT PRIMARY KEY,
    account_name VARCHAR(100),
    created_at TEXT
);

CREATE TABLE projects (
    project_id INT PRIMARY KEY,
    account_id INT,
    project_name VARCHAR(100)
);

INSERT INTO accounts VALUES (1, 'Alpha Corp', '2023-01-10'), (2, 'Beta Inc', '2023-02-15'), (3, 'Gamma LLC', '2023-03-20');
INSERT INTO projects VALUES (101, 1, 'Website Redesign'), (102, 1, 'Mobile App');

-- --- [SOLUTION QUERY] ---
SELECT 
    a.account_id,
    a.account_name,
    a.created_at
FROM accounts a
LEFT JOIN projects p ON a.account_id = p.account_id
WHERE p.project_id IS NULL
ORDER BY a.account_id ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 2
-- ASSERT: COL[account_name] = Beta Inc
