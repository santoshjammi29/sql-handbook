-- ============================================================================
-- EXERCISE: 058_slowly_changing_dimension_type_2_historical.sql
-- MODULE:   06_data_modeling_and_scd
-- LEVEL:    Advanced
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   SCD Type 2 (Historical Tracking): When customer address changes, previous
--   address must be preserved for historical sales tax audit compliance.
--   Each version has valid_from, valid_to, and is_current flag.
-- PROBLEM STATEMENT:
--   Execute an SCD Type 2 state transition: expire existing record and insert new active row.
-- ============================================================================

DROP TABLE IF EXISTS dim_customer_scd2;
CREATE TABLE dim_customer_scd2 (
    surrogate_key INT PRIMARY KEY,
    customer_id INT,
    customer_name VARCHAR(100),
    state_code VARCHAR(2),
    valid_from TEXT,
    valid_to TEXT,
    is_current INT
);

INSERT INTO dim_customer_scd2 VALUES
(1, 101, 'Alice Smith', 'NY', '2023-01-01', '9999-12-31', 1);

-- Step 1: Expire old active row
UPDATE dim_customer_scd2
SET valid_to = '2024-05-01', is_current = 0
WHERE customer_id = 101 AND is_current = 1;

-- Step 2: Insert new active row
INSERT INTO dim_customer_scd2 VALUES
(2, 101, 'Alice Smith', 'CA', '2024-05-01', '9999-12-31', 1);

-- --- [SOLUTION QUERY] ---
SELECT 
    surrogate_key,
    customer_id,
    state_code,
    valid_from,
    valid_to,
    is_current
FROM dim_customer_scd2
WHERE customer_id = 101
ORDER BY valid_from ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 2
-- ASSERT: COL[state_code] = NY
