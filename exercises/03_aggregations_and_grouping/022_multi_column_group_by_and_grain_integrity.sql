-- ============================================================================
-- EXERCISE: 022_multi_column_group_by_and_grain_integrity.sql
-- MODULE:   03_aggregations_and_grouping
-- LEVEL:    🟡<br>Intermediate
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ROLE:     Lead Data Architect & Financial Controller
-- ----------------------------------------------------------------------------
-- ARCHITECTURAL CONTEXT & SYSTEM TOPOLOGY:
--   Multi-Entity Global General Ledger Financial Consolidation.
--   When aggregating transactional ledgers, grouping across multiple dimensional
--   levels (Operating Entity, Subsidiary, Functional Currency, and Fiscal Period)
--   is mandatory to prevent metric distortion and catastrophic currency commingling.
--
-- BUSINESS CONTEXT:
--   A multinational enterprise operates subsidiaries in Delaware (USD), London (GBP),
--   and Frankfurt (EUR). Grouping by Subsidiary alone without Currency Code mixes
--   different currency denominations together, causing fatal accounting errors!
--
-- PROBLEM STATEMENT:
--   Aggregate multi-currency ledger transactions at the precise architectural grain:
--   [Fiscal Quarter, Legal Entity, Operating Currency, Cost Center], computing
--   balanced debit/credit totals and net operating positions.
-- ============================================================================

DROP TABLE IF EXISTS global_general_ledger;

CREATE TABLE global_general_ledger (
    entry_id VARCHAR(32) PRIMARY KEY,
    fiscal_quarter VARCHAR(7) NOT NULL, -- '2024-Q1', '2024-Q2'
    legal_entity_id VARCHAR(20) NOT NULL,
    operating_currency VARCHAR(3) NOT NULL,
    cost_center VARCHAR(20) NOT NULL,
    debit_amount DECIMAL(14, 2) NOT NULL,
    credit_amount DECIMAL(14, 2) NOT NULL
);

INSERT INTO global_general_ledger VALUES
('GL-01', '2024-Q1', 'ENT-US', 'USD', 'CC-ENG', 120000.00, 0.00),
('GL-02', '2024-Q1', 'ENT-US', 'USD', 'CC-ENG', 45000.00,  0.00),
('GL-03', '2024-Q1', 'ENT-US', 'USD', 'CC-MKT', 80000.00,  0.00),
('GL-04', '2024-Q1', 'ENT-UK', 'GBP', 'CC-ENG', 95000.00,  0.00),
('GL-05', '2024-Q1', 'ENT-UK', 'GBP', 'CC-MKT', 30000.00,  0.00),
('GL-06', '2024-Q1', 'ENT-EU', 'EUR', 'CC-ENG', 110000.00, 0.00),
('GL-07', '2024-Q2', 'ENT-US', 'USD', 'CC-ENG', 135000.00, 0.00);

-- --- [SOLUTION QUERY] ---
-- Enforcing strict multi-dimensional grain integrity across financial boundaries
SELECT 
    fiscal_quarter,
    legal_entity_id,
    operating_currency,
    cost_center,
    COUNT(entry_id) AS total_ledger_postings,
    SUM(debit_amount) AS total_debits,
    SUM(credit_amount) AS total_credits,
    ROUND(SUM(debit_amount) - SUM(credit_amount), 2) AS net_operating_spend
FROM global_general_ledger
GROUP BY 
    fiscal_quarter,
    legal_entity_id,
    operating_currency,
    cost_center
ORDER BY fiscal_quarter ASC, legal_entity_id ASC, cost_center ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 6
-- ASSERT: COL[fiscal_quarter] = 2024-Q1
