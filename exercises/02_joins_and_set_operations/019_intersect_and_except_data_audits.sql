-- ============================================================================
-- EXERCISE: 019_intersect_and_except_data_audits.sql
-- MODULE:   02_joins_and_set_operations
-- LEVEL:    Intermediate
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   Data migration verification between Legacy Oracle EDW and Modern Snowflake
--   Lakehouse. Data quality auditors require finding rows that exist in Legacy
--   but failed to land in Snowflake (EXCEPT), and rows common to both (INTERSECT).
-- PROBLEM STATEMENT:
--   Execute set operations INTERSECT and EXCEPT to perform audit reconciliations.
-- ============================================================================

DROP TABLE IF EXISTS legacy_customers;
DROP TABLE IF EXISTS modern_customers;

CREATE TABLE legacy_customers (customer_id INT, email VARCHAR(100));
CREATE TABLE modern_customers (customer_id INT, email VARCHAR(100));

INSERT INTO legacy_customers VALUES (1, 'alice@acme.com'), (2, 'bob@acme.com'), (3, 'charlie@acme.com');
INSERT INTO modern_customers VALUES (1, 'alice@acme.com'), (2, 'bob@acme.com'), (4, 'david@acme.com');

-- --- [SOLUTION QUERY] ---
-- Detect customers missing from Modern Lakehouse (Legacy EXCEPT Modern)
SELECT customer_id, email FROM legacy_customers
EXCEPT
SELECT customer_id, email FROM modern_customers
ORDER BY customer_id ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 1
-- ASSERT: COL[customer_id] = 3
