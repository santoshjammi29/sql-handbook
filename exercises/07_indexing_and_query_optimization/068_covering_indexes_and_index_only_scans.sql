-- ============================================================================
-- EXERCISE: 068_covering_indexes_and_index_only_scans.sql
-- MODULE:   07_indexing_and_query_optimization
-- LEVEL:    🔴<br>Advanced
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ROLE:     Lead Performance Architect & High-Throughput DBA
-- ----------------------------------------------------------------------------
-- ARCHITECTURAL CONTEXT & SYSTEM TOPOLOGY:
--   Microservice High-Throughput Read Path & Index-Only Scans.
--   When all columns requested by a query are present inside the index tree itself,
--   the database engine executes an Index-Only Scan: it answers the query entirely
--   from index memory pages without touching table heap disk blocks!
--
-- BUSINESS CONTEXT:
--   Enterprise analytical engine optimization for 068 covering indexes and index only scans.
--   Ensuring strict grain integrity, distributed performance, and deterministic results.
--
-- PROBLEM STATEMENT:
--   Write a production-grade SQL query fulfilling the architectural requirements for 068 covering indexes and index only scans.
-- ============================================================================

DROP TABLE IF EXISTS user_account_lookup;

CREATE TABLE user_account_lookup (
    user_id VARCHAR(32) PRIMARY KEY,
    email VARCHAR(150) NOT NULL,
    account_status VARCHAR(20) NOT NULL,
    profile_bio TEXT -- Heavy text column stored in table heap
);

-- Covering index containing both search predicate (email) and projected column (account_status)
CREATE INDEX idx_covering_email_status ON user_account_lookup(email, account_status);

INSERT INTO user_account_lookup VALUES
('U-01', 'alice@acme.com', 'ACTIVE', 'Enterprise Admin with multi-cloud permissions'),
('U-02', 'bob@globex.com', 'SUSPENDED', 'Pending security audit review');

-- --- [SOLUTION QUERY] ---
-- Index-Only Scan: query touches ONLY the covering index columns
SELECT 
    email,
    account_status,
    'INDEX_ONLY_SCAN_ZERO_HEAP_FETCH' AS execution_mode
FROM user_account_lookup
WHERE email = 'alice@acme.com';

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 1
-- ASSERT: COL[email] = alice@acme.com
