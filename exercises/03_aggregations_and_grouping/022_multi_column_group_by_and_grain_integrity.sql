-- ============================================================================
-- EXERCISE: 022_multi_column_group_by_and_grain_integrity.sql
-- MODULE:   03_aggregations_and_grouping
-- LEVEL:    Intermediate
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   A SaaS company bills customers based on product tier across multiple geographic
--   regions. The billing team needs aggregated metrics at the (region, plan_tier) grain.
-- PROBLEM STATEMENT:
--   Group by multiple dimensions, ensuring proper grain integrity, and calculate
--   active subscriber count and total Monthly Recurring Revenue (MRR).
-- ============================================================================

DROP TABLE IF EXISTS subscriptions;
CREATE TABLE subscriptions (
    sub_id INT PRIMARY KEY,
    region VARCHAR(50),
    plan_tier VARCHAR(50),
    mrr DECIMAL(10, 2)
);

INSERT INTO subscriptions VALUES
(1, 'EMEA', 'Enterprise', 5000.00),
(2, 'EMEA', 'Standard', 1200.00),
(3, 'EMEA', 'Enterprise', 4500.00),
(4, 'US',   'Enterprise', 6000.00),
(5, 'US',   'Standard', 1500.00),
(6, 'US',   'Standard', 1100.00);

-- --- [SOLUTION QUERY] ---
SELECT 
    region,
    plan_tier,
    COUNT(sub_id) AS active_subscribers,
    SUM(mrr)      AS total_mrr,
    ROUND(AVG(mrr), 2) AS avg_mrr_per_sub
FROM subscriptions
GROUP BY region, plan_tier
ORDER BY region ASC, total_mrr DESC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 4
-- ASSERT: COL[total_mrr] = 9500.00
