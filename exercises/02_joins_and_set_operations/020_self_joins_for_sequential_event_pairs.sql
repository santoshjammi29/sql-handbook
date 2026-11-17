-- ============================================================================
-- EXERCISE: 020_self_joins_for_sequential_event_pairs.sql
-- MODULE:   02_joins_and_set_operations
-- LEVEL:    🔴<br>Advanced
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ROLE:     Lead Analytics Engineer & Digital Product Architect
-- ----------------------------------------------------------------------------
-- ARCHITECTURAL CONTEXT & SYSTEM TOPOLOGY:
--   User Clickstream Funnel Pathing & Checkout Drop-Off Velocity Analytics.
--   Connecting consecutive sequential user actions within a browsing session
--   to compute step-to-step drop-off transition times and abandonment paths.
--
-- BUSINESS CONTEXT:
--   Product analytics needs to track transition velocity from 'PRODUCT_VIEW' to 'ADD_TO_CART'
--   to 'CHECKOUT_START' to 'ORDER_SUBMIT'. By performing a self-join on session_id
--   matching Step N with Step N+1, analysts can measure transition latency and
--   identify high-friction user friction points.
--
-- PROBLEM STATEMENT:
--   Build a self-join event pair pipeline that links each user action to its immediate
--   subsequent action, calculates transition elapsed seconds, and flags drop-offs.
-- ============================================================================

DROP TABLE IF EXISTS user_clickstream_events;

CREATE TABLE user_clickstream_events (
    event_id VARCHAR(32) PRIMARY KEY,
    session_id VARCHAR(32) NOT NULL,
    step_sequence INT NOT NULL,
    page_name VARCHAR(50) NOT NULL,
    event_epoch_sec INT NOT NULL
);

INSERT INTO user_clickstream_events VALUES
-- Session S1: Completes full checkout funnel smoothly
('E-01', 'S1', 1, 'HOME_PAGE',        1714550000),
('E-02', 'S1', 2, 'PRODUCT_DETAILS',  1714550045), -- +45s
('E-03', 'S1', 3, 'ADD_TO_CART',      1714550090), -- +45s
('E-04', 'S1', 4, 'CHECKOUT_PAYMENT', 1714550210), -- +120s
-- Session S2: Drops off after cart
('E-05', 'S2', 1, 'HOME_PAGE',        1714551000),
('E-06', 'S2', 2, 'PRODUCT_DETAILS',  1714551030), -- +30s
('E-07', 'S2', 3, 'ADD_TO_CART',      1714551080); -- Abandons here!

-- --- [SOLUTION QUERY] ---
-- Self-join pattern linking step_sequence N to step_sequence N + 1
SELECT 
    curr.session_id,
    curr.step_sequence AS from_step_num,
    curr.page_name AS from_page,
    nxt.step_sequence AS to_step_num,
    COALESCE(nxt.page_name, 'SESSION_ABANDONED_EXIT') AS to_page,
    CASE 
        WHEN nxt.event_epoch_sec IS NOT NULL THEN (nxt.event_epoch_sec - curr.event_epoch_sec)
        ELSE NULL 
    END AS transition_duration_seconds,
    CASE 
        WHEN nxt.page_name IS NULL THEN 'CHURN_DROP_OFF'
        WHEN (nxt.event_epoch_sec - curr.event_epoch_sec) > 90 THEN 'SLOW_FRICTION_TRANSITION'
        ELSE 'OPTIMAL_VELOCITY'
    END AS transition_health_grade
FROM user_clickstream_events curr
LEFT JOIN user_clickstream_events nxt 
    ON curr.session_id = nxt.session_id 
    AND curr.step_sequence + 1 = nxt.step_sequence
ORDER BY curr.session_id ASC, curr.step_sequence ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 7
-- ASSERT: COL[session_id] = S1
