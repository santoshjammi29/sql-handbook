-- ============================================================================
-- EXERCISE: 035_cumulative_and_running_totals.sql
-- MODULE:   04_window_functions_mastery
-- LEVEL:    🔴<br>Advanced
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ROLE:     Lead Core Banking Architect & FinTech Transaction Engineer
-- ----------------------------------------------------------------------------
-- ARCHITECTURAL CONTEXT & SYSTEM TOPOLOGY:
--   Core Banking General Ledger & Real-Time Balance Tracker.
--   Every transaction (credits, debits, wire transfers, card swipes) mutates the account balance.
--   The ledger must compute running balances in chronological sequence and immediately
--   flag any moment the balance breaches overdraft limits (e.g. falling below $0.00).
--
-- BUSINESS CONTEXT:
--   Enterprise analytical engine optimization for 035 cumulative and running totals.
--   Ensuring strict grain integrity, distributed performance, and deterministic results.
--
-- PROBLEM STATEMENT:
--   Write a production-grade SQL query fulfilling the architectural requirements for 035 cumulative and running totals.
-- ============================================================================

DROP TABLE IF EXISTS core_bank_ledger;

CREATE TABLE core_bank_ledger (
    entry_id VARCHAR(32) PRIMARY KEY,
    account_id VARCHAR(32) NOT NULL,
    entry_timestamp TEXT NOT NULL,
    transaction_type VARCHAR(20) NOT NULL,
    amount_usd DECIMAL(12, 2) NOT NULL
);

INSERT INTO core_bank_ledger VALUES
('ENT-01', 'ACC-99', '2024-05-01 09:00:00', 'DEPOSIT',     5000.00),
('ENT-02', 'ACC-99', '2024-05-01 11:30:00', 'WITHDRAWAL', -1200.00),
('ENT-03', 'ACC-99', '2024-05-01 14:15:00', 'WIRE_OUT',   -4200.00), -- Overdraft breach! (-400)
('ENT-04', 'ACC-99', '2024-05-01 16:00:00', 'DEPOSIT',     2000.00),
('ENT-05', 'ACC-99', '2024-05-01 18:30:00', 'WITHDRAWAL',  -500.00);

-- --- [SOLUTION QUERY] ---
WITH running_ledger AS (
    SELECT 
        entry_id,
        account_id,
        entry_timestamp,
        transaction_type,
        amount_usd,
        -- Running cumulative balance
        SUM(amount_usd) OVER (
            PARTITION BY account_id 
            ORDER BY entry_timestamp ASC
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS current_running_balance_usd
    FROM core_bank_ledger
)
SELECT 
    entry_id,
    account_id,
    entry_timestamp,
    transaction_type,
    amount_usd,
    current_running_balance_usd,
    -- High watermark: peak balance reached up to this point
    MAX(current_running_balance_usd) OVER (
        PARTITION BY account_id 
        ORDER BY entry_timestamp ASC
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS peak_balance_high_watermark_usd,
    CASE 
        WHEN current_running_balance_usd < 0.00 THEN 'OVERDRAFT_BREACH_FEE_TRIGGERED'
        WHEN current_running_balance_usd < 500.00 THEN 'LOW_BALANCE_WARNING'
        ELSE 'HEALTHY_SOLVENT'
    END AS account_standing_status
FROM running_ledger
ORDER BY entry_timestamp ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 5
-- ASSERT: COL[entry_id] = ENT-01
