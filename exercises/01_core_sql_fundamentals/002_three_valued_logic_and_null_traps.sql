-- ============================================================================
-- EXERCISE: 002_three_valued_logic_and_null_traps.sql
-- MODULE:   01_core_sql_fundamentals
-- LEVEL:    Beginner / Foundation
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   A marketing operations system needs to identify customer leads that have NOT
--   unsubscribed from communication. However, unsubscribed status contains NULL
--   values for legacy users who registered before consent tracking was enabled.
-- PROBLEM STATEMENT:
--   Retrieve all customers who are NOT explicitly unsubscribed ('UNSUB'), handling
--   Three-Valued Logic (3VL) properly so NULL records are safely included. Also
--   demonstrate the catastrophic NOT IN (..., NULL) trap.
-- PRODUCTION PITFALL:
--   Using 'WHERE status != ''UNSUB''' silently drops all NULL records because
--   NULL != 'UNSUB' evaluates to UNKNOWN, which evaluates to FALSE in WHERE filters!
-- ============================================================================

DROP TABLE IF EXISTS marketing_leads;
CREATE TABLE marketing_leads (
    lead_id INT PRIMARY KEY,
    email VARCHAR(100),
    unsub_status VARCHAR(20) -- Values: 'UNSUB', 'ACTIVE', or NULL
);

INSERT INTO marketing_leads (lead_id, email, unsub_status) VALUES
(1, 'alice@example.com', 'ACTIVE'),
(2, 'bob@example.com', 'UNSUB'),
(3, 'charlie@example.com', NULL),
(4, 'david@example.com', 'ACTIVE'),
(5, 'eve@example.com', NULL);

-- --- [SOLUTION QUERY] ---
-- Correctly handles 3VL by checking IS NULL or using COALESCE
SELECT 
    lead_id,
    email,
    COALESCE(unsub_status, 'UNSET') AS resolved_status
FROM marketing_leads
WHERE unsub_status != 'UNSUB' OR unsub_status IS NULL
ORDER BY lead_id ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 4
-- ASSERT: COL[email] = alice@example.com
