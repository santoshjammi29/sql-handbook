-- ============================================================================
-- EXERCISE: 060_slowly_changing_dimension_type_4_mini_dimensions.sql
-- MODULE:   06_data_modeling_and_scd
-- LEVEL:    Advanced
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   SCD Type 4 (Mini-Dimensions): High-frequency changing customer attributes
--   (credit score band, annual income tier, age group) would cause an SCD Type 2
--   table to explode to billions of rows. Mini-dimensions extract these into a
--   small, pre-calculated profile lookup table.
-- PROBLEM STATEMENT:
--   Model and query a Type 4 mini-dimension linked to a base customer dimension.
-- ============================================================================

DROP TABLE IF EXISTS customer_profile_history;
DROP TABLE IF EXISTS dim_demographic_bands;
DROP TABLE IF EXISTS dim_customer_base;

CREATE TABLE dim_customer_base (
    customer_id INT PRIMARY KEY,
    customer_name VARCHAR(100)
);

CREATE TABLE dim_demographic_bands (
    band_id INT PRIMARY KEY,
    credit_score_band VARCHAR(20),
    income_tier VARCHAR(20)
);

CREATE TABLE customer_profile_history (
    customer_id INT,
    band_id INT,
    assigned_date TEXT,
    PRIMARY KEY (customer_id, assigned_date)
);

INSERT INTO dim_customer_base VALUES (1, 'Alice Smith');
INSERT INTO dim_demographic_bands VALUES (101, '600-699 (Fair)', 'Mid Income'), (102, '700-799 (Good)', 'High Income');
INSERT INTO customer_profile_history VALUES (1, 101, '2023-01-01'), (1, 102, '2024-01-01');

-- --- [SOLUTION QUERY] ---
SELECT 
    c.customer_name,
    h.assigned_date,
    b.credit_score_band,
    b.income_tier
FROM dim_customer_base c
JOIN customer_profile_history h ON c.customer_id = h.customer_id
JOIN dim_demographic_bands b ON h.band_id = b.band_id
ORDER BY h.assigned_date DESC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 2
-- ASSERT: COL[credit_score_band] = 700-799 (Good)
