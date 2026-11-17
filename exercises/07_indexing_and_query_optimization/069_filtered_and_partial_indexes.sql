-- ============================================================================
-- EXERCISE: 069_filtered_and_partial_indexes.sql
-- MODULE:   07_indexing_and_query_optimization
-- LEVEL:    🔴<br>Advanced
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ROLE:     Lead Systems Architect & Distributed Queue Engineer
-- ----------------------------------------------------------------------------
-- ARCHITECTURAL CONTEXT & SYSTEM TOPOLOGY:
--   High-Scale Asynchronous Task Dispatch Queue.
--   In a table of 50 million tasks, 99.8% of rows are 'COMPLETED' or 'ARCHIVED'.
--   Only 0.2% are active 'PENDING' tasks requiring rapid worker polling.
--   Creating a standard index wastes gigabytes indexing completed historical tasks.
--   A Partial (Filtered) Index indexes ONLY rows WHERE status = 'PENDING'!
--
-- BUSINESS CONTEXT:
--   Enterprise analytical engine optimization for 069 filtered and partial indexes.
--   Ensuring strict grain integrity, distributed performance, and deterministic results.
--
-- PROBLEM STATEMENT:
--   Write a production-grade SQL query fulfilling the architectural requirements for 069 filtered and partial indexes.
-- ============================================================================

DROP TABLE IF EXISTS async_task_queue;

CREATE TABLE async_task_queue (
    task_id VARCHAR(32) PRIMARY KEY,
    queue_name VARCHAR(50) NOT NULL,
    task_status VARCHAR(20) NOT NULL,
    scheduled_epoch INT NOT NULL
);

-- Partial index indexing strictly active pending tasks
CREATE INDEX idx_partial_pending_tasks 
ON async_task_queue(queue_name, scheduled_epoch) 
WHERE task_status = 'PENDING';

INSERT INTO async_task_queue VALUES
('TSK-01', 'PAYMENTS', 'COMPLETED', 1714550000),
('TSK-02', 'PAYMENTS', 'COMPLETED', 1714551000),
('TSK-03', 'PAYMENTS', 'PENDING',   1714552000), -- In partial index!
('TSK-04', 'EMAILS',   'PENDING',   1714552500), -- In partial index!
('TSK-05', 'PAYMENTS', 'ARCHIVED',  1714540000);

-- --- [SOLUTION QUERY] ---
-- Query matching the partial index filter clause
SELECT 
    task_id,
    queue_name,
    task_status,
    scheduled_epoch,
    'PARTIAL_INDEX_HOT_CACHE_SEEK' AS query_plan
FROM async_task_queue
WHERE task_status = 'PENDING' AND queue_name = 'PAYMENTS'
ORDER BY scheduled_epoch ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 1
-- ASSERT: COL[task_id] = TSK-03
