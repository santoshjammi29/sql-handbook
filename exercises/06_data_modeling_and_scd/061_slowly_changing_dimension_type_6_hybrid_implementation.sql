-- ============================================================================
-- EXERCISE: 061_slowly_changing_dimension_type_6_hybrid_implementation.sql
-- MODULE:   06_data_modeling_and_scd
-- LEVEL:    🔴<br>Advanced
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ROLE:     Lead Enterprise Data Architect & Dimensional Modeler
-- ----------------------------------------------------------------------------
-- ARCHITECTURAL CONTEXT & SYSTEM TOPOLOGY:
--   SCD Type 6 Hybrid Implementation (Type 1 + Type 2 + Type 3).
--   Combining:
--   - Type 2: Historical record versioning with valid_from and valid_to dates.
--   - Type 3: Historical attribute preservation (previous_value).
--   - Type 1: Overwriting current attribute across ALL historical rows for that entity!
--
-- BUSINESS CONTEXT:
--   Enterprise analytical engine optimization for 061 slowly changing dimension type 6 hybrid implementation.
--   Ensuring strict grain integrity, distributed performance, and deterministic results.
--
-- PROBLEM STATEMENT:
--   Write a production-grade SQL query fulfilling the architectural requirements for 061 slowly changing dimension type 6 hybrid implementation.
-- ============================================================================

DROP TABLE IF EXISTS dim_sales_rep_scd6;

CREATE TABLE dim_sales_rep_scd6 (
    surrogate_key INT PRIMARY KEY,
    rep_id VARCHAR(32) NOT NULL,
    historic_territory VARCHAR(50) NOT NULL, -- Type 2 (historical value at that point in time)
    current_territory VARCHAR(50) NOT NULL,  -- Type 1 (current value stamped on all rows!)
    valid_from TEXT NOT NULL,
    valid_to TEXT NOT NULL,
    is_current INT NOT NULL
);

INSERT INTO dim_sales_rep_scd6 VALUES
-- Rep R-01 moved from West to East, but current_territory is updated to 'EAST' on all rows!
(1, 'R-01', 'WEST', 'EAST', '2023-01-01', '2024-03-31', 0),
(2, 'R-01', 'EAST', 'EAST', '2024-04-01', '9999-12-31', 1);

-- --- [SOLUTION QUERY] ---
-- Query demonstrating SCD6: Filter by historical territory OR by current territory
SELECT 
    rep_id,
    historic_territory,
    current_territory,
    valid_from,
    valid_to,
    is_current,
    'SCD6_HYBRID_ROW' AS scd_architecture
FROM dim_sales_rep_scd6
ORDER BY surrogate_key ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 2
-- ASSERT: COL[rep_id] = R-01
