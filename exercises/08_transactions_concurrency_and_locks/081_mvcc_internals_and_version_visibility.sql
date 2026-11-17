-- ============================================================================
-- EXERCISE: 081_mvcc_internals_and_version_visibility.sql
-- MODULE:   08_transactions_concurrency_and_locks
-- LEVEL:    🔴<br>Advanced
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ROLE:     Lead PostgreSQL & Distributed Storage Architect
-- ----------------------------------------------------------------------------
-- ARCHITECTURAL CONTEXT & SYSTEM TOPOLOGY:
--   PostgreSQL & Distributed Storage Engine MVCC Internals.
--   In Multi-Version Concurrency Control (MVCC), rows are immutable heap tuples.
--   Each physical tuple header stores:
--   1. xmin: Transaction ID that inserted/created the tuple.
--   2. xmax: Transaction ID that deleted or superseded the tuple (0 if currently active/alive).
--   3. Tuple Visibility Rule for Snapshot at Tx_ID = S:
--      A tuple is VISIBLE if:
--      (xmin <= S AND xmin is committed) AND (xmax > S OR xmax = 0 OR xmax is uncommitted/aborted).
--   When xmax <= S and committed, the tuple is DEAD and eligible for VACUUM cleanup.
--
-- BUSINESS CONTEXT:
--   Understanding MVCC visibility is mandatory for database architects tuning
--   autovacuum aggressiveness, diagnosing table bloat, and analyzing temporal time-travel
--   queries in modern data engines.
--
-- PROBLEM STATEMENT:
--   Model a physical MVCC heap table with tuple versions for customer account ACC-801.
--   Evaluate tuple visibility for an active transaction snapshot at tx_id = 104,
--   and classify which tuples are LIVE_VISIBLE, FUTURE_INVISIBLE, or DEAD_GARBAGE.
-- ============================================================================

DROP TABLE IF EXISTS pg_heap_tuples;

CREATE TABLE pg_heap_tuples (
    tuple_id INT PRIMARY KEY,
    account_id VARCHAR(32) NOT NULL,
    balance_usd DECIMAL(12, 2) NOT NULL,
    xmin INT NOT NULL, -- Created by transaction
    xmax INT NOT NULL  -- Expired/superseded by transaction (0 = currently active)
);

-- Evolution of ACC-801:
-- 1. Initial creation at Tx 100 ($500.00). Superseded at Tx 103.
-- 2. Updated at Tx 103 ($750.00). Superseded at Tx 106.
-- 3. Updated at Tx 106 ($950.00). Currently active (xmax = 0).
-- 4. Unrelated account ACC-802 created at Tx 102.
INSERT INTO pg_heap_tuples VALUES
(1, 'ACC-801', 500.00, 100, 103),
(2, 'ACC-801', 750.00, 103, 106),
(3, 'ACC-801', 950.00, 106, 0),
(4, 'ACC-802', 300.00, 102, 0);

-- --- [SOLUTION QUERY] ---
-- Evaluate MVCC visibility for a reader holding Snapshot Tx = 104
SELECT 
    tuple_id,
    account_id,
    balance_usd,
    xmin,
    xmax,
    CASE 
        WHEN xmin <= 104 AND (xmax > 104 OR xmax = 0) THEN 'LIVE_VISIBLE'
        WHEN xmin > 104 THEN 'FUTURE_INVISIBLE'
        WHEN xmin <= 104 AND xmax <= 104 AND xmax != 0 THEN 'DEAD_GARBAGE_TUPLE'
    END AS tuple_visibility_status,
    CASE 
        WHEN xmax != 0 AND xmax <= 104 THEN 'VACUUM_RECLAIMABLE'
        ELSE 'RETAIN'
    END AS vacuum_lifecycle
FROM pg_heap_tuples
ORDER BY tuple_id ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 4
-- ASSERT: COL[tuple_id] = 1
-- ASSERT: COL[tuple_visibility_status] = DEAD_GARBAGE_TUPLE\n