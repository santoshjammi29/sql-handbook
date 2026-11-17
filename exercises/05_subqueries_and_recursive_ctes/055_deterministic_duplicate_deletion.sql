-- ============================================================================
-- EXERCISE: 055_deterministic_duplicate_deletion.sql
-- MODULE:   05_subqueries_and_recursive_ctes
-- LEVEL:    Intermediate
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   A buggy webhook created multiple duplicate records for the same customer email.
--   Database hygiene mandates deleting all duplicate rows, strictly keeping the
--   single record with the lowest primary key ID.
-- PROBLEM STATEMENT:
--   Delete duplicates deterministically using ROW_NUMBER() in a CTE.
-- ============================================================================

DROP TABLE IF EXISTS contacts;
CREATE TABLE contacts (
    contact_id INT PRIMARY KEY,
    email VARCHAR(100),
    full_name VARCHAR(100)
);

INSERT INTO contacts VALUES
(1, 'alice@acme.com', 'Alice Smith'),
(2, 'alice@acme.com', 'Alice Smith Duplicate'),
(3, 'alice@acme.com', 'Alice S. Triplicate'),
(4, 'bob@acme.com',   'Bob Jones');

-- --- [SOLUTION QUERY] ---
-- Delete duplicate contacts preserving lowest contact_id
DELETE FROM contacts
WHERE contact_id IN (
    SELECT contact_id FROM (
        SELECT 
            contact_id,
            ROW_NUMBER() OVER (
                PARTITION BY email 
                ORDER BY contact_id ASC
            ) AS rn
        FROM contacts
    ) ranked
    WHERE ranked.rn > 1
);

SELECT contact_id, email, full_name FROM contacts ORDER BY contact_id ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 2
-- ASSERT: COL[contact_id] = 1
