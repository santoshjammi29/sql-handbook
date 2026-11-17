-- ============================================================================
-- EXERCISE: 028_relational_pivoting_rows_to_columns.sql
-- MODULE:   03_aggregations_and_grouping
-- LEVEL:    🟡<br>Intermediate
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ROLE:     Lead Financial Systems Architect & Reporting Lead
-- ----------------------------------------------------------------------------
-- ARCHITECTURAL CONTEXT & SYSTEM TOPOLOGY:
--   Quarterly Executive Income Statement & Financial P&L Matrix.
--   Transactional accounting databases record financial entries row-by-row with
--   [Fiscal Quarter, Account Name, Amount]. Executive balance sheets require
--   pivoting rows into columns so each quarter (Q1, Q2, Q3, Q4) forms its own column.
--
-- BUSINESS CONTEXT:
--   1. Proprietary PIVOT syntax (Snowflake, BigQuery, T-SQL) lacks cross-platform portability.
--   2. The universal ANSI SQL standard uses Conditional Aggregation:
--      'SUM(CASE WHEN quarter = ''Q1'' THEN amount ELSE 0 END) AS q1_amount'.
--   3. This is robust, high-performance, and compatible with every relational engine.
--
-- PROBLEM STATEMENT:
--   Implement an enterprise-grade query to resolve 028 relational pivoting rows to columns.
-- ============================================================================

DROP TABLE IF EXISTS accounting_gl_summary;

CREATE TABLE accounting_gl_summary (
    cost_center VARCHAR(30) NOT NULL,
    fiscal_quarter VARCHAR(7) NOT NULL, -- '2024-Q1', '2024-Q2', etc.
    spend_amount_usd DECIMAL(12, 2) NOT NULL
);

INSERT INTO accounting_gl_summary VALUES
('R&D_ENGINEERING',  '2024-Q1', 450000.00),
('R&D_ENGINEERING',  '2024-Q2', 480000.00),
('R&D_ENGINEERING',  '2024-Q3', 510000.00),
('R&D_ENGINEERING',  '2024-Q4', 530000.00),
('SALES_MARKETING',  '2024-Q1', 320000.00),
('SALES_MARKETING',  '2024-Q2', 390000.00),
('SALES_MARKETING',  '2024-Q3', 410000.00),
('SALES_MARKETING',  '2024-Q4', 440000.00),
('GENERAL_ADMIN',    '2024-Q1', 110000.00),
('GENERAL_ADMIN',    '2024-Q2', 115000.00),
('GENERAL_ADMIN',    '2024-Q3', 120000.00),
('GENERAL_ADMIN',    '2024-Q4', 125000.00);

-- --- [SOLUTION QUERY] ---
-- Universal ANSI SQL Pivot transforming quarterly rows into columnar balance sheet
SELECT 
    cost_center,
    SUM(CASE WHEN fiscal_quarter = '2024-Q1' THEN spend_amount_usd ELSE 0.00 END) AS q1_actual_usd,
    SUM(CASE WHEN fiscal_quarter = '2024-Q2' THEN spend_amount_usd ELSE 0.00 END) AS q2_actual_usd,
    SUM(CASE WHEN fiscal_quarter = '2024-Q3' THEN spend_amount_usd ELSE 0.00 END) AS q3_actual_usd,
    SUM(CASE WHEN fiscal_quarter = '2024-Q4' THEN spend_amount_usd ELSE 0.00 END) AS q4_actual_usd,
    SUM(spend_amount_usd) AS full_year_total_usd,
    ROUND(
        (SUM(CASE WHEN fiscal_quarter = '2024-Q4' THEN spend_amount_usd ELSE 0.00 END) - 
         SUM(CASE WHEN fiscal_quarter = '2024-Q1' THEN spend_amount_usd ELSE 0.00 END)) / 
        NULLIF(SUM(CASE WHEN fiscal_quarter = '2024-Q1' THEN spend_amount_usd ELSE 0.00 END), 0.00) * 100.0, 
        2
    ) AS full_year_spend_growth_pct
FROM accounting_gl_summary
GROUP BY cost_center
ORDER BY full_year_total_usd DESC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 3
-- ASSERT: COL[cost_center] = R&D_ENGINEERING
