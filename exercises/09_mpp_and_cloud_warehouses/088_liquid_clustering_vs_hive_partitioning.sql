-- ============================================================================
-- EXERCISE: 088_liquid_clustering_vs_hive_partitioning.sql
-- MODULE:   09_mpp_and_cloud_warehouses
-- LEVEL:    🔴<br>Advanced
-- ENGINES:  Databricks Spark SQL, Snowflake, BigQuery, PostgreSQL, DuckDB, SQLite
-- ROLE:     Principal Lakehouse Data Architect & Databricks Specialist
-- ----------------------------------------------------------------------------
-- ARCHITECTURAL CONTEXT & SYSTEM TOPOLOGY:
--   Modern Delta Lake Liquid Clustering vs Legacy Hive Physical Directory Layouts.
--   Legacy Hive Partitioning (`/year=2024/month=05/day=15/region=US/`):
--   - Creates tens of thousands of tiny directories and sub-10MB Parquet files.
--   - Causes file system metadata bottleneck during partition discovery and directory listing.
--   - Inflexible: Adding or changing partition columns requires full table re-writes!
--   Databricks Delta Lake Liquid Clustering (`CLUSTER BY (event_date, region, device_type)`):
--   - Stores data in flat directories while clustering rows along space-filling Z-order curves.
--   - Automatically avoids small file explosion while maintaining multi-dimensional pruning.
--   - Flexible: Clustering keys can be updated at any time without data re-layout!
--
-- BUSINESS CONTEXT:
--   An enterprise IoT fleet streams 5 billion daily telemetry events. Switching from Hive
--   partitioning to Liquid Clustering reduced cloud storage API costs by 80% and boosted
--   p95 analytics query speed by 4x.
--
-- PROBLEM STATEMENT:
--   Model file metadata for a telemetry lakehouse table under both architectures.
--   Write an analytical comparison query auditing file fragmentation, average file size,
--   and partition pruning effectiveness.
-- ============================================================================

DROP TABLE IF EXISTS lakehouse_storage_audit;

CREATE TABLE lakehouse_storage_audit (
    file_id VARCHAR(32) PRIMARY KEY,
    architecture_type VARCHAR(30) NOT NULL, -- HIVE_PARTITIONED, LIQUID_CLUSTERED
    region_code VARCHAR(10) NOT NULL,
    file_size_mb DECIMAL(8, 2) NOT NULL,
    row_count INT NOT NULL,
    pruning_eligible INT NOT NULL -- 1 if pruned by multi-column query, 0 if scanned
);

INSERT INTO lakehouse_storage_audit VALUES
-- Legacy Hive Partitioning: Over-partitioned into tiny sub-optimal files
('FILE-HIVE-01', 'HIVE_PARTITIONED', 'US_EAST',   4.50,   85000, 1),
('FILE-HIVE-02', 'HIVE_PARTITIONED', 'US_EAST',   3.80,   72000, 1),
('FILE-HIVE-03', 'HIVE_PARTITIONED', 'EU_WEST',   6.20,  120000, 0),
('FILE-HIVE-04', 'HIVE_PARTITIONED', 'EU_WEST',   5.10,   98000, 0),

-- Modern Liquid Clustering: Consolidated larger files with dense clustering stats
('FILE-LIQD-01', 'LIQUID_CLUSTERED', 'US_EAST', 128.00, 2400000, 1),
('FILE-LIQD-02', 'LIQUID_CLUSTERED', 'EU_WEST', 134.50, 2550000, 0);

-- --- [SOLUTION QUERY] ---
-- Architectural comparison: File consolidation and pruning health metrics
SELECT 
    architecture_type,
    COUNT(file_id) AS total_physical_files,
    ROUND(AVG(file_size_mb), 2) AS avg_file_size_mb,
    SUM(row_count) AS total_rows_stored,
    SUM(CASE WHEN pruning_eligible = 1 THEN 1 ELSE 0 END) AS files_pruned,
    CASE 
        WHEN AVG(file_size_mb) < 10.0 THEN 'SEVERE_SMALL_FILE_PROBLEM'
        WHEN AVG(file_size_mb) >= 100.0 THEN 'HEALTHY_CONSOLIDATED_LAKEHOUSE'
    END AS storage_health_verdict
FROM lakehouse_storage_audit
GROUP BY architecture_type
ORDER BY avg_file_size_mb DESC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 2
-- ASSERT: COL[architecture_type] = LIQUID_CLUSTERED
-- ASSERT: COL[avg_file_size_mb] = 131.25
-- ASSERT: COL[storage_health_verdict] = HEALTHY_CONSOLIDATED_LAKEHOUSE\n