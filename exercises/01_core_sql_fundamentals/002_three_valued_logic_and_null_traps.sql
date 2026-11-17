-- ============================================================================
-- EXERCISE: 002_three_valued_logic_and_null_traps.sql
-- MODULE:   01_core_sql_fundamentals
-- LEVEL:    🟢<br>Beginner
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ROLE:     Lead Data Architect & Senior Data Engineer
-- ----------------------------------------------------------------------------
-- ARCHITECTURAL CONTEXT & SYSTEM TOPOLOGY:
--   Enterprise Compliance & Multi-Jurisdiction Privacy Consent Engine (GDPR & CCPA).
--   Streaming user consent events land in Kafka with missing fields from legacy systems.
--   A marketing campaign targeting query must filter out opted-out users while
--   strictly observing jurisdictional consent mandates.
--
-- BUSINESS CONTEXT:
--   Marketing operations executes targeted email campaigns. Under GDPR (EU), users
--   must EXPLICITLY opt in (status = 'OPT_IN'); NULL consent represents absence of
--   consent and must NOT be emailed. Under US CAN-SPAM, marketing is permitted unless
--   the user explicitly opts out (status = 'OPT_OUT'); NULL consent is permissible.
--   A junior developer used 'WHERE consent_status != ''OPT_OUT''', which silently
--   dropped all legacy NULL records due to ANSI SQL Three-Valued Logic (3VL).
--
-- PROBLEM STATEMENT:
--   1. Illustrate ANSI SQL 3VL truth tables: TRUE, FALSE, and UNKNOWN.
--   2. Demonstrate how 'column != ''VALUE''' evaluates to UNKNOWN when column IS NULL,
--      which is discarded by the WHERE clause filter.
--   3. Demonstrate the catastrophic 'NOT IN (subquery with NULL)' collapse bug.
--   4. Build a production-grade consent evaluation pipeline that handles jurisdiction-specific
--      NULL defaults safely using COALESCE, CASE, and NOT EXISTS.
--
-- DISTRIBUTED ENGINE & COMPILATION INTERNALS:
--   In distributed engines (Spark SQL, Presto/Trino, Snowflake), NULL comparisons in joins
--   or subqueries evaluate to UNKNOWN and never match, often causing unintended broadcast
--   cartesian products or dropping partitions silently.
-- ============================================================================

DROP TABLE IF EXISTS marketing_consent_log;
DROP TABLE IF EXISTS customer_privacy_profiles;

CREATE TABLE customer_privacy_profiles (
    customer_id VARCHAR(32) PRIMARY KEY,
    full_name VARCHAR(100) NOT NULL,
    jurisdiction_code VARCHAR(10) NOT NULL, -- 'EU_GDPR', 'US_CANSPAM', 'APAC'
    primary_email VARCHAR(100) NOT NULL
);

CREATE TABLE marketing_consent_log (
    consent_id VARCHAR(32) PRIMARY KEY,
    customer_id VARCHAR(32) NOT NULL,
    channel VARCHAR(20) NOT NULL,          -- 'EMAIL', 'SMS', 'PUSH'
    consent_status VARCHAR(20),            -- 'OPT_IN', 'OPT_OUT', or NULL (legacy unrecorded)
    captured_timestamp TEXT,
    FOREIGN KEY (customer_id) REFERENCES customer_privacy_profiles(customer_id)
);

-- Seed realistic enterprise customer profiles across jurisdictions
INSERT INTO customer_privacy_profiles VALUES
('CUST-001', 'Elena Rostova', 'EU_GDPR', 'elena@europe.de'),
('CUST-002', 'Liam O''Connor', 'EU_GDPR', 'liam@dublin.ie'),
('CUST-003', 'Johnathan Davis', 'US_CANSPAM', 'jdavis@techcorp.com'),
('CUST-004', 'Sarah Miller', 'US_CANSPAM', 'smiller@consumer.net'),
('CUST-005', 'Marcus Chen', 'APAC', 'mchen@singapore.sg'),
('CUST-006', 'Hannah Schmidt', 'EU_GDPR', 'hannah@berlin.de'),
('CUST-007', 'Robert Taylor', 'US_CANSPAM', 'rtaylor@austin.com');

INSERT INTO marketing_consent_log VALUES
-- CUST-001: Explicitly opted in (Eligible everywhere)
('CS-101', 'CUST-001', 'EMAIL', 'OPT_IN', '2024-01-15 10:00:00'),
-- CUST-002: Explicitly opted out (Ineligible everywhere)
('CS-102', 'CUST-002', 'EMAIL', 'OPT_OUT', '2024-02-20 14:30:00'),
-- CUST-003: Legacy record with NULL consent status (Eligible in US under CAN-SPAM, Ineligible in EU under GDPR)
('CS-103', 'CUST-003', 'EMAIL', NULL, '2023-11-10 09:15:00'),
-- CUST-004: Explicitly opted out
('CS-104', 'CUST-004', 'EMAIL', 'OPT_OUT', '2024-03-01 11:45:00'),
-- CUST-005: Legacy record with NULL consent (Eligible in APAC default permissive)
('CS-105', 'CUST-005', 'EMAIL', NULL, '2023-12-05 16:20:00'),
-- CUST-006: Explicitly opted in
('CS-106', 'CUST-006', 'EMAIL', 'OPT_IN', '2024-04-12 08:00:00'),
-- CUST-007: No record in consent log at all (untracked customer)
('CS-107', 'CUST-007', 'SMS', 'OPT_IN', '2024-04-15 12:00:00');

-- --- [SOLUTION QUERY] ---
WITH stg_customer_consents AS (
    -- Step 1: Left join to capture customers who have no email consent record at all
    SELECT 
        p.customer_id,
        p.full_name,
        p.jurisdiction_code,
        p.primary_email,
        c.consent_status AS raw_consent_status
    FROM customer_privacy_profiles p
    LEFT JOIN marketing_consent_log c 
        ON p.customer_id = c.customer_id 
        AND c.channel = 'EMAIL'
),
evaluated_compliance AS (
    -- Step 2: Apply Three-Valued Logic safely using explicit jurisdiction policies
    SELECT 
        customer_id,
        full_name,
        jurisdiction_code,
        primary_email,
        COALESCE(raw_consent_status, 'UNRECORDED_NULL') AS audit_consent_status,
        CASE 
            -- Rule 1: Explicit OPT_OUT is universally disqualified across all legal domains
            WHEN raw_consent_status = 'OPT_OUT' THEN 'EXCLUDED_OPT_OUT'
            
            -- Rule 2: EU GDPR mandates explicit affirmative consent; NULL is non-compliant
            WHEN jurisdiction_code = 'EU_GDPR' AND raw_consent_status = 'OPT_IN' THEN 'ELIGIBLE_GDPR_AFFIRMATIVE'
            WHEN jurisdiction_code = 'EU_GDPR' THEN 'EXCLUDED_GDPR_NO_CONSENT'
            
            -- Rule 3: US CAN-SPAM and APAC permit contact unless explicitly opted out
            WHEN jurisdiction_code IN ('US_CANSPAM', 'APAC') AND (raw_consent_status = 'OPT_IN' OR raw_consent_status IS NULL) 
                THEN 'ELIGIBLE_PERMISSIVE_DEFAULT'
                
            ELSE 'EXCLUDED_UNKNOWN_POLICY'
        END AS compliance_determination
    FROM stg_customer_consents
)
-- Step 3: Dispatch manifest generation selecting strictly legally dispatchable profiles
SELECT 
    customer_id,
    full_name,
    jurisdiction_code,
    primary_email,
    audit_consent_status,
    compliance_determination
FROM evaluated_compliance
WHERE compliance_determination LIKE 'ELIGIBLE%'
ORDER BY jurisdiction_code ASC, customer_id ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 5
-- ASSERT: COL[customer_id] = CUST-005
