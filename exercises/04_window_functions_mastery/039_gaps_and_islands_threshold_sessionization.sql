-- ============================================================================
-- EXERCISE: 039_gaps_and_islands_threshold_sessionization.sql
-- MODULE:   04_window_functions_mastery
-- LEVEL:    Advanced
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   Web traffic analytics sessionizer: consecutive page clicks separated by
--   less than 30 minutes (1800 seconds) belong to the same session. A gap
--   greater than 30 minutes starts a new session ID.
-- PROBLEM STATEMENT:
--   Detect gaps using LAG() and generate sequential session IDs using a
--   cumulative sum over the gap boundary indicator.
-- ============================================================================

DROP TABLE IF EXISTS clickstream;
CREATE TABLE clickstream (
    click_id INT PRIMARY KEY,
    user_id INT,
    click_epoch INT -- Epoch seconds
);

INSERT INTO clickstream VALUES
(1, 101, 1000),
(2, 101, 1500), -- 500s gap (same session)
(3, 101, 4000), -- 2500s gap (>1800s -> New session!)
(4, 101, 4200); -- 200s gap (same session)

-- --- [SOLUTION QUERY] ---
WITH flag_boundaries AS (
    SELECT 
        click_id,
        user_id,
        click_epoch,
        CASE 
            WHEN click_epoch - LAG(click_epoch) OVER (PARTITION BY user_id ORDER BY click_epoch ASC) > 1800 
                 OR LAG(click_epoch) OVER (PARTITION BY user_id ORDER BY click_epoch ASC) IS NULL 
            THEN 1 
            ELSE 0 
        END AS is_new_session
    FROM clickstream
)
SELECT 
    click_id,
    user_id,
    click_epoch,
    SUM(is_new_session) OVER (
        PARTITION BY user_id 
        ORDER BY click_epoch ASC
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS session_id
FROM flag_boundaries
ORDER BY click_id ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 4
-- ASSERT: COL[session_id] = 1
