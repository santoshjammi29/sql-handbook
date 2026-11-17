-- ============================================================================
-- EXERCISE: 014_full_outer_joins_for_reconciliation.sql
-- MODULE:   02_joins_and_set_operations
-- LEVEL:    Intermediate
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   Daily reconciliation between internal payment ledger and Stripe settlement
--   files. Records can exist in internal ledger but missing in Stripe, or exist
--   in Stripe but missing internally, or have mismatched amounts.
-- PROBLEM STATEMENT:
--   Perform bidirectional data reconciliation using a FULL OUTER JOIN (emulated
--   via UNION in SQLite for universal engine portability).
-- ============================================================================

DROP TABLE IF EXISTS internal_ledger;
DROP TABLE IF EXISTS stripe_settlements;

CREATE TABLE internal_ledger (
    txn_id VARCHAR(50) PRIMARY KEY,
    internal_amount DECIMAL(10, 2)
);

CREATE TABLE stripe_settlements (
    txn_id VARCHAR(50) PRIMARY KEY,
    stripe_amount DECIMAL(10, 2)
);

INSERT INTO internal_ledger VALUES ('TXN_001', 100.00), ('TXN_002', 250.00), ('TXN_003', 400.00);
INSERT INTO stripe_settlements VALUES ('TXN_001', 100.00), ('TXN_002', 240.00), ('TXN_004', 550.00);

-- --- [SOLUTION QUERY] ---
-- Universal Full Outer Reconciliation
WITH full_reconciliation AS (
    SELECT 
        COALESCE(i.txn_id, s.txn_id) AS txn_id,
        i.internal_amount,
        s.stripe_amount
    FROM internal_ledger i
    LEFT JOIN stripe_settlements s ON i.txn_id = s.txn_id
    UNION
    SELECT 
        COALESCE(i.txn_id, s.txn_id) AS txn_id,
        i.internal_amount,
        s.stripe_amount
    FROM stripe_settlements s
    LEFT JOIN internal_ledger i ON s.txn_id = i.txn_id
)
SELECT 
    txn_id,
    internal_amount,
    stripe_amount,
    CASE 
        WHEN internal_amount IS NULL THEN 'MISSING_IN_INTERNAL_LEDGER'
        WHEN stripe_amount IS NULL THEN 'MISSING_IN_STRIPE'
        WHEN internal_amount != stripe_amount THEN 'AMOUNT_MISMATCH'
        ELSE 'RECONCILED_MATCH'
    END AS recon_status
FROM full_reconciliation
ORDER BY txn_id ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 4
-- ASSERT: COL[recon_status] = RECONCILED_MATCH
