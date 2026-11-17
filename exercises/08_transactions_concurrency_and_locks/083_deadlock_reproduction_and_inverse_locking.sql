-- ============================================================================
-- EXERCISE: 083_deadlock_reproduction_and_inverse_locking.sql
-- MODULE:   08_transactions_concurrency_and_locks
-- LEVEL:    🔴<br>Advanced
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ROLE:     Staff Database Reliability Engineer & High-Volume OLTP Architect
-- ----------------------------------------------------------------------------
-- ARCHITECTURAL CONTEXT & SYSTEM TOPOLOGY:
--   Core Banking Multi-Account Wire Settlement & Distributed Lock Graphs.
--   Deadlock Anomaly (PostgreSQL 40P01 / MySQL 1205):
--   - Worker A transfers funds from Account 101 to Account 202.
--     Acquires exclusive lock on Account 101, then requests lock on Account 202.
--   - Simultaneously, Worker B transfers funds from Account 202 to Account 101.
--     Acquires exclusive lock on Account 202, then requests lock on Account 101.
--   - Classic cyclic lock dependency: Worker A waits for Worker B; Worker B waits for Worker A.
--   - Engine deadlock detector kicks in, aborting one worker with transaction serialization failure.
--
-- BUSINESS CONTEXT:
--   In cross-border payment clearinghouses handling 10,000 tx/sec, deadlocks degrade
--   throughput by 40% due to costly aborts, rollbacks, and retry stampedes.
--   The permanent architectural solution: **Canonical Resource Ordering**.
--   Every worker MUST acquire locks in strictly sorted resource identifier order
--   (e.g., MIN(acc_a, acc_b) FIRST, then MAX(acc_a, acc_b) SECOND), regardless
--   of transfer direction! This mathematically guarantees a Directed Acyclic Graph (DAG)
--   with ZERO possible deadlock cycles.
--
-- PROBLEM STATEMENT:
--   Model a wire transfer routing engine. Given pending concurrent transfer requests,
--   write a query that computes the canonical lock acquisition sequence for each transfer
--   and verifies that canonical ordering prevents cyclic lock contention.
-- ============================================================================

DROP TABLE IF EXISTS pending_wire_transfers;
DROP TABLE IF EXISTS settlement_accounts;

CREATE TABLE settlement_accounts (
    account_id VARCHAR(32) PRIMARY KEY,
    clearing_bank VARCHAR(50) NOT NULL,
    settled_balance_usd DECIMAL(14, 2) NOT NULL
);

CREATE TABLE pending_wire_transfers (
    transfer_id VARCHAR(32) PRIMARY KEY,
    source_account_id VARCHAR(32) NOT NULL,
    target_account_id VARCHAR(32) NOT NULL,
    transfer_amount_usd DECIMAL(14, 2) NOT NULL,
    initiated_at TEXT NOT NULL
);

INSERT INTO settlement_accounts VALUES
('ACC-101', 'Federal Clearing Bank A', 100000.00),
('ACC-202', 'Federal Clearing Bank B', 150000.00);

-- Two concurrent transfers in opposite directions:
INSERT INTO pending_wire_transfers VALUES
('TXN-WIRE-01', 'ACC-101', 'ACC-202', 25000.00, '2024-06-01 14:00:00'),
('TXN-WIRE-02', 'ACC-202', 'ACC-101', 10000.00, '2024-06-01 14:00:01');

-- --- [SOLUTION QUERY] ---
-- Determine canonical locking sequence to guarantee deadlock immunity
SELECT 
    t.transfer_id,
    t.source_account_id,
    t.target_account_id,
    t.transfer_amount_usd,
    CASE 
        WHEN t.source_account_id < t.target_account_id THEN t.source_account_id 
        ELSE t.target_account_id 
    END AS primary_lock_resource,
    CASE 
        WHEN t.source_account_id < t.target_account_id THEN t.target_account_id 
        ELSE t.source_account_id 
    END AS secondary_lock_resource,
    'CANONICAL_SORT_PREVENTS_DEADLOCK_CYCLES' AS lock_protocol_strategy
FROM pending_wire_transfers t
ORDER BY t.transfer_id ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 2
-- ASSERT: COL[transfer_id] = TXN-WIRE-01
-- ASSERT: COL[primary_lock_resource] = ACC-101
-- ASSERT: COL[secondary_lock_resource] = ACC-202\n