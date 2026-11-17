-- ============================================================================
-- EXERCISE: 031_ranking_functions_row_number_rank_dense_rank.sql
-- MODULE:   04_window_functions_mastery
-- LEVEL:    Intermediate
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   Sales leaderboard computation requires rewarding top performers. When two
--   reps tie for 2nd place, HR policy mandates that the next rep receive 3rd
--   rank (DENSE_RANK) rather than skipping to 4th rank (RANK).
-- PROBLEM STATEMENT:
--   Demonstrate ROW_NUMBER(), RANK(), and DENSE_RANK() side-by-side with tied values.
-- ============================================================================

DROP TABLE IF EXISTS sales_scores;
CREATE TABLE sales_scores (
    rep_id INT PRIMARY KEY,
    rep_name VARCHAR(50),
    score INT
);

INSERT INTO sales_scores VALUES
(1, 'Alice',   100),
(2, 'Bob',     90),
(3, 'Charlie', 90),
(4, 'David',   80),
(5, 'Eve',     70);

-- --- [SOLUTION QUERY] ---
SELECT 
    rep_id,
    rep_name,
    score,
    ROW_NUMBER() OVER (ORDER BY score DESC) AS row_num,
    RANK()       OVER (ORDER BY score DESC) AS rnk,
    DENSE_RANK() OVER (ORDER BY score DESC) AS dense_rnk
FROM sales_scores
ORDER BY score DESC, rep_id ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 5
-- ASSERT: COL[dense_rnk] = 1
