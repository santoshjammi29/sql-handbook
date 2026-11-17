-- ============================================================================
-- EXERCISE: 040_gaps_and_islands_overlapping_interval_merging.sql
-- MODULE:   04_window_functions_mastery
-- LEVEL:    Advanced
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   Hotel room booking intervals or fleet vehicle maintenance reservations
--   can overlap. Management needs to collapse overlapping booking dates into
--   contiguous booked blocks to calculate true occupancy duration.
-- PROBLEM STATEMENT:
--   Merge overlapping date intervals using windowed running maximums.
-- ============================================================================

DROP TABLE IF EXISTS booking_intervals;
CREATE TABLE booking_intervals (
    room_id INT,
    start_date TEXT,
    end_date TEXT
);

INSERT INTO booking_intervals VALUES
(1, '2024-05-01', '2024-05-05'),
(1, '2024-05-03', '2024-05-08'), -- Overlaps with booking 1!
(1, '2024-05-12', '2024-05-15'); -- Disjoint booking

-- --- [SOLUTION QUERY] ---
WITH max_prev_end AS (
    SELECT 
        room_id,
        start_date,
        end_date,
        MAX(end_date) OVER (
            PARTITION BY room_id 
            ORDER BY start_date ASC 
            ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
        ) AS max_prev_end_date
    FROM booking_intervals
),
island_starts AS (
    SELECT 
        room_id,
        start_date,
        end_date,
        CASE 
            WHEN max_prev_end_date IS NULL OR start_date > max_prev_end_date THEN 1 
            ELSE 0 
        END AS is_island_start
    FROM max_prev_end
),
island_groups AS (
    SELECT 
        room_id,
        start_date,
        end_date,
        SUM(is_island_start) OVER (
            PARTITION BY room_id 
            ORDER BY start_date ASC
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS group_id
    FROM island_starts
)
SELECT 
    room_id,
    MIN(start_date) AS merged_start_date,
    MAX(end_date)   AS merged_end_date
FROM island_groups
GROUP BY room_id, group_id
ORDER BY merged_start_date ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 2
-- ASSERT: COL[merged_end_date] = 2024-05-08
