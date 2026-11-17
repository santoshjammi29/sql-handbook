-- ============================================================================
-- EXERCISE: 086_snowflake_micropartition_pruning.sql
-- MODULE:   09_mpp_and_cloud_warehouses
-- LEVEL:    🔴<br>Advanced
-- ENGINES:  Snowflake, Databricks Spark SQL, BigQuery, PostgreSQL, DuckDB, SQLite
-- ROLE:     Principal Cloud Data Architect & Snowflake Performance Specialist
-- ----------------------------------------------------------------------------
-- ARCHITECTURAL CONTEXT & SYSTEM TOPOLOGY:
--   Petabyte-Scale Cloud Data Warehouse & Micro-Partition Metadata Pruning.
--   In Snowflake, BigQuery, and Databricks Delta Lake:
--   - Tables are divided into immutable columnar micro-partitions (50MB to 500MB uncompressed).
--   - The central Metadata Catalog / Cloud Services Layer maintains rich column statistics:
--     min_value, max_value, null_count, and distinct_count for every column in every micro-partition.
--   - When a query contains a predicate like:
--     WHERE event_timestamp BETWEEN '2024-05-16 00:00:00' AND '2024-05-16 23:59:59'
--     the Cloud Services Coordinator evaluates partition min/max bounds in microseconds,
--     completely PRUNING non-overlapping partitions before a single compute worker is allocated!
--
-- BUSINESS CONTEXT:
--   Scanning full tables in cloud warehouses burns thousands of dollars in compute credits.
--   Effective micro-partition pruning slashes query execution time from 10 minutes to 3 seconds
--   and reduces warehouse compute bills by up to 95%.
--
-- PROBLEM STATEMENT:
--   Model a cloud warehouse metadata catalog tracking 4 micro-partitions of an enterprise
--   audit event table. Write a query simulating the metadata pruning optimizer for a target
--   query searching for events on '2024-05-16' in tenant 'TNT-US-CORP'.
--   Calculate partitions scanned vs pruned and row scanning efficiency.
-- ============================================================================

DROP TABLE IF EXISTS micropartition_catalog;

CREATE TABLE micropartition_catalog (
    partition_id VARCHAR(32) PRIMARY KEY,
    min_event_time TEXT NOT NULL,
    max_event_time TEXT NOT NULL,
    min_tenant_id VARCHAR(32) NOT NULL,
    max_tenant_id VARCHAR(32) NOT NULL,
    compressed_bytes INT NOT NULL,
    row_count INT NOT NULL
);

INSERT INTO micropartition_catalog VALUES
('MP-001', '2024-05-01 00:00:00', '2024-05-07 23:59:59', 'TNT-APAC-001', 'TNT-EU-099',  104857600, 2500000),
('MP-002', '2024-05-08 00:00:00', '2024-05-14 23:59:59', 'TNT-APAC-001', 'TNT-US-999',  112197632, 2800000),
('MP-003', '2024-05-15 00:00:00', '2024-05-21 23:59:59', 'TNT-EU-001',   'TNT-US-CORP', 125829120, 3100000),
('MP-004', '2024-05-22 00:00:00', '2024-05-28 23:59:59', 'TNT-US-CORP', 'TNT-US-ZED',  108003328, 2600000);

-- --- [SOLUTION QUERY] ---
-- Query optimizer evaluation: targeting '2024-05-16 14:00:00' and 'TNT-US-CORP'
WITH optimizer_pruning_decision AS (
    SELECT 
        partition_id,
        min_event_time,
        max_event_time,
        min_tenant_id,
        max_tenant_id,
        row_count,
        compressed_bytes,
        CASE 
            WHEN '2024-05-16 14:00:00' BETWEEN min_event_time AND max_event_time
             AND 'TNT-US-CORP' BETWEEN min_tenant_id AND max_tenant_id
            THEN 'SCAN_CANDIDATE'
            ELSE 'METADATA_PRUNED'
        END AS pruning_verdict
    FROM micropartition_catalog
)
SELECT 
    COUNT(*) AS total_partitions_in_table,
    SUM(CASE WHEN pruning_verdict = 'SCAN_CANDIDATE' THEN 1 ELSE 0 END) AS partitions_scanned,
    SUM(CASE WHEN pruning_verdict = 'METADATA_PRUNED' THEN 1 ELSE 0 END) AS partitions_pruned,
    SUM(CASE WHEN pruning_verdict = 'SCAN_CANDIDATE' THEN row_count ELSE 0 END) AS rows_scanned_by_warehouse,
    SUM(CASE WHEN pruning_verdict = 'METADATA_PRUNED' THEN row_count ELSE 0 END) AS rows_avoided_by_pruning,
    ROUND(100.0 * SUM(CASE WHEN pruning_verdict = 'METADATA_PRUNED' THEN row_count ELSE 0 END) / SUM(row_count), 2) AS pruning_efficiency_pct
FROM optimizer_pruning_decision;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 1
-- ASSERT: COL[total_partitions_in_table] = 4
-- ASSERT: COL[partitions_scanned] = 1
-- ASSERT: COL[partitions_pruned] = 3
-- ASSERT: COL[rows_scanned_by_warehouse] = 3100000\n