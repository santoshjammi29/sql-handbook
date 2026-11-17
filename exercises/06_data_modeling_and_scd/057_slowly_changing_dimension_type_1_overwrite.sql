-- ============================================================================
-- EXERCISE: 057_slowly_changing_dimension_type_1_overwrite.sql
-- MODULE:   06_data_modeling_and_scd
-- LEVEL:    Intermediate
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   SCD Type 1 (In-Place Overwrite): When correcting spelling errors or non-historical
--   attributes (e.g. fixing customer phone number), the prior value is overwritten
--   and no historical versions are retained.
-- PROBLEM STATEMENT:
--   Apply an SCD Type 1 update ensuring audit timestamps are maintained.
-- ============================================================================

DROP TABLE IF EXISTS dim_customer_scd1;
CREATE TABLE dim_customer_scd1 (
    customer_id INT PRIMARY KEY,
    customer_name VARCHAR(100),
    phone_number VARCHAR(20),
    last_updated_at TEXT
);

INSERT INTO dim_customer_scd1 VALUES
(1, 'Alice Smith', '555-0000', '2024-01-01 10:00:00');

-- SCD Type 1 Update
UPDATE dim_customer_scd1 
SET phone_number = '555-9999', 
    last_updated_at = '2024-05-15 14:30:00'
WHERE customer_id = 1;

-- --- [SOLUTION QUERY] ---
SELECT customer_id, customer_name, phone_number, last_updated_at 
FROM dim_customer_scd1 
WHERE customer_id = 1;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 1
-- ASSERT: COL[phone_number] = 555-9999
