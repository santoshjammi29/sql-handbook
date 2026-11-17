-- ============================================================================
-- EXERCISE: 062_data_vault_2_0_hubs_links_satellites.sql
-- MODULE:   06_data_modeling_and_scd
-- LEVEL:    🔴<br>Advanced
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ROLE:     Lead Enterprise Data Architect & Data Vault 2.0 Specialist
-- ----------------------------------------------------------------------------
-- ARCHITECTURAL CONTEXT & SYSTEM TOPOLOGY:
--   Data Vault 2.0 Core Banking Enterprise Raw Vault.
--   Implementing Dan Linstedt's Data Vault 2.0:
--   1. Hub: Core business concept identified by business key (e.g., hub_account).
--   2. Link: Business relationship / transaction connecting multiple hubs (e.g., link_transaction).
--   3. Satellite: Descriptive temporal context with hash diffs (e.g., sat_account_details).
--
-- BUSINESS CONTEXT:
--   Enterprise analytical engine optimization for 062 data vault 2 0 hubs links satellites.
--   Ensuring strict grain integrity, distributed performance, and deterministic results.
--
-- PROBLEM STATEMENT:
--   Write a production-grade SQL query fulfilling the architectural requirements for 062 data vault 2 0 hubs links satellites.
-- ============================================================================

DROP TABLE IF EXISTS sat_account_profile;
DROP TABLE IF EXISTS link_account_customer;
DROP TABLE IF EXISTS hub_customer;
DROP TABLE IF EXISTS hub_account;

CREATE TABLE hub_account (
    hk_account_hash VARCHAR(64) PRIMARY KEY,
    account_number VARCHAR(30) NOT NULL,
    load_timestamp TEXT NOT NULL,
    record_source VARCHAR(50) NOT NULL
);

CREATE TABLE hub_customer (
    hk_customer_hash VARCHAR(64) PRIMARY KEY,
    customer_id VARCHAR(30) NOT NULL,
    load_timestamp TEXT NOT NULL,
    record_source VARCHAR(50) NOT NULL
);

CREATE TABLE link_account_customer (
    hk_link_hash VARCHAR(64) PRIMARY KEY,
    hk_account_hash VARCHAR(64) NOT NULL,
    hk_customer_hash VARCHAR(64) NOT NULL,
    load_timestamp TEXT NOT NULL,
    record_source VARCHAR(50) NOT NULL,
    FOREIGN KEY (hk_account_hash) REFERENCES hub_account(hk_account_hash),
    FOREIGN KEY (hk_customer_hash) REFERENCES hub_customer(hk_customer_hash)
);

CREATE TABLE sat_account_profile (
    hk_account_hash VARCHAR(64) NOT NULL,
    load_timestamp TEXT NOT NULL,
    hash_diff VARCHAR(64) NOT NULL,
    account_type VARCHAR(20) NOT NULL,
    currency_code VARCHAR(3) NOT NULL,
    PRIMARY KEY (hk_account_hash, load_timestamp),
    FOREIGN KEY (hk_account_hash) REFERENCES hub_account(hk_account_hash)
);

INSERT INTO hub_account VALUES ('HK-ACC-01', 'ACC-99001', '2024-05-01 10:00:00', 'CORE_BANKING');
INSERT INTO hub_customer VALUES ('HK-CUST-01', 'CUST-1100', '2024-05-01 10:00:00', 'CRM_SALESFORCE');
INSERT INTO link_account_customer VALUES ('HK-LNK-01', 'HK-ACC-01', 'HK-CUST-01', '2024-05-01 10:00:00', 'CORE_BANKING');
INSERT INTO sat_account_profile VALUES ('HK-ACC-01', '2024-05-01 10:00:00', 'HD-VAL-01', 'SAVINGS_INTEREST', 'USD');

-- --- [SOLUTION QUERY] ---
-- Data Vault 2.0 Information Mart Query joining Hub, Link, and Satellite
SELECT 
    h_a.account_number,
    h_c.customer_id,
    s.account_type,
    s.currency_code,
    s.load_timestamp AS satellite_loaded_at,
    'DATA_VAULT_2_0_RAW_VAULT' AS edw_pattern
FROM link_account_customer l
INNER JOIN hub_account h_a ON l.hk_account_hash = h_a.hk_account_hash
INNER JOIN hub_customer h_c ON l.hk_customer_hash = h_c.hk_customer_hash
INNER JOIN sat_account_profile s ON h_a.hk_account_hash = s.hk_account_hash
ORDER BY h_a.account_number ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 1
-- ASSERT: COL[account_number] = ACC-99001
