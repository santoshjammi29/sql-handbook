-- ============================================================================
-- EXERCISE: 062_data_vault_2_0_hubs_links_satellites.sql
-- MODULE:   06_data_modeling_and_scd
-- LEVEL:    Advanced
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   Data Vault 2.0 Enterprise EDW: Isolates business keys into HUBS, relationships
--   into LINKS, and descriptive/temporal context into SATELLITES for agile schema evolution.
-- PROBLEM STATEMENT:
--   Model and query a complete Data Vault 2.0 triangle: Hub Customer, Hub Account,
--   Link Customer-Account, and Satellite Customer Details.
-- ============================================================================

DROP TABLE IF EXISTS sat_customer;
DROP TABLE IF EXISTS link_customer_account;
DROP TABLE IF EXISTS hub_account;
DROP TABLE IF EXISTS hub_customer;

CREATE TABLE hub_customer (
    h_customer_hash VARCHAR(32) PRIMARY KEY,
    customer_id INT,
    load_date TEXT
);

CREATE TABLE hub_account (
    h_account_hash VARCHAR(32) PRIMARY KEY,
    account_number VARCHAR(20),
    load_date TEXT
);

CREATE TABLE link_customer_account (
    l_cust_acc_hash VARCHAR(32) PRIMARY KEY,
    h_customer_hash VARCHAR(32),
    h_account_hash VARCHAR(32),
    load_date TEXT
);

CREATE TABLE sat_customer (
    h_customer_hash VARCHAR(32),
    load_date TEXT,
    customer_name VARCHAR(100),
    email VARCHAR(100),
    PRIMARY KEY (h_customer_hash, load_date)
);

INSERT INTO hub_customer VALUES ('HASH_C1', 101, '2024-01-01');
INSERT INTO hub_account VALUES ('HASH_A1', 'ACC-999', '2024-01-01');
INSERT INTO link_customer_account VALUES ('HASH_L1', 'HASH_C1', 'HASH_A1', '2024-01-01');
INSERT INTO sat_customer VALUES ('HASH_C1', '2024-01-01', 'Alice Smith', 'alice@example.com');

-- --- [SOLUTION QUERY] ---
SELECT 
    c.customer_id,
    s.customer_name,
    s.email,
    a.account_number
FROM hub_customer c
JOIN link_customer_account l ON c.h_customer_hash = l.h_customer_hash
JOIN hub_account a ON l.h_account_hash = a.h_account_hash
JOIN sat_customer s ON c.h_customer_hash = s.h_customer_hash;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 1
-- ASSERT: COL[account_number] = ACC-999
