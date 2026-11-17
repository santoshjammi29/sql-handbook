-- ============================================================================
-- EXERCISE: 039_gaps_and_islands_threshold_sessionization.sql
-- MODULE:   04_window_functions_mastery
-- LEVEL:    🔴<br>Advanced
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ROLE:     Lead Digital Analytics Architect & Clickstream Engineer
-- ----------------------------------------------------------------------------
-- ARCHITECTURAL CONTEXT & SYSTEM TOPOLOGY:
--   Web & Mobile Clickstream User Sessionization Engine.
--   Incoming user event streams lack session identifiers. An inactive period of
--   30 minutes (1800 seconds) between events demarcates the boundary of a new session.
--
-- BUSINESS CONTEXT:
--   Sessionization Pattern:
--   1. Calculate elapsed seconds since previous user event using LAG(epoch_seconds).
--   2. Flag a new session (1) if elapsed > 1800 seconds or if it is the first event, else 0.
--   3. Perform a running SUM() of the new-session flags: this assigns a monotonically
--      increasing session ID to all events within the active window!
--
-- PROBLEM STATEMENT:
--   Implement an enterprise-grade query to resolve 039 gaps and islands threshold sessionization.
-- ============================================================================

DROP TABLE IF EXISTS user_raw_events;

CREATE TABLE user_raw_events (
    event_id VARCHAR(32) PRIMARY KEY,
    user_id VARCHAR(32) NOT NULL,
    event_timestamp TEXT NOT NULL,
    epoch_sec INT NOT NULL,
    page_url VARCHAR(100) NOT NULL
);

INSERT INTO user_raw_events VALUES
-- User U1 - Session 1
('E-01', 'U1', '2024-05-01 10:00:00', 1714557600, '/home'),
('E-02', 'U1', '2024-05-01 10:10:00', 1714558200, '/products'), -- +10m (Same session)
('E-03', 'U1', '2024-05-01 10:25:00', 1714559100, '/cart'),     -- +15m (Same session)
-- User U1 - Session 2 (45m inactivity gap!)
('E-04', 'U1', '2024-05-01 11:10:00', 1714561800, '/home'),     -- +45m -> New session!
('E-05', 'U1', '2024-05-01 11:15:00', 1714562100, '/checkout'); -- +5m  (Same session 2)

-- --- [SOLUTION QUERY] ---
WITH lagged_events AS (
    SELECT 
        event_id,
        user_id,
        event_timestamp,
        epoch_sec,
        page_url,
        LAG(epoch_sec) OVER (PARTITION BY user_id ORDER BY epoch_sec ASC) AS prev_epoch_sec
    FROM user_raw_events
),
session_boundaries AS (
    SELECT 
        event_id,
        user_id,
        event_timestamp,
        epoch_sec,
        page_url,
        -- Flag new session if gap > 1800 seconds (30 minutes) or first event
        CASE 
            WHEN prev_epoch_sec IS NULL OR (epoch_sec - prev_epoch_sec) > 1800 THEN 1 
            ELSE 0 
        END AS is_new_session_flag
    FROM lagged_events
),
assigned_sessions AS (
    SELECT 
        event_id,
        user_id,
        event_timestamp,
        page_url,
        -- Running sum creates unique session index per user
        SUM(is_new_session_flag) OVER (
            PARTITION BY user_id 
            ORDER BY epoch_sec ASC 
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS session_seq_num
    FROM session_boundaries
)
SELECT 
    user_id,
    session_seq_num,
    COUNT(event_id) AS total_events_in_session,
    MIN(event_timestamp) AS session_started_at,
    MAX(event_timestamp) AS session_ended_at
FROM assigned_sessions
GROUP BY user_id, session_seq_num
ORDER BY user_id ASC, session_seq_num ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 2
-- ASSERT: COL[user_id] = U1
