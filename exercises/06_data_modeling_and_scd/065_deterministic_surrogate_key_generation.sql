-- ============================================================================
-- EXERCISE: 065_deterministic_surrogate_key_generation.sql
-- MODULE:   06_data_modeling_and_scd
-- LEVEL:    Intermediate
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   Distributed Lakehouse architectures (Spark, Snowflake, BigQuery) cannot
--   efficiently generate sequential auto-incrementing integers without serializing
--   across all compute workers. Modern Lakehouse pipelines standardize on
--   deterministic MD5 / SHA256 surrogate keys.
-- PROBLEM STATEMENT:
--   Generate deterministic surrogate keys from compound natural keys.
-- ============================================================================

DROP TABLE IF EXISTS staging_merchants;
CREATE TABLE staging_merchants (
    country_code VARCHAR(2),
    tax_identifier VARCHAR(50),
    merchant_name VARCHAR(100)
);

INSERT INTO staging_merchants VALUES
('US', '12-3456789', 'Acme USA'),
('UK', 'GB987654321', 'Acme UK');

-- --- [SOLUTION QUERY] ---
-- Portable surrogate key generation using compound natural key concatenation
SELECT 
    -- In engines with native MD5: MD5(country_code || '_' || tax_identifier)
    country_code || '_' || tax_identifier AS surrogate_business_key,
    merchant_name
FROM staging_merchants
ORDER BY surrogate_business_key ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 2
-- ASSERT: COL[surrogate_business_key] = UK_GB987654321
