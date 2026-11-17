-- ============================================================================
-- EXERCISE: 071_clustered_vs_non_clustered_index_layout.sql
-- MODULE:   07_indexing_and_query_optimization
-- LEVEL:    Advanced
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   Clustered Index determines the physical order of rows on disk. There can
--   be only ONE clustered index per table. In SQLite/Postgres/MySQL, the PRIMARY KEY
--   serves as the clustered index.
-- PROBLEM STATEMENT:
--   Demonstrate range scanning on a clustered primary key.
-- ============================================================================

DROP TABLE IF EXISTS ledger_entries;
CREATE TABLE ledger_entries (
    entry_id INT PRIMARY KEY, -- Clustered physical key
    account_id INT,
    amount DECIMAL(10, 2)
);

INSERT INTO ledger_entries VALUES
(1001, 10, 250.00),
(1002, 10, 100.00),
(1003, 20, 500.00),
(1004, 20, 750.00);

-- --- [SOLUTION QUERY] ---
-- Sequential physical range scan
SELECT entry_id, account_id, amount
FROM ledger_entries
WHERE entry_id BETWEEN 1001 AND 1003
ORDER BY entry_id ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 3
-- ASSERT: COL[amount] = 250.00
