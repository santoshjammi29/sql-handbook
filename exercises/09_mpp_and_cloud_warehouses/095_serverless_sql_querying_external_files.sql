-- ============================================================================
-- EXERCISE: 095_serverless_sql_querying_external_files.sql
-- MODULE:   09_mpp_and_cloud_warehouses
-- LEVEL:    Intermediate
-- ENGINES:  DuckDB, Databricks Spark SQL, Snowflake, BigQuery, Azure Synapse
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   Serverless SQL (DuckDB, Synapse Serverless, BigQuery Omni): Querying external
--   Parquet and CSV files directly on object storage without provisioning dedicated clusters.
-- PROBLEM STATEMENT:
--   Demonstrate querying semi-structured raw payloads and extracting tabular attributes.
-- ============================================================================

DROP TABLE IF EXISTS external_landing_zone;
CREATE TABLE external_landing_zone (
    file_name VARCHAR(100),
    raw_csv_line VARCHAR(255)
);

INSERT INTO external_landing_zone VALUES
('part-0001.csv', '101,Laptop,1200.00'),
('part-0001.csv', '102,Phone,800.00');

-- --- [SOLUTION QUERY] ---
SELECT 
    file_name,
    SUBSTR(raw_csv_line, 1, INSTR(raw_csv_line, ',') - 1) AS product_id,
    raw_csv_line
FROM external_landing_zone
ORDER BY product_id ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 2
-- ASSERT: COL[product_id] = 101
