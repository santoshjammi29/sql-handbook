-- ============================================================================
-- EXERCISE: 085_double_entry_ledger_atomic_transfer.sql
-- MODULE:   08_transactions_concurrency_and_locks
-- LEVEL:    🟣<br>Architect
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ROLE:     Principal FinTech Ledger Architect & Financial Compliance Officer
-- ----------------------------------------------------------------------------
-- ARCHITECTURAL CONTEXT & SYSTEM TOPOLOGY:
--   Core Banking General Ledger (GL) & Financial Invariant Enforcement.
--   The foundational mathematical invariant of Double-Entry Bookkeeping (Luca Pacioli, 1494):
--   Every financial transaction comprises multiple debits and credits such that:
--   $$\sum \text{Debits} - \sum \text{Credits} \equiv 0.00$$
--   No money can ever be created or destroyed within a closed ledger.
--
-- BUSINESS CONTEXT:
--   A cross-border enterprise settlement clearinghouse settles a $50,000 corporate payment:
--   1. Cash out from Corporate Settlement Account (Asset credit -$50,000.00).
--   2. Merchant Receiving Clearing Account (Liability debit +$48,500.00).
--   3. Platform Interchange Clearing Fee (Revenue debit +$1,200.00).
--   4. Network FX Conversion Fee (Revenue debit +$300.00).
--   Net balance across all 4 legs: -50,000 + 48,500 + 1,200 + 300 = 0.00!
--
-- PROBLEM STATEMENT:
--   Build a production-grade multi-leg general ledger auditing query that:
--   1. Reconciles all journal batches and verifies that every batch mathematically balances to 0.00.
--   2. Evaluates trial balance totals by account class (ASSET, LIABILITY, REVENUE).
--   3. Flags any corrupted or unbalanced transaction batches.
-- ============================================================================

DROP TABLE IF EXISTS gl_journal_lines;
DROP TABLE IF EXISTS gl_journal_batches;
DROP TABLE IF EXISTS chart_of_accounts;

CREATE TABLE chart_of_accounts (
    account_code VARCHAR(32) PRIMARY KEY,
    account_name VARCHAR(100) NOT NULL,
    account_class VARCHAR(20) NOT NULL -- ASSET, LIABILITY, REVENUE, EXPENSE
);

CREATE TABLE gl_journal_batches (
    batch_id VARCHAR(32) PRIMARY KEY,
    batch_reference VARCHAR(50) NOT NULL,
    posted_timestamp TEXT NOT NULL,
    batch_status VARCHAR(20) NOT NULL -- POSTED, PENDING, REJECTED
);

CREATE TABLE gl_journal_lines (
    line_id VARCHAR(32) PRIMARY KEY,
    batch_id VARCHAR(32) NOT NULL,
    account_code VARCHAR(32) NOT NULL,
    amount_usd DECIMAL(14, 2) NOT NULL, -- Positive = Debit, Negative = Credit
    memo VARCHAR(100) NOT NULL,
    FOREIGN KEY (batch_id) REFERENCES gl_journal_batches(batch_id),
    FOREIGN KEY (account_code) REFERENCES chart_of_accounts(account_code)
);

INSERT INTO chart_of_accounts VALUES
('1010-CASH-SETTLE',  'Corporate Cash Settlement',     'ASSET'),
('2010-MERCHANT-PAY', 'Merchant Payable Clearing',     'LIABILITY'),
('4010-FEE-REV',      'Platform Transaction Revenue',  'REVENUE'),
('4020-FX-REV',       'FX Spread Revenue',             'REVENUE');

INSERT INTO gl_journal_batches VALUES
('BATCH-2024-8801', 'WIRE-SETTLE-CORP-990', '2024-06-01 16:00:00', 'POSTED');

-- Multi-leg journal entries for BATCH-2024-8801
INSERT INTO gl_journal_lines VALUES
('LINE-01', 'BATCH-2024-8801', '1010-CASH-SETTLE',  -50000.00, 'Cash settlement disbursement'),
('LINE-02', 'BATCH-2024-8801', '2010-MERCHANT-PAY',  48500.00, 'Merchant funds transfer credited'),
('LINE-03', 'BATCH-2024-8801', '4010-FEE-REV',       1200.00, 'Interchange platform service fee'),
('LINE-04', 'BATCH-2024-8801', '4020-FX-REV',         300.00, 'Cross-border FX clearing fee');

-- --- [SOLUTION QUERY] ---
-- Master General Ledger batch audit verifying Pacioli Zero-Balance Invariant
WITH batch_balance_check AS (
    SELECT 
        b.batch_id,
        b.batch_reference,
        b.posted_timestamp,
        COUNT(l.line_id) AS total_legs,
        SUM(l.amount_usd) AS net_batch_balance_usd,
        SUM(CASE WHEN l.amount_usd > 0 THEN l.amount_usd ELSE 0 END) AS total_debits_usd,
        SUM(CASE WHEN l.amount_usd < 0 THEN ABS(l.amount_usd) ELSE 0 END) AS total_credits_usd
    FROM gl_journal_batches b
    INNER JOIN gl_journal_lines l ON b.batch_id = l.batch_id
    GROUP BY b.batch_id, b.batch_reference, b.posted_timestamp
)
SELECT 
    batch_id,
    batch_reference,
    total_legs,
    total_debits_usd,
    total_credits_usd,
    net_batch_balance_usd,
    CASE 
        WHEN net_batch_balance_usd = 0.00 THEN 'ZERO_BALANCE_INVARIANT_CONFIRMED'
        ELSE 'CRITICAL_LEDGER_IMBALANCE_DETECTED'
    END AS ledger_audit_status
FROM batch_balance_check
ORDER BY batch_id ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 1
-- ASSERT: COL[batch_id] = BATCH-2024-8801
-- ASSERT: COL[total_legs] = 4
-- ASSERT: COL[net_batch_balance_usd] = 0.0
-- ASSERT: COL[ledger_audit_status] = ZERO_BALANCE_INVARIANT_CONFIRMED\n