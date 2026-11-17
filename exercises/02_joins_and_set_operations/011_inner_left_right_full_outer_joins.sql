-- ============================================================================
-- EXERCISE: 011_inner_left_right_full_outer_joins.sql
-- MODULE:   02_joins_and_set_operations
-- LEVEL:    Intermediate
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   Sales management wants a complete list of all registered sales reps and
--   their deals closed this quarter. A junior developer placed a filter on deal
--   status in the WHERE clause of a LEFT JOIN, accidentally turning it into an
--   INNER JOIN and dropping reps who have closed zero deals.
-- PROBLEM STATEMENT:
--   Demonstrate the critical semantic difference between filtering the right-side
--   table in the ON clause vs. in the WHERE clause of an outer join.
-- ============================================================================

DROP TABLE IF EXISTS sales_deals;
DROP TABLE IF EXISTS sales_reps;

CREATE TABLE sales_reps (
    rep_id INT PRIMARY KEY,
    rep_name VARCHAR(100)
);

CREATE TABLE sales_deals (
    deal_id INT PRIMARY KEY,
    rep_id INT,
    amount DECIMAL(10, 2),
    deal_status VARCHAR(20)
);

INSERT INTO sales_reps VALUES (1, 'Alice'), (2, 'Bob'), (3, 'Charlie');
INSERT INTO sales_deals VALUES (101, 1, 50000.00, 'WON'), (102, 1, 20000.00, 'LOST'), (103, 2, 15000.00, 'LOST');

-- --- [SOLUTION QUERY] ---
-- Keep condition in ON clause so reps with 0 WON deals are NOT eliminated!
SELECT 
    r.rep_id,
    r.rep_name,
    COALESCE(SUM(d.amount), 0.00) AS total_won_amount,
    COUNT(d.deal_id) AS total_won_deals
FROM sales_reps r
LEFT JOIN sales_deals d 
    ON r.rep_id = d.rep_id 
    AND d.deal_status = 'WON' -- Evaluated during join, preserving all left rows!
GROUP BY r.rep_id, r.rep_name
ORDER BY r.rep_id ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 3
-- ASSERT: COL[total_won_amount] = 50000.00
