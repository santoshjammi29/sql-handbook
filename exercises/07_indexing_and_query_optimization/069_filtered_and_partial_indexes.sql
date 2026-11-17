-- ============================================================================
-- EXERCISE: 069_filtered_and_partial_indexes.sql
-- MODULE:   07_indexing_and_query_optimization
-- LEVEL:    Advanced
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   Message queue processing: A table holds 50 million processed messages and
--   500 unprocessed messages. Indexing all 50M rows wastes gigabytes of RAM.
--   A Partial / Filtered Index indexes ONLY rows WHERE status = 'UNPROCESSED'.
-- PROBLEM STATEMENT:
--   Create a partial index and query the unprocessed queue.
-- ============================================================================

DROP TABLE IF EXISTS async_task_queue;
CREATE TABLE async_task_queue (
    task_id INT PRIMARY KEY,
    payload TEXT,
    status VARCHAR(20),
    created_at TEXT
);

INSERT INTO async_task_queue VALUES
(1, '{"job": "email"}', 'PROCESSED',   '2024-05-01 09:00:00'),
(2, '{"job": "report"}', 'PROCESSED',   '2024-05-01 09:05:00'),
(3, '{"job": "sync"}',   'UNPROCESSED', '2024-05-01 10:00:00');

-- Partial index in SQLite / Postgres
CREATE INDEX idx_unprocessed_tasks ON async_task_queue (task_id, created_at)
WHERE status = 'UNPROCESSED';

-- --- [SOLUTION QUERY] ---
SELECT task_id, payload, created_at
FROM async_task_queue
WHERE status = 'UNPROCESSED'
ORDER BY created_at ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 1
-- ASSERT: COL[task_id] = 3
