-- ============================================================================
-- EXERCISE: 102_incident_phantom_read_financial_ledger_double_spend.sql
-- MODULE:   10_production_incidents_and_triage
-- LEVEL:    🔴<br>Advanced
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ROLE:     Principal FinTech Security Architect & Fraud Engine Specialist
-- ----------------------------------------------------------------------------
-- ARCHITECTURAL CONTEXT & SYSTEM TOPOLOGY:
--   PRODUCTION INCIDENT POSTMORTEM: Financial Ledger Double-Spend Breach Under Read Committed.
--   A fraud ring exploited a race condition in the mobile wallet disbursement endpoint to
--   withdraw $1,000.00 from an account holding only $600.00, causing a -$400.00 ledger breach.
--
-- BUSINESS CONTEXT:
--   PRODUCTION INCIDENT ROOT CAUSE:
--   Two concurrent withdrawal API calls arrived simultaneously (within 3 milliseconds).
--   Under default `READ COMMITTED` isolation:
--   - Thread 1: Reads `balance = 600.00`. $600 >= $500$ -> OK.
--   - Thread 2: Reads `balance = 600.00` simultaneously. $600 >= $500$ -> OK.
--   - Thread 1 updates balance: $600 - 500 = 100$.
--   - Thread 2 updates balance: $100 - 500 = -400$!
--
-- PROBLEM STATEMENT:
--   SURGICAL TRIAGE & REMEDIATION:
--   1. Database Level: Enforce hard CHECK constraint: `CHECK (settled_balance_usd >= 0.00)`.
--   2. SQL Predicate Level: Atomic Compare-And-Deduct guard:
--      `UPDATE wallet SET balance = balance - :amt WHERE id = :id AND balance >= :amt;`
--   3. If affected row count == 0, the transaction aborts with INSUFFICIENT_FUNDS.
-- ============================================================================

DROP TABLE IF EXISTS wallet_accounts_security;

CREATE TABLE wallet_accounts_security (
    account_id VARCHAR(32) PRIMARY KEY,
    account_holder VARCHAR(100) NOT NULL,
    settled_balance_usd DECIMAL(12, 2) NOT NULL CHECK (settled_balance_usd >= 0.00)
);

INSERT INTO wallet_accounts_security VALUES
('WLT-FRAUD-01', 'Compromised Target Account', 600.00);

-- Thread 1 executes atomic guarded withdrawal of $500.00 (Succeeds)
UPDATE wallet_accounts_security
SET settled_balance_usd = settled_balance_usd - 500.00
WHERE account_id = 'WLT-FRAUD-01' AND settled_balance_usd >= 500.00;

-- Thread 2 attempts atomic guarded withdrawal of $500.00 (Fails guard predicate: 100 < 500)
UPDATE wallet_accounts_security
SET settled_balance_usd = settled_balance_usd - 500.00
WHERE account_id = 'WLT-FRAUD-01' AND settled_balance_usd >= 500.00;

-- --- [SOLUTION QUERY] ---
-- Verify account balance preserved above zero and double-spend prevented
SELECT 
    account_id,
    account_holder,
    settled_balance_usd,
    CASE 
        WHEN settled_balance_usd >= 0.00 THEN 'ZERO_BALANCE_INVARIANT_PRESERVED'
        ELSE 'DOUBLE_SPEND_BREACH_DETECTED'
    END AS ledger_integrity_status,
    'ATOMIC_PREDICATE_AND_CHECK_CONSTRAINT' AS security_defense_layer
FROM wallet_accounts_security
WHERE account_id = 'WLT-FRAUD-01';

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 1
-- ASSERT: COL[account_id] = WLT-FRAUD-01
-- ASSERT: COL[settled_balance_usd] = 100.0
-- ASSERT: COL[ledger_integrity_status] = ZERO_BALANCE_INVARIANT_PRESERVED\n