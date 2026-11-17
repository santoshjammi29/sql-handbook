-- ============================================================================
-- EXERCISE: 061_slowly_changing_dimension_type_6_hybrid_implementation.sql
-- MODULE:   06_data_modeling_and_scd
-- LEVEL:    Advanced
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   SCD Type 6 (1 + 2 + 3): Combines full row history (Type 2) with an in-place
--   current attribute column (Type 1) populated across ALL historical rows for that entity.
-- PROBLEM STATEMENT:
--   Implement SCD Type 6 where updating the active record also cascades the
--   current_state value back to all historical records.
-- ============================================================================

DROP TABLE IF EXISTS dim_customer_scd6;
CREATE TABLE dim_customer_scd6 (
    surrogate_key INT PRIMARY KEY,
    customer_id INT,
    historical_state VARCHAR(2),
    current_state VARCHAR(2),
    valid_from TEXT,
    valid_to TEXT,
    is_current INT
);

INSERT INTO dim_customer_scd6 VALUES
(1, 101, 'NY', 'NY', '2023-01-01', '2024-05-01', 0),
(2, 101, 'CA', 'CA', '2024-05-01', '9999-12-31', 1);

-- Type 6 rule: Overwrite current_state on historical rows to match latest active row!
UPDATE dim_customer_scd6
SET current_state = 'CA'
WHERE customer_id = 101;

-- --- [SOLUTION QUERY] ---
SELECT 
    surrogate_key,
    customer_id,
    historical_state,
    current_state,
    is_current
FROM dim_customer_scd6
WHERE customer_id = 101
ORDER BY surrogate_key ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 2
-- ASSERT: COL[historical_state] = NY
-- ASSERT: COL[current_state] = CA
