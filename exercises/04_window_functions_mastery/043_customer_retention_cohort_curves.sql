-- ============================================================================
-- EXERCISE: 043_customer_retention_cohort_curves.sql
-- MODULE:   04_window_functions_mastery
-- LEVEL:    🔴<br>Advanced
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ROLE:     Lead Product Growth Architect & Retention Analyst
-- ----------------------------------------------------------------------------
-- ARCHITECTURAL CONTEXT & SYSTEM TOPOLOGY:
--   SaaS Customer Retention Cohort Triangle Engine.
--   Grouping users by their signup month cohort, and tracking what percentage
--   remain active in Month 0, Month 1, Month 2, etc.
--
-- BUSINESS CONTEXT:
--   Enterprise analytical engine optimization for 043 customer retention cohort curves.
--   Ensuring strict grain integrity, distributed performance, and deterministic results.
--
-- PROBLEM STATEMENT:
--   Write a production-grade SQL query fulfilling the architectural requirements for 043 customer retention cohort curves.
-- ============================================================================

DROP TABLE IF EXISTS customer_monthly_activity;
DROP TABLE IF EXISTS customer_signups;

CREATE TABLE customer_signups (
    customer_id VARCHAR(32) PRIMARY KEY,
    signup_month VARCHAR(7) NOT NULL -- 'YYYY-MM'
);

CREATE TABLE customer_monthly_activity (
    customer_id VARCHAR(32) NOT NULL,
    active_month VARCHAR(7) NOT NULL,
    PRIMARY KEY (customer_id, active_month)
);

INSERT INTO customer_signups VALUES
('C-01', '2024-01'), ('C-02', '2024-01'), ('C-03', '2024-01'), ('C-04', '2024-01'),
('C-05', '2024-02'), ('C-06', '2024-02');

INSERT INTO customer_monthly_activity VALUES
-- 2024-01 Cohort Activity (4 total users)
('C-01', '2024-01'), ('C-02', '2024-01'), ('C-03', '2024-01'), ('C-04', '2024-01'), -- Month 0: 4/4 = 100%
('C-01', '2024-02'), ('C-02', '2024-02'), ('C-03', '2024-02'),                       -- Month 1: 3/4 = 75%
('C-01', '2024-03'), ('C-02', '2024-03'),                                             -- Month 2: 2/4 = 50%
-- 2024-02 Cohort Activity (2 total users)
('C-05', '2024-02'), ('C-06', '2024-02'),                                             -- Month 0: 2/2 = 100%
('C-05', '2024-03');                                                                   -- Month 1: 1/2 = 50%

-- --- [SOLUTION QUERY] ---
WITH cohort_sizes AS (
    SELECT signup_month, COUNT(*) AS cohort_initial_users
    FROM customer_signups
    GROUP BY signup_month
),
active_by_cohort AS (
    SELECT 
        s.signup_month,
        a.active_month,
        -- Calculate month offset (assuming same year in sample)
        (CAST(SUBSTR(a.active_month, 6, 2) AS INT) - CAST(SUBSTR(s.signup_month, 6, 2) AS INT)) AS month_number,
        COUNT(DISTINCT a.customer_id) AS active_users
    FROM customer_signups s
    INNER JOIN customer_monthly_activity a ON s.customer_id = a.customer_id
    GROUP BY s.signup_month, a.active_month
)
SELECT 
    a.signup_month,
    c.cohort_initial_users,
    a.month_number,
    a.active_users,
    ROUND((CAST(a.active_users AS DECIMAL) / c.cohort_initial_users) * 100.0, 2) AS retention_rate_pct
FROM active_by_cohort a
INNER JOIN cohort_sizes c ON a.signup_month = c.signup_month
ORDER BY a.signup_month ASC, a.month_number ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 5
-- ASSERT: COL[signup_month] = 2024-01
