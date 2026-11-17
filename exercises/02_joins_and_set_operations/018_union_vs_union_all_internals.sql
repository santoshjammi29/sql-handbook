-- ============================================================================
-- EXERCISE: 018_union_vs_union_all_internals.sql
-- MODULE:   02_joins_and_set_operations
-- LEVEL:    🟢<br>Beginner
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ROLE:     Lead Data Architect & High-Throughput Streaming Engineer
-- ----------------------------------------------------------------------------
-- ARCHITECTURAL CONTEXT & SYSTEM TOPOLOGY:
--   Omnichannel Event Stream Consolidation (Web, Mobile App & IoT Gateways).
--   A performance disaster occurred in production when an engineer used 'UNION'
--   instead of 'UNION ALL' to consolidate 50 million nightly clickstream events,
--   triggering an expensive memory spill to disk and an OOM crash.
--
-- BUSINESS CONTEXT:
--   1. UNION performs implicit DISTINCT sorting: it reads all inputs, builds a global
--      hash set or performs an external merge sort across cluster memory to eliminate
--      duplicate rows, even when sources are mutually exclusive!
--   2. UNION ALL is a pure streaming concatenation: it appends rows immediately without
--      memory buffering or sorting overhead (O(1) memory complexity).
--   3. Production Rule: Always use UNION ALL unless deliberate deduplication is required.
--
-- PROBLEM STATEMENT:
--   Consolidate disparate ingestion channels using UNION ALL while calculating channel
--   contributions, and demonstrate the exact duplicate identification audit.
-- ============================================================================

DROP TABLE IF EXISTS web_click_stream;
DROP TABLE IF EXISTS mobile_app_stream;

CREATE TABLE web_click_stream (
    event_id VARCHAR(32) PRIMARY KEY,
    user_id VARCHAR(32) NOT NULL,
    action_type VARCHAR(30) NOT NULL,
    event_timestamp TEXT NOT NULL
);

CREATE TABLE mobile_app_stream (
    event_id VARCHAR(32) PRIMARY KEY,
    user_id VARCHAR(32) NOT NULL,
    action_type VARCHAR(30) NOT NULL,
    event_timestamp TEXT NOT NULL
);

INSERT INTO web_click_stream VALUES
('EV-W1', 'USR-01', 'PAGE_VIEW', '2024-05-01 10:00:00'),
('EV-W2', 'USR-02', 'ADD_TO_CART', '2024-05-01 10:02:00'),
('EV-W3', 'USR-01', 'SEARCH', '2024-05-01 10:05:00');

INSERT INTO mobile_app_stream VALUES
('EV-M1', 'USR-03', 'APP_LAUNCH', '2024-05-01 10:01:00'),
('EV-M2', 'USR-02', 'PUSH_CLICK', '2024-05-01 10:03:00'),
('EV-W2', 'USR-02', 'ADD_TO_CART', '2024-05-01 10:02:00'); -- Duplicate webhook event!

-- --- [SOLUTION QUERY] ---
-- High-throughput streaming consolidation:
-- 1. UNION ALL provides zero-overhead concatenation
-- 2. Audit metadata tags the source channel
-- 3. Downstream windowing flags duplicate events deterministically
WITH unified_stream AS (
    SELECT event_id, user_id, action_type, event_timestamp, 'WEB_CHANNEL' AS ingestion_source
    FROM web_click_stream
    
    UNION ALL
    
    SELECT event_id, user_id, action_type, event_timestamp, 'MOBILE_CHANNEL' AS ingestion_source
    FROM mobile_app_stream
),
dedup_audited AS (
    SELECT 
        event_id,
        user_id,
        action_type,
        event_timestamp,
        ingestion_source,
        ROW_NUMBER() OVER (
            PARTITION BY event_id 
            ORDER BY ingestion_source ASC
        ) AS occurrence_rank
    FROM unified_stream
)
SELECT 
    event_id,
    user_id,
    action_type,
    event_timestamp,
    ingestion_source,
    CASE 
        WHEN occurrence_rank = 1 THEN 'PRIMARY_DELIVERY'
        ELSE 'DUPLICATE_CROSS_CHANNEL_REPLAY'
    END AS stream_delivery_status
FROM dedup_audited
ORDER BY event_timestamp ASC, event_id ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 6
-- ASSERT: COL[event_id] = EV-W1
