-- ============================================================================
-- EXERCISE: 043_customer_retention_cohort_curves.sql
-- MODULE:   04_window_functions_mastery
-- LEVEL:    Advanced
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   Product analytics cohorts: Group users by acquisition month and calculate
--   the retention rate in subsequent activity months (Month 0, Month 1, Month 2).
-- PROBLEM STATEMENT:
--   Build a classic cohort retention matrix in SQL.
-- ============================================================================

DROP TABLE IF EXISTS user_activities;
DROP TABLE IF EXISTS user_first_seen;

CREATE TABLE user_activities (
    user_id INT,
    activity_month INT -- Month offset: 1 = Jan, 2 = Feb, 3 = Mar
);

INSERT INTO user_activities VALUES
(1, 1), (1, 2), (1, 3),
(2, 1), (2, 2),
(3, 1),
(4, 2), (4, 3);

-- --- [SOLUTION QUERY] ---
WITH cohort_assignment AS (
    SELECT 
        user_id,
        MIN(activity_month) AS cohort_month
    FROM user_activities
    GROUP BY user_id
),
cohort_sizes AS (
    SELECT cohort_month, COUNT(user_id) AS total_cohort_users
    FROM cohort_assignment
    GROUP BY cohort_month
),
cohort_activity AS (
    SELECT 
        c.cohort_month,
        a.activity_month - c.cohort_month AS month_number,
        COUNT(DISTINCT a.user_id) AS active_users
    FROM user_activities a
    JOIN cohort_assignment c ON a.user_id = c.user_id
    GROUP BY c.cohort_month, month_number
)
SELECT 
    ca.cohort_month,
    ca.month_number,
    ca.active_users,
    cs.total_cohort_users,
    ROUND(100.0 * ca.active_users / cs.total_cohort_users, 1) AS retention_pct
FROM cohort_activity ca
JOIN cohort_sizes cs ON ca.cohort_month = cs.cohort_month
ORDER BY ca.cohort_month ASC, ca.month_number ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 5
-- ASSERT: COL[retention_pct] = 100.0
