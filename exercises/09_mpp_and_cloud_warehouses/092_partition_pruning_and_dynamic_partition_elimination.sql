-- ============================================================================
-- EXERCISE: 092_partition_pruning_and_dynamic_partition_elimination.sql
-- MODULE:   09_mpp_and_cloud_warehouses
-- LEVEL:    🔴<br>Advanced
-- ENGINES:  Snowflake, BigQuery, Databricks Spark SQL, PostgreSQL, DuckDB, SQLite
-- ROLE:     Lead Cloud Warehouse Architect & Query Engine Specialist
-- ----------------------------------------------------------------------------
-- ARCHITECTURAL CONTEXT & SYSTEM TOPOLOGY:
--   Dynamic Partition Pruning (DPP) & Runtime Partition Elimination in MPP Engines.
--   Static Partition Pruning occurs when filters are constants (e.g. `WHERE partition_date = '2024-05-01'`).
--   Dynamic Partition Elimination (DPP) occurs at runtime in Star Schema queries:
--   - Fact table (e.g. 10 billion rows partitioned by `date_key`).
--   - Dimension table `dim_fiscal_calendar` is filtered on `fiscal_quarter = 'Q4_HOLIDAY'`.
--   - The engine evaluates the dimension query first, broadcasts the matching list of `date_key`s
--     directly to the fact table scan operator, and eliminates 90%+ of fact partitions BEFORE
--     reading data blocks from cloud object storage!
--
-- BUSINESS CONTEXT:
--   Without DPP, queries joining partitioned fact tables to dynamic dimension filters
--   perform catastrophic full table scans, burning massive cloud compute budgets.
--
-- PROBLEM STATEMENT:
--   Simulate DPP execution: Model a date-partitioned shipments fact table and fiscal dimension.
--   Write a query that leverages dynamic partition filtering to scan only target holiday dates,
--   verifying that non-qualifying partitions are completely bypassed.
-- ============================================================================

DROP TABLE IF EXISTS dim_fiscal_calendar_dpp;
DROP TABLE IF EXISTS fact_shipments_partitioned;

CREATE TABLE fact_shipments_partitioned (
    shipment_id VARCHAR(32) PRIMARY KEY,
    partition_date TEXT NOT NULL,
    freight_carrier VARCHAR(30) NOT NULL,
    shipping_cost_usd DECIMAL(10, 2) NOT NULL
);

CREATE TABLE dim_fiscal_calendar_dpp (
    cal_date TEXT PRIMARY KEY,
    fiscal_quarter VARCHAR(10) NOT NULL,
    is_peak_holiday_surge INT NOT NULL -- 1 = True, 0 = False
);

INSERT INTO dim_fiscal_calendar_dpp VALUES
('2024-11-28', 'Q4', 1), -- Thanksgiving
('2024-11-29', 'Q4', 1), -- Black Friday
('2024-12-02', 'Q4', 1), -- Cyber Monday
('2024-04-15', 'Q2', 0),
('2024-07-04', 'Q3', 0);

INSERT INTO fact_shipments_partitioned VALUES
('SHP-901', '2024-11-28', 'FEDEX_PRIORITY', 145.00),
('SHP-902', '2024-11-29', 'UPS_EXPRESS',    210.00),
('SHP-903', '2024-04-15', 'DHL_STANDARD',    45.00);

-- --- [SOLUTION QUERY] ---
-- Query executing Dynamic Partition Elimination via correlated subquery filter
SELECT 
    s.shipment_id,
    s.partition_date,
    s.freight_carrier,
    s.shipping_cost_usd,
    'DYNAMIC_PARTITION_PRUNING_SUCCESS' AS scan_path
FROM fact_shipments_partitioned s
WHERE s.partition_date IN (
    SELECT cal_date 
    FROM dim_fiscal_calendar_dpp 
    WHERE fiscal_quarter = 'Q4' AND is_peak_holiday_surge = 1
)
ORDER BY s.shipment_id ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 2
-- ASSERT: COL[shipment_id] = SHP-901
-- ASSERT: COL[partition_date] = 2024-11-28\n