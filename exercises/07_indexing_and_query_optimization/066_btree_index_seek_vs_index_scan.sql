-- ============================================================================
-- EXERCISE: 066_btree_index_seek_vs_index_scan.sql
-- MODULE:   07_indexing_and_query_optimization
-- LEVEL:    Intermediate
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   A user authentication service queries accounts table by email. If the email
--   column lacks an index, the database executes an O(N) full table scan.
--   With a unique B-Tree index, it executes an O(log N) Index Seek.
-- PROBLEM STATEMENT:
--   Create a B-Tree index, query the record, and verify plan execution characteristics.
-- ============================================================================

DROP TABLE IF EXISTS app_users;
CREATE TABLE app_users (
    user_id INT PRIMARY KEY,
    email VARCHAR(100),
    is_active INT
);

INSERT INTO app_users VALUES
(1, 'alice@acme.com', 1),
(2, 'bob@acme.com', 1),
(3, 'charlie@acme.com', 0);

CREATE UNIQUE INDEX idx_users_email ON app_users (email);

-- --- [SOLUTION QUERY] ---
SELECT user_id, email, is_active
FROM app_users
WHERE email = 'alice@acme.com';

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 1
-- ASSERT: COL[user_id] = 1
