-- ============================================================================
-- EXERCISE: 077_dirty_read_anomaly_read_uncommitted.sql
-- MODULE:   08_transactions_concurrency_and_locks
-- LEVEL:    🔴<br>Advanced
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ROLE:     Principal FinTech Data Architect & Core Banking Engineer
-- ----------------------------------------------------------------------------
-- ARCHITECTURAL CONTEXT & SYSTEM TOPOLOGY:
--   Core Banking Settlement Ledger & ANSI SQL Transaction Isolation Levels.
--   Under ANSI SQL Isolation Level READ UNCOMMITTED (Dirty Read):
--   Transaction 1 performs an in-flight UPDATE on account balance from $10,000 to $50,000.
--   Transaction 2 (auditor or risk engine) reads the updated uncommitted $50,000 balance.
--   Transaction 1 encounters an overdraft exception and issues ROLLBACK.
--   Transaction 2 has now acted upon or recorded a balance that NEVER existed in durable storage!
--
-- BUSINESS CONTEXT:
--   In high-frequency automated clearing house (ACH) systems, uncommitted dirty reads
--   can cause compliance risk alerts to be suppressed or illicit wire withdrawals
--   to be approved based on transient phantom balances.
--   Modern transactional engines enforce READ COMMITTED or Snapshot Isolation to ensure
--   queries only ever read durable, committed records.
--
-- PROBLEM STATEMENT:
--   Simulate the lifecycle of an uncommitted aborted financial transfer on account
--   ACC-CORP-01. Verify that following the rollback, durable ledger reads reflect
--   the true initial balance of $10,000.00 and that all audit logs record the aborted status.
-- ============================================================================

DROP TABLE IF EXISTS banking_transfer_audit_log;
DROP TABLE IF EXISTS core_checking_accounts;

CREATE TABLE core_checking_accounts (
    account_id VARCHAR(32) PRIMARY KEY,
    entity_name VARCHAR(100) NOT NULL,
    settled_balance_usd DECIMAL(14, 2) NOT NULL,
    last_committed_tx_id INT NOT NULL
);

CREATE TABLE banking_transfer_audit_log (
    log_id INT PRIMARY KEY,
    account_id VARCHAR(32) NOT NULL,
    attempted_tx_id INT NOT NULL,
    attempted_amount_usd DECIMAL(14, 2) NOT NULL,
    tx_outcome VARCHAR(20) NOT NULL -- COMMITTED, ROLLED_BACK
);

INSERT INTO core_checking_accounts VALUES
('ACC-CORP-01', 'Acme Treasury Ltd', 10000.00, 1001),
('ACC-CORP-02', 'Apex Logistics LLC',  25000.00, 1001);

-- Transaction 1002 starts: Attempts uncommitted mutation
BEGIN TRANSACTION;
UPDATE core_checking_accounts 
SET settled_balance_usd = settled_balance_usd + 40000.00,
    last_committed_tx_id = 1002
WHERE account_id = 'ACC-CORP-01';

-- Exception occurs during external AML check -> Transaction aborts!
ROLLBACK;

-- Audit system records the aborted attempt
INSERT INTO banking_transfer_audit_log VALUES
(1, 'ACC-CORP-01', 1002, 40000.00, 'ROLLED_BACK');

-- --- [SOLUTION QUERY] ---
-- Query verifying read committed isolation: Balance reflects strictly durable committed state
SELECT 
    a.account_id,
    a.entity_name,
    a.settled_balance_usd,
    a.last_committed_tx_id,
    COALESCE(l.tx_outcome, 'NO_ANOMALY') AS latest_audit_status,
    'DIRTY_READ_PREVENTED_BY_COMMITTED_ISOLATION' AS isolation_guarantee
FROM core_checking_accounts a
LEFT JOIN banking_transfer_audit_log l ON a.account_id = l.account_id
WHERE a.account_id = 'ACC-CORP-01';

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 1
-- ASSERT: COL[account_id] = ACC-CORP-01
-- ASSERT: COL[settled_balance_usd] = 10000.0
-- ASSERT: COL[latest_audit_status] = ROLLED_BACK\n