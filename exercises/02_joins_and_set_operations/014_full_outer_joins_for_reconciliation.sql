-- ============================================================================
-- EXERCISE: 014_full_outer_joins_for_reconciliation.sql
-- MODULE:   02_joins_and_set_operations
-- LEVEL:    🟡<br>Intermediate
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ROLE:     Lead Data Architect & Financial Controller
-- ----------------------------------------------------------------------------
-- ARCHITECTURAL CONTEXT & SYSTEM TOPOLOGY:
--   Automated Financial General Ledger & Bank Settlement Reconciliation Engine.
--   Comparing internal general ledger transactions against an external bank feed.
--
-- BUSINESS CONTEXT:
--   Every business day, internal accounting entries must be reconciled with bank statements:
--   1. MATCHED: Transaction exists in both ledger and bank statement with identical amount.
--   2. LEDGER_ONLY: Recorded in accounting ledger but missing from bank statement (un-cleared checks, timing lag).
--   3. BANK_FEED_ONLY: Charged by bank but unrecorded in internal ledger (bank service fees, automatic debits).
--   4. AMOUNT_MISMATCH: Exists in both but values differ (disputed fee, data entry typo).
--
-- PROBLEM STATEMENT:
--   Execute a bidirectional full reconciliation that classifies every single record
--   across both systems and computes total variance.
-- ============================================================================

DROP TABLE IF EXISTS internal_gl_entries;
DROP TABLE IF EXISTS external_bank_feed;

CREATE TABLE internal_gl_entries (
    entry_id VARCHAR(32) PRIMARY KEY,
    reference_id VARCHAR(32) NOT NULL,
    amount_usd DECIMAL(12, 2) NOT NULL
);

CREATE TABLE external_bank_feed (
    statement_line_id VARCHAR(32) PRIMARY KEY,
    reference_id VARCHAR(32) NOT NULL,
    cleared_amount_usd DECIMAL(12, 2) NOT NULL
);

INSERT INTO internal_gl_entries VALUES
('GL-01', 'REF-100', 5000.00), -- Matched
('GL-02', 'REF-200', 1250.00), -- Amount mismatch (Bank shows 1200)
('GL-03', 'REF-300', 890.00),  -- Ledger only (Uncleared)
('GL-04', 'REF-400', 3400.00); -- Matched

INSERT INTO external_bank_feed VALUES
('BK-01', 'REF-100', 5000.00), -- Matched
('BK-02', 'REF-200', 1200.00), -- Amount mismatch (Internal shows 1250)
('BK-03', 'REF-400', 3400.00), -- Matched
('BK-04', 'REF-500', 45.00);   -- Bank only (Monthly service fee)

-- --- [SOLUTION QUERY] ---
-- Full outer reconciliation: implemented portably using LEFT JOIN + UNION ALL + RIGHT anti-join
WITH left_side AS (
    SELECT 
        gl.reference_id AS gl_ref,
        bk.reference_id AS bk_ref,
        gl.amount_usd AS gl_amount,
        bk.cleared_amount_usd AS bk_amount
    FROM internal_gl_entries gl
    LEFT JOIN external_bank_feed bk ON gl.reference_id = bk.reference_id
),
right_orphans AS (
    SELECT 
        NULL AS gl_ref,
        bk.reference_id AS bk_ref,
        NULL AS gl_amount,
        bk.cleared_amount_usd AS bk_amount
    FROM external_bank_feed bk
    WHERE NOT EXISTS (
        SELECT 1 FROM internal_gl_entries gl WHERE gl.reference_id = bk.reference_id
    )
),
full_recon_matrix AS (
    SELECT * FROM left_side
    UNION ALL
    SELECT * FROM right_orphans
)
SELECT 
    COALESCE(gl_ref, bk_ref) AS reconciled_reference_id,
    gl_amount,
    bk_amount,
    ROUND(COALESCE(gl_amount, 0.00) - COALESCE(bk_amount, 0.00), 2) AS variance_usd,
    CASE 
        WHEN gl_ref IS NOT NULL AND bk_ref IS NOT NULL AND gl_amount = bk_amount THEN 'RECONCILED_MATCH'
        WHEN gl_ref IS NOT NULL AND bk_ref IS NOT NULL AND gl_amount != bk_amount THEN 'AMOUNT_MISMATCH_DISPUTE'
        WHEN gl_ref IS NOT NULL AND bk_ref IS NULL THEN 'LEDGER_ONLY_UNCLEARED'
        WHEN gl_ref IS NULL AND bk_ref IS NOT NULL THEN 'BANK_ONLY_UNRECORDED_FEE'
    END AS reconciliation_status
FROM full_recon_matrix
ORDER BY reconciled_reference_id ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 5
-- ASSERT: COL[reconciled_reference_id] = REF-100
