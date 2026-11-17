-- ============================================================================
-- EXERCISE: 091_broadcast_vs_shuffle_join_thresholds.sql
-- MODULE:   09_mpp_and_cloud_warehouses
-- LEVEL:    Intermediate
-- ENGINES:  Databricks Spark SQL, Snowflake, BigQuery, PostgreSQL, DuckDB, SQLite
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   Distributed join mechanics: If a table is below the broadcast threshold
--   (e.g. 10MB in Spark), it is broadcast to all workers, avoiding a network
--   shuffle of the 500GB fact table.
-- PROBLEM STATEMENT:
--   Demonstrate joining a large fact table to a tiny lookup dimension.
-- ============================================================================

DROP TABLE IF EXISTS fact_clickstream;
DROP TABLE IF EXISTS dim_device_type;

CREATE TABLE fact_clickstream (click_id INT PRIMARY KEY, device_id INT, page VARCHAR(50));
CREATE TABLE dim_device_type (device_id INT PRIMARY KEY, device_name VARCHAR(50));

INSERT INTO fact_clickstream VALUES (1, 1, 'home'), (2, 2, 'cart'), (3, 1, 'checkout');
INSERT INTO dim_device_type VALUES (1, 'Desktop'), (2, 'Mobile');

-- --- [SOLUTION QUERY] ---
SELECT 
    f.click_id,
    d.device_name,
    f.page
FROM fact_clickstream f
JOIN dim_device_type d ON f.device_id = d.device_id
ORDER BY f.click_id ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 3
-- ASSERT: COL[device_name] = Desktop
