-- ============================================================================
-- EXERCISE: 038_gaps_and_islands_consecutive_streaks.sql
-- MODULE:   04_window_functions_mastery
-- LEVEL:    🔴<br>Advanced
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ROLE:     Lead Product Data Architect & Gamification Engineer
-- ----------------------------------------------------------------------------
-- ARCHITECTURAL CONTEXT & SYSTEM TOPOLOGY:
--   SaaS & Gaming Daily Active User (DAU) Engagement Streak Engine.
--   Rewarding players who maintain consecutive daily activity streaks of 3 or more days.
--
-- BUSINESS CONTEXT:
--   The classic "Gaps and Islands" problem:
--   When subtracting a monotonic ROW_NUMBER() from a consecutive date sequence,
--   consecutive dates increment at the exact same rate as the row number (1 day per row).
--   Therefore: (date - row_number days) yields an identical, constant anchor date for all
--   consecutive days in an island! Any gap in dates shifts the anchor, creating a new island.
--
-- PROBLEM STATEMENT:
--   Implement an enterprise-grade query to resolve 038 gaps and islands consecutive streaks.
-- ============================================================================

DROP TABLE IF EXISTS player_activity_log;

CREATE TABLE player_activity_log (
    player_id VARCHAR(32) NOT NULL,
    activity_date TEXT NOT NULL, -- YYYY-MM-DD
    xp_earned INT NOT NULL,
    PRIMARY KEY (player_id, activity_date)
);

INSERT INTO player_activity_log VALUES
-- Player 1: Streak of 3 days (May 1-3), Gap on May 4, Streak of 2 days (May 5-6)
('P-01', '2024-05-01', 150),
('P-01', '2024-05-02', 200),
('P-01', '2024-05-03', 250), -- Streak 1 (3 days)
('P-01', '2024-05-05', 180),
('P-01', '2024-05-06', 220), -- Streak 2 (2 days)
-- Player 2: Streak of 4 days (May 1-4)
('P-02', '2024-05-01', 300),
('P-02', '2024-05-02', 320),
('P-02', '2024-05-03', 310),
('P-02', '2024-05-04', 400); -- Streak 3 (4 days)

-- --- [SOLUTION QUERY] ---
-- Gaps & Islands: Date - RowNumber clustering
WITH ranked_activity AS (
    SELECT 
        player_id,
        activity_date,
        xp_earned,
        -- Subtracting row_number days produces a stable invariant date anchor
        DATE(activity_date, '-' || ROW_NUMBER() OVER (PARTITION BY player_id ORDER BY activity_date ASC) || ' days') AS island_group_anchor
    FROM player_activity_log
),
streak_aggregates AS (
    SELECT 
        player_id,
        island_group_anchor,
        MIN(activity_date) AS streak_start_date,
        MAX(activity_date) AS streak_end_date,
        COUNT(*) AS streak_duration_days,
        SUM(xp_earned) AS total_streak_xp
    FROM ranked_activity
    GROUP BY player_id, island_group_anchor
)
SELECT 
    player_id,
    streak_start_date,
    streak_end_date,
    streak_duration_days,
    total_streak_xp,
    CASE 
        WHEN streak_duration_days >= 3 THEN 'TIER_1_STREAK_BONUS_ELIGIBLE'
        ELSE 'STANDARD_ACTIVITY'
    END AS reward_status
FROM streak_aggregates
WHERE streak_duration_days >= 3
ORDER BY streak_duration_days DESC, streak_start_date ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 2
-- ASSERT: COL[player_id] = P-02
