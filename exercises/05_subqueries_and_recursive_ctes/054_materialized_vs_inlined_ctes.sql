-- ============================================================================
-- EXERCISE: 054_materialized_vs_inlined_ctes.sql
-- MODULE:   05_subqueries_and_recursive_ctes
-- LEVEL:    🔴<br>Advanced
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ROLE:     Lead Performance Architect & Database Engine Internals Specialist
-- ----------------------------------------------------------------------------
-- ARCHITECTURAL CONTEXT & SYSTEM TOPOLOGY:
--   CTE Materialization vs Inlining Optimization.
--   PostgreSQL 12+ and modern query optimizers choose whether to materialize
--   a CTE into a temporary memory buffer or inline it into the outer query.
--
-- BUSINESS CONTEXT:
--   Enterprise analytical engine optimization for 054 materialized vs inlined ctes.
--   Ensuring strict grain integrity, distributed performance, and deterministic results.
--
-- PROBLEM STATEMENT:
--   Write a production-grade SQL query fulfilling the architectural requirements for 054 materialized vs inlined ctes.
-- ============================================================================

DROP TABLE IF EXISTS financial_ledger_feed;

CREATE TABLE financial_ledger_feed (
    txn_id VARCHAR(32) PRIMARY KEY,
    amount_usd DECIMAL(12, 2) NOT NULL,
    status VARCHAR(20) NOT NULL
);

INSERT INTO financial_ledger_feed VALUES
('T-01', 50000.00, 'SETTLED'),
('T-02', 25000.00, 'SETTLED'),
('T-03',  8000.00, 'PENDING'),
('T-04', 12000.00, 'SETTLED');

-- --- [SOLUTION QUERY] ---
-- Multi-reference CTE that benefits from single materialization rather than dual scans
WITH settled_high_value_txns AS (
    SELECT txn_id, amount_usd
    FROM financial_ledger_feed
    WHERE status = 'SETTLED' AND amount_usd >= 10000.00
)
SELECT 
    t.txn_id,
    t.amount_usd,
    (SELECT SUM(amount_usd) FROM settled_high_value_txns) AS total_settled_pool_usd,
    ROUND((t.amount_usd / (SELECT SUM(amount_usd) FROM settled_high_value_txns)) * 100.0, 2) AS pool_share_pct
FROM settled_high_value_txns t
ORDER BY t.amount_usd DESC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 3
-- ASSERT: COL[txn_id] = T-01
