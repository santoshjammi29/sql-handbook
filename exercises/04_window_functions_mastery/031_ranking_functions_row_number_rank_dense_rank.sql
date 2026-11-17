-- ============================================================================
-- EXERCISE: 031_ranking_functions_row_number_rank_dense_rank.sql
-- MODULE:   04_window_functions_mastery
-- LEVEL:    🔴<br>Advanced
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ROLE:     Lead Analytics Engineer & Quantitative Compensation Modeler
-- ----------------------------------------------------------------------------
-- ARCHITECTURAL CONTEXT & SYSTEM TOPOLOGY:
--   Enterprise Performance Bonus & Sales Commission Allocation Engine.
--   When ranking entities with identical tied metrics, understanding the exact
--   mathematical behavior of ROW_NUMBER, RANK, and DENSE_RANK is vital:
--   1. ROW_NUMBER: Strictly monotonic sequential integer (1, 2, 3, 4...). Ties are broken arbitrarily unless additional sort columns are specified.
--   2. RANK: Olympic-style ranking with gaps (1, 2, 2, 4...). Next rank is incremented by number of tied peers.
--   3. DENSE_RANK: Sequential ranking without gaps (1, 2, 2, 3...). Ideal for tier awards.
--
-- BUSINESS CONTEXT:
--   Enterprise analytical engine optimization for 031 ranking functions row number rank dense rank.
--   Ensuring strict grain integrity, distributed performance, and deterministic results.
--
-- PROBLEM STATEMENT:
--   Write a production-grade SQL query fulfilling the architectural requirements for 031 ranking functions row number rank dense rank.
-- ============================================================================

DROP TABLE IF EXISTS sales_performance_ledger;

CREATE TABLE sales_performance_ledger (
    rep_id VARCHAR(32) PRIMARY KEY,
    rep_name VARCHAR(100) NOT NULL,
    department VARCHAR(50) NOT NULL,
    closed_revenue_usd DECIMAL(12, 2) NOT NULL,
    tenure_months INT NOT NULL
);

INSERT INTO sales_performance_ledger VALUES
('R-101', 'Alice Vance',    'ENTERPRISE', 1200000.00, 36), -- Rank 1
('R-102', 'Bob Smith',      'ENTERPRISE',  950000.00, 24), -- Tied Rank 2
('R-103', 'Carlos Gomez',   'ENTERPRISE',  950000.00, 18), -- Tied Rank 2 (Junior)
('R-104', 'David Zhang',    'ENTERPRISE',  800000.00, 48), -- Rank 4 (RANK) / Rank 3 (DENSE_RANK)
('R-105', 'Elena Rostova',  'COMMERCIAL',  600000.00, 12),
('R-106', 'Fiona Gallagher','COMMERCIAL',  600000.00, 24);

-- --- [SOLUTION QUERY] ---
-- Comparing ranking functions within department partitions
SELECT 
    rep_id,
    rep_name,
    department,
    closed_revenue_usd,
    tenure_months,
    -- Deterministic row number breaking ties by tenure
    ROW_NUMBER() OVER (
        PARTITION BY department 
        ORDER BY closed_revenue_usd DESC, tenure_months DESC
    ) AS deterministic_row_num,
    -- Olympic rank with gaps
    RANK() OVER (
        PARTITION BY department 
        ORDER BY closed_revenue_usd DESC
    ) AS olympic_rank_with_gaps,
    -- Dense rank without gaps
    DENSE_RANK() OVER (
        PARTITION BY department 
        ORDER BY closed_revenue_usd DESC
    ) AS bonus_tier_dense_rank
FROM sales_performance_ledger
ORDER BY department ASC, closed_revenue_usd DESC, tenure_months DESC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 6
-- ASSERT: COL[rep_id] = R-105
