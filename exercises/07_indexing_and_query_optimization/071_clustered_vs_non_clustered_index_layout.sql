-- ============================================================================
-- EXERCISE: 071_clustered_vs_non_clustered_index_layout.sql
-- MODULE:   07_indexing_and_query_optimization
-- LEVEL:    🔴<br>Advanced
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ROLE:     Lead Storage Engine Architect & Physical DBA
-- ----------------------------------------------------------------------------
-- ARCHITECTURAL CONTEXT & SYSTEM TOPOLOGY:
--   Physical Storage Layout: Clustered vs Non-Clustered Indexes.
--   1. Clustered Index: Dictates the physical order of rows on disk (the leaf nodes ARE the data pages).
--   2. Non-Clustered Index: Separate B-Tree containing indexed keys and pointers back to the base table.
--
-- BUSINESS CONTEXT:
--   Enterprise analytical engine optimization for 071 clustered vs non clustered index layout.
--   Ensuring strict grain integrity, distributed performance, and deterministic results.
--
-- PROBLEM STATEMENT:
--   Write a production-grade SQL query fulfilling the architectural requirements for 071 clustered vs non clustered index layout.
-- ============================================================================

DROP TABLE IF EXISTS clustered_ledger_store;

CREATE TABLE clustered_ledger_store (
    posting_sequence_id INT PRIMARY KEY, -- In SQLite/InnoDB, PRIMARY KEY defines physical clustering!
    account_number VARCHAR(30) NOT NULL,
    transaction_amount_usd DECIMAL(12, 2) NOT NULL,
    posted_timestamp TEXT NOT NULL
);

INSERT INTO clustered_ledger_store VALUES
(1001, 'ACC-8801', 5000.00, '2024-05-01 10:00:00'),
(1002, 'ACC-8802', 1200.00, '2024-05-01 10:05:00'),
(1003, 'ACC-8801', 3400.00, '2024-05-01 10:10:00');

-- --- [SOLUTION QUERY] ---
-- Querying physically contiguous clustered range
SELECT 
    posting_sequence_id,
    account_number,
    transaction_amount_usd,
    posted_timestamp,
    'CLUSTERED_SEQUENTIAL_PAGE_SCAN' AS io_profile
FROM clustered_ledger_store
WHERE posting_sequence_id BETWEEN 1001 AND 1003
ORDER BY posting_sequence_id ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 3
-- ASSERT: COL[posting_sequence_id] = 1001
