-- ============================================================================
-- EXERCISE: 023_where_pre_filtering_vs_having_post_aggregation.sql
-- MODULE:   03_aggregations_and_grouping
-- LEVEL:    Beginner / Foundation
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   Finance needs to audit departments whose total verified expense claims
--   exceed $1,000. Only claims with status 'APPROVED' should be evaluated.
-- PROBLEM STATEMENT:
--   Demonstrate combining WHERE (filtering out rejected/pending claims before
--   aggregation) with HAVING (filtering out departments with small total claims).
-- ============================================================================

DROP TABLE IF EXISTS expense_claims;
CREATE TABLE expense_claims (
    claim_id INT PRIMARY KEY,
    department VARCHAR(50),
    amount DECIMAL(10, 2),
    status VARCHAR(20)
);

INSERT INTO expense_claims VALUES
(1, 'Engineering', 800.00, 'APPROVED'),
(2, 'Engineering', 400.00, 'APPROVED'),
(3, 'Engineering', 500.00, 'REJECTED'),
(4, 'Marketing',   600.00, 'APPROVED'),
(5, 'Marketing',   300.00, 'APPROVED'),
(6, 'Sales',       1500.00, 'APPROVED');

-- --- [SOLUTION QUERY] ---
SELECT 
    department,
    SUM(amount) AS total_approved_expenses
FROM expense_claims
WHERE status = 'APPROVED'
GROUP BY department
HAVING SUM(amount) > 1000.00
ORDER BY total_approved_expenses DESC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 2
-- ASSERT: COL[total_approved_expenses] = 1500.00
