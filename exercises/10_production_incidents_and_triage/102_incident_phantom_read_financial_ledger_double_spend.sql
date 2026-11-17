-- ============================================================================
-- EXERCISE: 102_incident_phantom_read_financial_ledger_double_spend.sql
-- MODULE:   10_production_incidents_and_triage
-- LEVEL:    Advanced
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   PRODUCTION INCIDENT POSTMORTEM: Financial Ledger Double-Spend Breach.
--   An attacker initiated two concurrent withdrawals of $500 on an account with $600.
--   Both threads read balance = $600 simultaneously under Read Committed,
--   withdrawing $1,000 total and causing a -$400 balance breach.
-- PROBLEM STATEMENT:
--   Triage and execute production recovery.
-- SURGICAL REMEDIATION:
--   Enforce strict check constraint AND atomic withdrawal with balance condition.
-- ============================================================================

DROP TABLE IF EXISTS fraud_accounts;
CREATE TABLE fraud_accounts (
    acc_id INT PRIMARY KEY,
    balance DECIMAL(10, 2) CHECK (balance >= 0.00) -- Database constraint guard!
);

INSERT INTO fraud_accounts VALUES (1, 600.00);

-- Atomic withdrawal: only update if balance >= withdrawal amount!
UPDATE fraud_accounts
SET balance = balance - 500.00
WHERE acc_id = 1 AND balance >= 500.00;

-- --- [SOLUTION QUERY] ---
SELECT acc_id, balance FROM fraud_accounts WHERE acc_id = 1;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 1
-- ASSERT: COL[balance] = 100.00
