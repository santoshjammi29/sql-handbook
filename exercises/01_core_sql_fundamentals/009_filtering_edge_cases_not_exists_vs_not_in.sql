-- ============================================================================
-- EXERCISE: 009_filtering_edge_cases_not_exists_vs_not_in.sql
-- MODULE:   01_core_sql_fundamentals
-- LEVEL:    🟢<br>Beginner
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ROLE:     Lead Data Architect & Anti-Financial Crime Lead
-- ----------------------------------------------------------------------------
-- ARCHITECTURAL CONTEXT & SYSTEM TOPOLOGY:
--   International Wire Transfer Anti-Money Laundering (AML) Compliance Engine.
--   Cross-border wire payments must be screened against the Office of Foreign Assets
--   Control (OFAC) sanctions watchlist. A catastrophic vulnerability was introduced
--   when a junior engineer filtered sanctioned beneficiaries using 'NOT IN'.
--
-- BUSINESS CONTEXT:
--   1. The NOT IN (NULL) Trap: If the subquery in 'WHERE x NOT IN (SELECT y FROM ...)'
--      returns even a SINGLE NULL value, the entire predicate evaluates to UNKNOWN
--      for ALL candidate records! Because WHERE filters discard UNKNOWN, ZERO records
--      are returned, silently halting or corrupting downstream pipelines.
--   2. Production Standard: Professional data engineers use 'NOT EXISTS' or
--      'LEFT JOIN ... WHERE right.key IS NULL'. 'NOT EXISTS' uses two-valued logic
--      (a row exists or it doesn't) and is completely immune to NULL values.
--
-- PROBLEM STATEMENT:
--   1. Seed an OFAC sanctions watchlist containing an intentional NULL record.
--   2. Demonstrate how NOT IN fails while NOT EXISTS safely filters out sanctioned
--      recipients without dropping legitimate cross-border transfers.
-- ============================================================================

DROP TABLE IF EXISTS ofac_sanctioned_entities;
DROP TABLE IF EXISTS inbound_wire_transfers;

CREATE TABLE ofac_sanctioned_entities (
    sanction_id VARCHAR(32) PRIMARY KEY,
    entity_name VARCHAR(100) NOT NULL,
    tax_identifier VARCHAR(50) -- Contains NULLs for unverified entities!
);

CREATE TABLE inbound_wire_transfers (
    wire_id VARCHAR(32) PRIMARY KEY,
    sender_name VARCHAR(100) NOT NULL,
    beneficiary_name VARCHAR(100) NOT NULL,
    beneficiary_tax_id VARCHAR(50) NOT NULL,
    transfer_amount_usd DECIMAL(12, 2) NOT NULL,
    origin_country VARCHAR(3) NOT NULL
);

-- Seed sanctions list with an intentional NULL tax identifier
INSERT INTO ofac_sanctioned_entities VALUES
('SANC-01', 'Illicit Shadow Trading Corp', 'TAX-99901'),
('SANC-02', 'Covert Nuclear Procurement Co', 'TAX-99902'),
('SANC-03', 'Unidentified Rogue Shell Entity', NULL); -- Critical NULL record!

-- Seed inbound wire transfers
INSERT INTO inbound_wire_transfers VALUES
('WIR-001', 'Global Logistics Ltd', 'Legitimate Vendor Alpha', 'TAX-11101', 50000.00, 'CAN'),
('WIR-002', 'Maritime Supply LLC', 'Illicit Shadow Trading Corp', 'TAX-99901', 120000.00, 'CYP'), -- Sanctioned!
('WIR-003', 'European Energy Group', 'Legitimate Partner Beta', 'TAX-11102', 850000.00, 'DEU'),
('WIR-004', 'Apex Retail Holdings', 'Covert Nuclear Procurement Co', 'TAX-99902', 45000.00, 'UAE'), -- Sanctioned!
('WIR-005', 'Pacific Import Export', 'Legitimate Vendor Gamma', 'TAX-11103', 32000.00, 'SGP');

-- --- [SOLUTION QUERY] ---
-- Production-grade filtering using NOT EXISTS (Immune to NULLs and highly optimized by CBOs)
WITH screened_transfers AS (
    SELECT 
        w.wire_id,
        w.sender_name,
        w.beneficiary_name,
        w.beneficiary_tax_id,
        w.transfer_amount_usd,
        w.origin_country
    FROM inbound_wire_transfers w
    WHERE NOT EXISTS (
        SELECT 1 
        FROM ofac_sanctioned_entities s
        WHERE s.tax_identifier = w.beneficiary_tax_id
    )
)
SELECT 
    wire_id,
    sender_name,
    beneficiary_name,
    beneficiary_tax_id,
    transfer_amount_usd,
    origin_country,
    'CLEARED_FOR_SETTLEMENT' AS compliance_status
FROM screened_transfers
ORDER BY transfer_amount_usd DESC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 3
-- ASSERT: COL[wire_id] = WIR-003
