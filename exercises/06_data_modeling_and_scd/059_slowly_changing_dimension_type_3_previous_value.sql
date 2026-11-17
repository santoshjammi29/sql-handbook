-- ============================================================================
-- EXERCISE: 059_slowly_changing_dimension_type_3_previous_value.sql
-- MODULE:   06_data_modeling_and_scd
-- LEVEL:    Intermediate
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   SCD Type 3 (Prior Value Column): Sales territory realignment requires
--   tracking both the Current Sales Territory and the Previous Sales Territory
--   side-by-side without adding new table rows.
-- PROBLEM STATEMENT:
--   Implement SCD Type 3 updating current_territory and shifting old value to prev_territory.
-- ============================================================================

DROP TABLE IF EXISTS dim_sales_rep_scd3;
CREATE TABLE dim_sales_rep_scd3 (
    rep_id INT PRIMARY KEY,
    rep_name VARCHAR(50),
    current_territory VARCHAR(50),
    prev_territory VARCHAR(50),
    effective_date TEXT
);

INSERT INTO dim_sales_rep_scd3 VALUES
(1, 'Bob Jones', 'North', NULL, '2023-01-01');

-- Transition rep from North to West
UPDATE dim_sales_rep_scd3
SET prev_territory = current_territory,
    current_territory = 'West',
    effective_date = '2024-06-01'
WHERE rep_id = 1;

-- --- [SOLUTION QUERY] ---
SELECT rep_id, rep_name, current_territory, prev_territory, effective_date 
FROM dim_sales_rep_scd3 
WHERE rep_id = 1;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 1
-- ASSERT: COL[current_territory] = West
-- ASSERT: COL[prev_territory] = North
