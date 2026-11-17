-- ============================================================================
-- EXERCISE: 006_string_manipulation_and_pattern_extraction.sql
-- MODULE:   01_core_sql_fundamentals
-- LEVEL:    Beginner / Foundation
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   User identity management records email addresses in mixed casing with leading
--   and trailing whitespace. Fraud teams need to extract the email domain to
--   aggregate disposable domain abuse.
-- PROBLEM STATEMENT:
--   Sanitize customer emails (trim, lowercase) and extract the domain substring
--   after the '@' symbol using standard SQL string functions.
-- ============================================================================

DROP TABLE IF EXISTS user_registrations;
CREATE TABLE user_registrations (
    user_id INT PRIMARY KEY,
    raw_email VARCHAR(255)
);

INSERT INTO user_registrations VALUES
(1, '  Alice@CORP.ACME.COM  '),
(2, 'Bob.Smith@gmail.com'),
(3, 'CHARLIE@TEMP-MAIL.ORG  '),
(4, '  david@corp.acme.com');

-- --- [SOLUTION QUERY] ---
SELECT 
    user_id,
    LOWER(TRIM(raw_email)) AS clean_email,
    SUBSTR(
        LOWER(TRIM(raw_email)), 
        INSTR(LOWER(TRIM(raw_email)), '@') + 1
    ) AS email_domain
FROM user_registrations
ORDER BY user_id ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 4
-- ASSERT: COL[email_domain] = corp.acme.com
