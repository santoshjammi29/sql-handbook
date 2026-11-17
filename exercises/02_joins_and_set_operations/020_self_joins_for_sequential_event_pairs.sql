-- ============================================================================
-- EXERCISE: 020_self_joins_for_sequential_event_pairs.sql
-- MODULE:   02_joins_and_set_operations
-- LEVEL:    Intermediate
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   User session flow analysis requires calculating how many seconds a user
--   spent on Step 1 before transitioning to Step 2 in a checkout funnel.
-- PROBLEM STATEMENT:
--   Self-join the funnel events table to match consecutive event steps for the
--   same user session and calculate time elapsed.
-- ============================================================================

DROP TABLE IF EXISTS funnel_steps;
CREATE TABLE funnel_steps (
    session_id INT,
    step_number INT,
    step_name VARCHAR(50),
    step_timestamp INT -- Unix epoch seconds
);

INSERT INTO funnel_steps VALUES
(101, 1, 'View Product', 1700000000),
(101, 2, 'Add to Cart', 1700000045),
(101, 3, 'Complete Purchase', 1700000120),
(102, 1, 'View Product', 1700000500),
(102, 2, 'Add to Cart', 1700000580);

-- --- [SOLUTION QUERY] ---
SELECT 
    curr.session_id,
    curr.step_number AS from_step_num,
    curr.step_name   AS from_step,
    next.step_name   AS to_step,
    (next.step_timestamp - curr.step_timestamp) AS duration_seconds
FROM funnel_steps curr
JOIN funnel_steps next 
    ON curr.session_id = next.session_id 
    AND curr.step_number + 1 = next.step_number
ORDER BY curr.session_id ASC, curr.step_number ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 3
-- ASSERT: COL[duration_seconds] = 45
