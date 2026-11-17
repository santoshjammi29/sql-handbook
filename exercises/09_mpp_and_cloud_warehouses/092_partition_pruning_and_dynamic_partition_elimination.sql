-- ============================================================================
-- EXERCISE: 092_partition_pruning_and_dynamic_partition_elimination.sql
-- MODULE:   09_mpp_and_cloud_warehouses
-- LEVEL:    Advanced
-- ENGINES:  Snowflake, BigQuery, Databricks Spark SQL, PostgreSQL, DuckDB, SQLite
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   Dynamic Partition Elimination: When joining a partitioned fact table to a
--   date dimension filtered on 'current fiscal quarter', the engine dynamically
--   prunes unreferenced fact partitions during query execution.
-- PROBLEM STATEMENT:
--   Filter fact table via dimension subquery matching specific calendar quarters.
-- ============================================================================

DROP TABLE IF EXISTS fact_shipments;
DROP TABLE IF EXISTS dim_calendar;

CREATE TABLE dim_calendar (cal_date TEXT PRIMARY KEY, fiscal_quarter VARCHAR(10));
CREATE TABLE fact_shipments (shipment_id INT PRIMARY KEY, ship_date TEXT, cost DECIMAL(10, 2));

INSERT INTO dim_calendar VALUES ('2024-01-10', 'Q1'), ('2024-01-20', 'Q1'), ('2024-04-15', 'Q2');
INSERT INTO fact_shipments VALUES (1, '2024-01-10', 50.00), (2, '2024-04-15', 75.00);

-- --- [SOLUTION QUERY] ---
SELECT 
    s.shipment_id,
    s.ship_date,
    s.cost
FROM fact_shipments s
WHERE s.ship_date IN (
    SELECT cal_date FROM dim_calendar WHERE fiscal_quarter = 'Q1'
)
ORDER BY s.shipment_id ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 1
-- ASSERT: COL[shipment_id] = 1
