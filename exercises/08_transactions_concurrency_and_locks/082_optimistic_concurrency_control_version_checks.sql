-- ============================================================================
-- EXERCISE: 082_optimistic_concurrency_control_version_checks.sql
-- MODULE:   08_transactions_concurrency_and_locks
-- LEVEL:    🟡<br>Intermediate
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ROLE:     Senior Distributed Backend Architect & High-Throughput Systems Engineer
-- ----------------------------------------------------------------------------
-- ARCHITECTURAL CONTEXT & SYSTEM TOPOLOGY:
--   High-Concurrency Flash-Sale Inventory Engine & Compare-And-Swap (CAS).
--   Pessimistic row locking (SELECT FOR UPDATE) causes severe database thread pool
--   exhaustion and lock convoying during sudden traffic spikes.
--   Production systems utilize Optimistic Concurrency Control (OCC) with atomic CAS:
--   1. Read item state: (stock = 100, lock_version = 1).
--   2. Perform business logic in application tier (compute discounts, validate cart).
--   3. Commit state atomically using a conditional predicate:
--      UPDATE inventory SET stock = stock - :qty, lock_version = lock_version + 1
--      WHERE item_id = :id AND lock_version = :read_version AND stock >= :qty;
--   4. If affected row count == 1: Success!
--   5. If affected row count == 0: Conflict detected (another worker updated the row). Retry or abort!
--
-- BUSINESS CONTEXT:
--   A ticketing platform releases 50 VIP tickets. 5 concurrent worker processes
--   attempt to claim seats. We must ensure that only the worker with a matching
--   version stamp succeeds, preventing double-selling while avoiding database deadlocks.
--
-- PROBLEM STATEMENT:
--   Simulate an OCC transaction where Worker 1 successfully claims 5 units at version 1,
--   advancing the version to 2. Demonstrate how Worker 2, submitting an update using
--   stale version 1, fails the CAS check, leaving inventory protected.
-- ============================================================================

DROP TABLE IF EXISTS occ_ticket_inventory;

CREATE TABLE occ_ticket_inventory (
    item_id VARCHAR(32) PRIMARY KEY,
    item_name VARCHAR(100) NOT NULL,
    available_stock INT NOT NULL,
    lock_version INT NOT NULL,
    updated_at TEXT NOT NULL
);

INSERT INTO occ_ticket_inventory VALUES
('SKU-VIP-PASS', 'Championship VIP Pass', 50, 1, '2024-06-01 12:00:00');

-- Worker 1 executes successful CAS mutation:
-- Matches item_id = 'SKU-VIP-PASS' AND lock_version = 1
UPDATE occ_ticket_inventory
SET available_stock = available_stock - 5,
    lock_version = lock_version + 1,
    updated_at = '2024-06-01 12:00:01'
WHERE item_id = 'SKU-VIP-PASS' AND lock_version = 1 AND available_stock >= 5;

-- Worker 2 (concurrent, holding stale version = 1) attempts CAS mutation:
-- This UPDATE matches 0 rows because lock_version is now 2!
UPDATE occ_ticket_inventory
SET available_stock = available_stock - 10,
    lock_version = lock_version + 1,
    updated_at = '2024-06-01 12:00:02'
WHERE item_id = 'SKU-VIP-PASS' AND lock_version = 1 AND available_stock >= 10;

-- --- [SOLUTION QUERY] ---
-- Query current inventory state verifying version incremented and stock intact
SELECT 
    item_id,
    item_name,
    available_stock,
    lock_version,
    updated_at,
    CASE 
        WHEN lock_version = 2 AND available_stock = 45 THEN 'OCC_CAS_SUCCESS_WORKER_1'
        ELSE 'OCC_ANOMALY'
    END AS concurrency_outcome
FROM occ_ticket_inventory
WHERE item_id = 'SKU-VIP-PASS';

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 1
-- ASSERT: COL[item_id] = SKU-VIP-PASS
-- ASSERT: COL[available_stock] = 45
-- ASSERT: COL[lock_version] = 2
-- ASSERT: COL[concurrency_outcome] = OCC_CAS_SUCCESS_WORKER_1\n