-- ============================================================================
-- EXERCISE: 084_pessimistic_locking_for_update.sql
-- MODULE:   08_transactions_concurrency_and_locks
-- LEVEL:    🔴<br>Advanced
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ROLE:     Lead Cloud Infrastructure & Messaging Systems Architect
-- ----------------------------------------------------------------------------
-- ARCHITECTURAL CONTEXT & SYSTEM TOPOLOGY:
--   High-Throughput Distributed Task Processing Queue & Pessimistic Locks.
--   When multiple worker instances pull work from a relational task queue:
--   - Naive SELECT ... FOR UPDATE causes Worker 2 to block behind Worker 1,
--     collapsing parallel pipeline processing into a single-threaded bottleneck.
--   - Advanced modern pattern: SELECT ... FOR UPDATE SKIP LOCKED (PostgreSQL, MySQL 8+, Oracle).
--     This allows concurrent workers to instantly bypass rows already locked by peers,
--     acquiring the next unleased task immediately with zero lock wait time!
--
-- BUSINESS CONTEXT:
--   In customer webhook notification delivery services dispatching 5,000 tasks/second,
--   job starvation and queue processing lag occur when worker processes contend on
--   queue head locks.
--
-- PROBLEM STATEMENT:
--   Model a distributed task queue with worker leasing states. Write a queue dispatching
--   query that identifies the next eligible, unleased job ready for Worker-3 to acquire,
--   simulating the semantics of SKIP LOCKED.
-- ============================================================================

DROP TABLE IF EXISTS distributed_task_queue;

CREATE TABLE distributed_task_queue (
    task_id VARCHAR(32) PRIMARY KEY,
    task_type VARCHAR(50) NOT NULL,
    payload_json TEXT NOT NULL,
    priority INT NOT NULL, -- Higher number = higher priority
    status VARCHAR(20) NOT NULL, -- PENDING, IN_PROGRESS, COMPLETED, FAILED
    locked_by_worker VARCHAR(32),
    lock_expires_at TEXT,
    created_at TEXT NOT NULL
);

INSERT INTO distributed_task_queue VALUES
('TSK-1001', 'SEND_WEBHOOK', '{"url":"https://api.acme.com"}', 10, 'IN_PROGRESS', 'worker-node-1', '2024-06-01 15:30:00', '2024-06-01 15:00:00'),
('TSK-1002', 'SEND_WEBHOOK', '{"url":"https://api.apex.com"}', 10, 'IN_PROGRESS', 'worker-node-2', '2024-06-01 15:30:00', '2024-06-01 15:01:00'),
('TSK-1003', 'REFRESH_CACHE', '{"key":"catalog_us"}',           5, 'PENDING',     NULL,            NULL,                 '2024-06-01 15:02:00'),
('TSK-1004', 'INDEX_LOGS',    '{"batch":"b-99"}',               1, 'PENDING',     NULL,            NULL,                 '2024-06-01 15:03:00');

-- --- [SOLUTION QUERY] ---
-- Query executing SKIP LOCKED dispatch semantics for incoming Worker-3
SELECT 
    task_id,
    task_type,
    priority,
    status,
    'worker-node-3' AS acquiring_worker,
    'SKIP_LOCKED_NON_BLOCKING_DISPATCH' AS acquisition_strategy
FROM distributed_task_queue
WHERE status = 'PENDING'
  AND (locked_by_worker IS NULL OR lock_expires_at < '2024-06-01 15:10:00')
ORDER BY priority DESC, created_at ASC
LIMIT 1;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 1
-- ASSERT: COL[task_id] = TSK-1003
-- ASSERT: COL[acquiring_worker] = worker-node-3\n