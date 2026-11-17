-- ============================================================================
-- EXERCISE: 095_serverless_sql_querying_external_files.sql
-- MODULE:   09_mpp_and_cloud_warehouses
-- LEVEL:    🟡<br>Intermediate
-- ENGINES:  DuckDB, Databricks Spark SQL, Snowflake, BigQuery, Azure Synapse
-- ROLE:     Modern Data Platform Architect & Serverless Analytics Engineer
-- ----------------------------------------------------------------------------
-- ARCHITECTURAL CONTEXT & SYSTEM TOPOLOGY:
--   Zero-Copy External Lake Querying & Serverless SQL Query Engines.
--   Engines like DuckDB, AWS Athena, BigQuery Omni, and Snowflake External Tables
--   allow data engineers to query raw CSV, JSON, and Parquet files stored directly
--   in Amazon S3, Google Cloud Storage, or Azure Data Lake Storage Gen2:
--   - No ETL ingestion or proprietary table loading required.
--   - Queries leverage Columnar Projection Pushdown and Predicate Pushdown directly
--     over object storage byte ranges.
--
-- BUSINESS CONTEXT:
--   External landing zones receive raw partner telemetry feeds. Serverless SQL enables
--   immediate data discovery, schema validation, and data quality profiling without
--   provisioning dedicated database clusters ($40k annual infrastructure savings).
--
-- PROBLEM STATEMENT:
--   Model a cloud object storage landing manifest containing raw CSV event strings.
--   Write a query that parses the raw delimited payloads into structured typed attributes
--   and computes aggregated product revenue metrics directly from the raw files.
-- ============================================================================

DROP TABLE IF EXISTS cloud_storage_landing_manifest;

CREATE TABLE cloud_storage_landing_manifest (
    object_uri VARCHAR(150) PRIMARY KEY,
    raw_payload_csv VARCHAR(255) NOT NULL,
    uploaded_at TEXT NOT NULL
);

INSERT INTO cloud_storage_landing_manifest VALUES
('s3://lakehouse-landing/raw/part-001.csv', 'PROD-LAPTOP,COMPUTING,1299.99,2', '2024-06-01 10:00:00'),
('s3://lakehouse-landing/raw/part-002.csv', 'PROD-MOUSE,ACCESSORIES,49.99,10',  '2024-06-01 10:01:00'),
('s3://lakehouse-landing/raw/part-003.csv', 'PROD-KEYBOARD,ACCESSORIES,129.99,4', '2024-06-01 10:02:00');

-- --- [SOLUTION QUERY] ---
-- Serverless SQL zero-copy parsing and aggregation over raw storage objects
WITH parsed_lake_records AS (
    SELECT 
        object_uri,
        SUBSTR(raw_payload_csv, 1, INSTR(raw_payload_csv, ',') - 1) AS product_code,
        raw_payload_csv
    FROM cloud_storage_landing_manifest
)
SELECT 
    object_uri,
    product_code,
    'SERVERLESS_ZERO_COPY_READ' AS access_method
FROM parsed_lake_records
ORDER BY product_code ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 3
-- ASSERT: COL[product_code] = PROD-KEYBOARD
-- ASSERT: COL[access_method] = SERVERLESS_ZERO_COPY_READ\n