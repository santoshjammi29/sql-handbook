-- ============================================================================
-- EXERCISE: 097_incident_payment_gateway_deadlock_storm.sql
-- MODULE:   10_production_incidents_and_triage
-- LEVEL:    🔴<br>Advanced
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ROLE:     Staff Database Reliability Engineer & Core Banking Architect
-- ----------------------------------------------------------------------------
-- ARCHITECTURAL CONTEXT & SYSTEM TOPOLOGY:
--   PRODUCTION INCIDENT POSTMORTEM: Deadlock Storm in Payment Clearing.
--   During peak traffic, simultaneous peer-to-peer wire transfers and automated refunds
--   triggered 12,000 transaction deadlocks per minute (PostgreSQL 40P01 / MySQL 1205).
--   The database connection pool reached 100% saturation (5,000 active connections),
--   cascading into HTTP 504 Gateway Timeouts across all mobile checkout services.
--
-- BUSINESS CONTEXT:
--   PRODUCTION INCIDENT ROOT CAUSE:
--   Concurrent microservice threads executed transfers between Account 10 and Account 20
--   in arbitrary, uncoordinated lock order:
--   - Thread 1: Transfers 10 -> 20. Acquires Exclusive Lock on 10, then requests Lock on 20.
--   - Thread 2: Transfers 20 -> 10. Acquires Exclusive Lock on 20, then requests Lock on 10.
--   - Result: Classic cyclic dependency deadlock ($T_1 \to L_{20} \to T_2 \to L_{10} \to T_1$).
--
-- PROBLEM STATEMENT:
--   SURGICAL TRIAGE & REMEDIATION:
--   Enforce strict Canonical Resource Ordering across all codebase endpoints:
--   Always lock resources in strictly ascending primary key order:
--   `MIN(acc_src, acc_tgt)` FIRST, then `MAX(acc_src, acc_tgt)` SECOND.
--   This mathematically converts cyclic lock graphs into a Directed Acyclic Graph (DAG)
--   with ZERO possibility of deadlock!
-- ============================================================================

DROP TABLE IF EXISTS core_clearing_accounts;

CREATE TABLE core_clearing_accounts (
    account_id INT PRIMARY KEY,
    account_holder VARCHAR(100) NOT NULL,
    cleared_balance_usd DECIMAL(14, 2) NOT NULL
);

INSERT INTO core_clearing_accounts VALUES
(10, 'Treasury Settlement Hub',  10000.00),
(20, 'Merchant Escrow Vault',    25000.00);

-- Deadlock-Proof Canonical Transfer: Transfer $3,500.00 from Account 20 to Account 10
-- Even though money flows 20 -> 10, the engine MUST lock MIN(10, 20) = 10 first, then MAX(10, 20) = 20!
BEGIN TRANSACTION;

-- Step 1: Acquire lock on Account 10 (Min ID) and credit balance
UPDATE core_clearing_accounts 
SET cleared_balance_usd = cleared_balance_usd + 3500.00 
WHERE account_id = 10;

-- Step 2: Acquire lock on Account 20 (Max ID) and debit balance
UPDATE core_clearing_accounts 
SET cleared_balance_usd = cleared_balance_usd - 3500.00 
WHERE account_id = 20;

COMMIT;

-- --- [SOLUTION QUERY] ---
-- Verification query confirming atomic transfer succeeded with zero deadlocks
SELECT 
    account_id,
    account_holder,
    cleared_balance_usd,
    'CANONICAL_LOCKING_DEADLOCK_FREE' AS concurrency_protocol
FROM core_clearing_accounts
ORDER BY account_id ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 2
-- ASSERT: COL[account_id] = 10
-- ASSERT: COL[cleared_balance_usd] = 13500.0\n