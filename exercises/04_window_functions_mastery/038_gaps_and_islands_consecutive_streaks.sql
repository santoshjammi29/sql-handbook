-- ============================================================================
-- EXERCISE: 038_gaps_and_islands_consecutive_streaks.sql
-- MODULE:   04_window_functions_mastery
-- LEVEL:    Advanced
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   Gaming engagement systems reward players who maintain consecutive daily login
--   streaks of 3 or more days.
-- PROBLEM STATEMENT:
--   Solve the classic Gaps & Islands problem using the Date - RowNumber island
--   grouping method.
-- ============================================================================

DROP TABLE IF EXISTS player_logins;
CREATE TABLE player_logins (
    player_id INT,
    login_date TEXT, -- YYYY-MM-DD
    PRIMARY KEY (player_id, login_date)
);

INSERT INTO player_logins VALUES
(1, '2024-05-01'),
(1, '2024-05-02'),
(1, '2024-05-03'), -- Streak 1: 3 days
(1, '2024-05-05'),
(1, '2024-05-06'); -- Streak 2: 2 days

-- --- [SOLUTION QUERY] ---
WITH ranked_logins AS (
    SELECT 
        player_id,
        login_date,
        -- Subtracting row_number days from login_date yields a constant anchor date for consecutive days
        DATE(login_date, '-' || (ROW_NUMBER() OVER (PARTITION BY player_id ORDER BY login_date ASC)) || ' days') AS island_anchor
    FROM player_logins
)
SELECT 
    player_id,
    MIN(login_date) AS streak_start,
    MAX(login_date) AS streak_end,
    COUNT(*) AS streak_length_days
FROM ranked_logins
GROUP BY player_id, island_anchor
HAVING COUNT(*) >= 3
ORDER BY streak_start ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 1
-- ASSERT: COL[streak_length_days] = 3
