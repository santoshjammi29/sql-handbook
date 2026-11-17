#!/usr/bin/env python3
"""
Generator for Module 09 (086-095) & Module 10 (096-105)
"""
import os
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent
EXERCISES_DIR = BASE_DIR / "exercises"

def save(mod: str, name: str, content: str):
    p = EXERCISES_DIR / mod / name
    p.parent.mkdir(parents=True, exist_ok=True)
    with open(p, "w", encoding="utf-8") as f:
        f.write(content.strip() + "\n")
    print(f"Generated: {mod}/{name}")

# ==============================================================================
# MODULE 09: MPP Data Warehouses & Distributed SQL (086 - 095)
# ==============================================================================

save("09_mpp_and_cloud_warehouses", "086_snowflake_micropartition_pruning.sql", """-- ============================================================================
-- EXERCISE: 086_snowflake_micropartition_pruning.sql
-- MODULE:   09_mpp_and_cloud_warehouses
-- LEVEL:    Advanced
-- ENGINES:  Snowflake, Databricks Spark SQL, BigQuery, PostgreSQL, DuckDB, SQLite
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   Cloud data warehouses (Snowflake, BigQuery) divide multi-terabyte tables
--   into immutable micro-partitions / row-groups. Metadata tracks min/max values
--   per column per micro-partition.
-- PROBLEM STATEMENT:
--   Simulate micro-partition metadata pruning: filter candidate partitions
--   using min/max bounds before scanning actual records.
-- ============================================================================

DROP TABLE IF EXISTS micropartition_metadata;
CREATE TABLE micropartition_metadata (
    partition_id INT PRIMARY KEY,
    min_event_date TEXT,
    max_event_date TEXT,
    row_count INT
);

INSERT INTO micropartition_metadata VALUES
(1, '2024-01-01', '2024-01-15', 500000),
(2, '2024-01-16', '2024-01-31', 650000),
(3, '2024-02-01', '2024-02-15', 450000);

-- --- [SOLUTION QUERY] ---
-- Query targeting '2024-01-20': Prunes partition 1 and 3 via metadata alone!
SELECT 
    partition_id,
    min_event_date,
    max_event_date,
    row_count AS rows_to_scan
FROM micropartition_metadata
WHERE '2024-01-20' BETWEEN min_event_date AND max_event_date;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 1
-- ASSERT: COL[partition_id] = 2
""")

save("09_mpp_and_cloud_warehouses", "087_mpp_table_distribution_hash_replicated_roundrobin.sql", """-- ============================================================================
-- EXERCISE: 087_mpp_table_distribution_hash_replicated_roundrobin.sql
-- MODULE:   09_mpp_and_cloud_warehouses
-- LEVEL:    Advanced
-- ENGINES:  Azure Synapse, Snowflake, Databricks, PostgreSQL, DuckDB, SQLite
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   MPP distribution strategies (Azure Synapse / Redshift):
--   1. Hash Distribution: fact tables distributed by hash(key) across 60 compute slices
--   2. Replicated: dimension tables copied to every compute node (zero shuffle joins)
--   3. Round-Robin: uniform staging tables without key evaluation
-- PROBLEM STATEMENT:
--   Simulate hash distribution bucketing across 4 worker nodes.
-- ============================================================================

DROP TABLE IF EXISTS distributed_fact;
CREATE TABLE distributed_fact (
    transaction_id INT PRIMARY KEY,
    customer_id INT,
    amount DECIMAL(10, 2)
);

INSERT INTO distributed_fact VALUES
(1, 101, 150.00), (2, 102, 200.00), (3, 103, 350.00), (4, 104, 500.00);

-- --- [SOLUTION QUERY] ---
-- Simulate hash distribution to 4 compute workers: (customer_id % 4)
SELECT 
    transaction_id,
    customer_id,
    amount,
    (customer_id % 4) AS worker_node_id
FROM distributed_fact
ORDER BY worker_node_id ASC, transaction_id ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 4
-- ASSERT: COL[worker_node_id] = 0
""")

save("09_mpp_and_cloud_warehouses", "088_liquid_clustering_vs_hive_partitioning.sql", """-- ============================================================================
-- EXERCISE: 088_liquid_clustering_vs_hive_partitioning.sql
-- MODULE:   09_mpp_and_cloud_warehouses
-- LEVEL:    Advanced
-- ENGINES:  Databricks Spark SQL, Snowflake, BigQuery, PostgreSQL, DuckDB, SQLite
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   Legacy Hive physical directory partitioning (/year=2024/month=05/) creates
--   the small file problem. Modern Lakehouses use Liquid Clustering (CLUSTER BY)
--   to cluster data across multiple dimensions (region, customer_id) in flat files.
-- PROBLEM STATEMENT:
--   Demonstrate multidimensional clustering and query filtering.
-- ============================================================================

DROP TABLE IF EXISTS clustered_events;
CREATE TABLE clustered_events (
    event_id INT PRIMARY KEY,
    region VARCHAR(10),
    event_date TEXT,
    user_id INT
);

INSERT INTO clustered_events VALUES
(1, 'US', '2024-05-01', 101),
(2, 'US', '2024-05-01', 102),
(3, 'EU', '2024-05-01', 201),
(4, 'US', '2024-05-02', 101);

-- --- [SOLUTION QUERY] ---
SELECT region, event_date, COUNT(*) AS event_count
FROM clustered_events
WHERE region = 'US' AND event_date = '2024-05-01'
GROUP BY region, event_date;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 1
-- ASSERT: COL[event_count] = 2
""")

save("09_mpp_and_cloud_warehouses", "089_detecting_distribution_skew_in_parallel_shards.sql", """-- ============================================================================
-- EXERCISE: 089_detecting_distribution_skew_in_parallel_shards.sql
-- MODULE:   09_mpp_and_cloud_warehouses
-- LEVEL:    Advanced
-- ENGINES:  Azure Synapse, Snowflake, Databricks, PostgreSQL, DuckDB, SQLite
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   In MPP clusters, if rows are not uniformly distributed, one worker processes
--   vastly more data than peers (Skew / Straggler node).
-- PROBLEM STATEMENT:
--   Write an administrative audit query to calculate row variance across worker shards.
-- ============================================================================

DROP TABLE IF EXISTS shard_stats;
CREATE TABLE shard_stats (
    shard_id INT PRIMARY KEY,
    row_count INT
);

INSERT INTO shard_stats VALUES
(1, 1000000),
(2, 980000),
(3, 1020000),
(4, 5500000); -- Severe Skew on Shard 4!

-- --- [SOLUTION QUERY] ---
SELECT 
    shard_id,
    row_count,
    ROUND(100.0 * row_count / (SELECT SUM(row_count) FROM shard_stats), 2) AS pct_of_total_rows,
    CASE 
        WHEN row_count > 2.0 * (SELECT AVG(row_count) FROM shard_stats) THEN 'CRITICAL_SKEW_STRAGGLER'
        ELSE 'BALANCED'
    END AS skew_status
FROM shard_stats
ORDER BY row_count DESC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 4
-- ASSERT: COL[skew_status] = CRITICAL_SKEW_STRAGGLER
""")

save("09_mpp_and_cloud_warehouses", "090_distributed_key_salting_for_skewed_joins.sql", """-- ============================================================================
-- EXERCISE: 090_distributed_key_salting_for_skewed_joins.sql
-- MODULE:   09_mpp_and_cloud_warehouses
-- LEVEL:    Advanced
-- ENGINES:  Databricks Spark SQL, Snowflake, BigQuery, PostgreSQL, DuckDB, SQLite
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   Distributed join skew: Joining fact orders on customer_id when customer 0
--   (Guest Checkout) represents 90% of all orders causes 1 executor to run for hours.
--   Solution: Key Salting (append random suffix 0-2 to customer 0, replicate dimension 3x).
-- PROBLEM STATEMENT:
--   Implement two-phase key salting in SQL.
-- ============================================================================

DROP TABLE IF EXISTS skewed_orders;
DROP TABLE IF EXISTS dim_customers_skew;

CREATE TABLE skewed_orders (order_id INT, customer_id INT, amount DECIMAL(10, 2));
CREATE TABLE dim_customers_skew (customer_id INT, customer_name VARCHAR(50));

INSERT INTO skewed_orders VALUES
(1, 0, 50.00), (2, 0, 75.00), (3, 0, 90.00), -- Skewed hotspot
(4, 10, 500.00);

INSERT INTO dim_customers_skew VALUES (0, 'Guest User'), (10, 'Corporate Account');

-- --- [SOLUTION QUERY] ---
WITH salted_fact AS (
    SELECT 
        order_id,
        customer_id,
        CASE 
            WHEN customer_id = 0 THEN customer_id || '_' || (order_id % 3)
            ELSE customer_id || '_0'
        END AS salted_key,
        amount
    FROM skewed_orders
),
replicated_dim AS (
    SELECT 
        c.customer_id,
        c.customer_name,
        CASE 
            WHEN c.customer_id = 0 THEN c.customer_id || '_' || s.salt
            ELSE c.customer_id || '_0'
        END AS salted_key
    FROM dim_customers_skew c
    CROSS JOIN (SELECT 0 AS salt UNION ALL SELECT 1 UNION ALL SELECT 2) s
)
SELECT 
    f.order_id,
    d.customer_name,
    f.amount
FROM salted_fact f
JOIN replicated_dim d ON f.salted_key = d.salted_key
ORDER BY f.order_id ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 4
-- ASSERT: COL[customer_name] = Guest User
""")

save("09_mpp_and_cloud_warehouses", "091_broadcast_vs_shuffle_join_thresholds.sql", """-- ============================================================================
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
""")

save("09_mpp_and_cloud_warehouses", "092_partition_pruning_and_dynamic_partition_elimination.sql", """-- ============================================================================
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
""")

save("09_mpp_and_cloud_warehouses", "093_delta_merge_into_multi_condition_matching.sql", """-- ============================================================================
-- EXERCISE: 093_delta_merge_into_multi_condition_matching.sql
-- MODULE:   09_mpp_and_cloud_warehouses
-- LEVEL:    Advanced
-- ENGINES:  Databricks Spark SQL, Snowflake, BigQuery, PostgreSQL, DuckDB, SQLite
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   Modern Lakehouse Upsert: Incoming CDC stream contains new inserts, updates,
--   and soft deletes. Standard ANSI MERGE INTO applies multiple WHEN MATCHED
--   clauses to delete or update rows and WHEN NOT MATCHED to insert rows.
-- PROBLEM STATEMENT:
--   Emulate atomic multi-condition MERGE upsert logic.
-- ============================================================================

DROP TABLE IF EXISTS cdc_target;
DROP TABLE IF EXISTS cdc_incoming;

CREATE TABLE cdc_target (id INT PRIMARY KEY, val VARCHAR(50), is_deleted INT);
CREATE TABLE cdc_incoming (id INT PRIMARY KEY, val VARCHAR(50), is_deleted INT);

INSERT INTO cdc_target VALUES (1, 'Old Val 1', 0), (2, 'Old Val 2', 0);
INSERT INTO cdc_incoming VALUES (1, 'Updated Val 1', 0), (2, 'Delete Val 2', 1), (3, 'New Val 3', 0);

-- Emulate MERGE: Delete where is_deleted = 1
DELETE FROM cdc_target WHERE id IN (SELECT id FROM cdc_incoming WHERE is_deleted = 1);
-- Update matching
INSERT INTO cdc_target (id, val, is_deleted)
SELECT id, val, is_deleted FROM cdc_incoming WHERE is_deleted = 0
ON CONFLICT(id) DO UPDATE SET val = EXCLUDED.val, is_deleted = EXCLUDED.is_deleted;

-- --- [SOLUTION QUERY] ---
SELECT id, val, is_deleted FROM cdc_target ORDER BY id ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 2
-- ASSERT: COL[val] = Updated Val 1
""")

save("09_mpp_and_cloud_warehouses", "094_query_memory_spill_mitigation.sql", """-- ============================================================================
-- EXERCISE: 094_query_memory_spill_mitigation.sql
-- MODULE:   09_mpp_and_cloud_warehouses
-- LEVEL:    Intermediate
-- ENGINES:  Databricks Spark SQL, Snowflake, BigQuery, PostgreSQL, DuckDB, SQLite
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   Tungsten memory spill: In-memory hash aggregations spill to local disk when
--   aggregating massive high-cardinality keys. Reducing grain before joining
--   eliminates memory spills.
-- PROBLEM STATEMENT:
--   Aggregate at lower grain before performing downstream dimension joins.
-- ============================================================================

DROP TABLE IF EXISTS raw_meter_reads;
CREATE TABLE raw_meter_reads (
    meter_id INT,
    kwh DECIMAL(10, 2)
);

INSERT INTO raw_meter_reads VALUES (1, 10.5), (1, 12.0), (2, 8.0), (2, 9.5);

-- --- [SOLUTION QUERY] ---
WITH aggregated_reads AS (
    -- Pre-aggregate to collapse millions of raw sensor rows into unique meter totals
    SELECT 
        meter_id,
        SUM(kwh) AS total_kwh
    FROM raw_meter_reads
    GROUP BY meter_id
)
SELECT meter_id, total_kwh
FROM aggregated_reads
ORDER BY meter_id ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 2
-- ASSERT: COL[total_kwh] = 22.5
""")

save("09_mpp_and_cloud_warehouses", "095_serverless_sql_querying_external_files.sql", """-- ============================================================================
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
""")

# ==============================================================================
# MODULE 10: Production Incidents, Disaster Scenarios & Triage (096 - 105)
# ==============================================================================

save("10_production_incidents_and_triage", "096_incident_the_99_percent_straggler_task_disaster.sql", """-- ============================================================================
-- EXERCISE: 096_incident_the_99_percent_straggler_task_disaster.sql
-- MODULE:   10_production_incidents_and_triage
-- LEVEL:    Advanced
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   PRODUCTION INCIDENT POSTMORTEM: The 99% Complete Straggler Task Disaster.
--   A nightly Spark/MPP pipeline joining 50M transactions stalled for 4 hours
--   at task 199/200. Root cause: 15 million transactions had customer_id IS NULL.
--   All NULLs hashed to the identical worker node!
-- SURGICAL REMEDIATION:
--   Filter out NULL customer keys before hash join, or isolate NULL processing.
-- ============================================================================

DROP TABLE IF EXISTS incident_txns;
DROP TABLE IF EXISTS incident_customers;

CREATE TABLE incident_txns (txn_id INT PRIMARY KEY, cust_id INT, amount DECIMAL(10, 2));
CREATE TABLE incident_customers (cust_id INT PRIMARY KEY, cust_name VARCHAR(50));

INSERT INTO incident_txns VALUES
(1, 10, 100.00), (2, 20, 200.00),
(3, NULL, 50.00), (4, NULL, 75.00), (5, NULL, 90.00); -- Skewed NULLs!

INSERT INTO incident_customers VALUES (10, 'Enterprise Customer A'), (20, 'Enterprise Customer B');

-- --- [SOLUTION QUERY] ---
-- Production fix: Process known valid keys with hash join, union unassigned NULLs directly
SELECT 
    t.txn_id,
    c.cust_name,
    t.amount
FROM incident_txns t
JOIN incident_customers c ON t.cust_id = c.cust_id
WHERE t.cust_id IS NOT NULL

UNION ALL

SELECT 
    t.txn_id,
    'UNASSIGNED_GUEST' AS cust_name,
    t.amount
FROM incident_txns t
WHERE t.cust_id IS NULL
ORDER BY txn_id ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 5
-- ASSERT: COL[cust_name] = Enterprise Customer A
""")

save("10_production_incidents_and_triage", "097_incident_payment_gateway_deadlock_storm.sql", """-- ============================================================================
-- EXERCISE: 097_incident_payment_gateway_deadlock_storm.sql
-- MODULE:   10_production_incidents_and_triage
-- LEVEL:    Advanced
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   PRODUCTION INCIDENT POSTMORTEM: Deadlock Storm in Payment Processing.
--   During Black Friday, concurrent refund webhooks deadlocked across ledger accounts.
--   Transaction 1 updated Account 10 then 20; Transaction 2 updated Account 20 then 10.
-- SURGICAL REMEDIATION:
--   Enforce strict ascending primary key locking order across all endpoints.
-- ============================================================================

DROP TABLE IF EXISTS incident_accounts;
CREATE TABLE incident_accounts (account_id INT PRIMARY KEY, balance DECIMAL(10, 2));

INSERT INTO incident_accounts VALUES (10, 1000.00), (20, 2000.00);

-- Deadlock-proof ordered transfer: Transfer $300 from Account 20 to Account 10
-- Mandatory rule: Lock min(10, 20) first, max(10, 20) second!
BEGIN TRANSACTION;
UPDATE incident_accounts SET balance = balance + 300.00 WHERE account_id = 10;
UPDATE incident_accounts SET balance = balance - 300.00 WHERE account_id = 20;
COMMIT;

-- --- [SOLUTION QUERY] ---
SELECT account_id, balance FROM incident_accounts ORDER BY account_id ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 2
-- ASSERT: COL[balance] = 1300.00
""")

save("10_production_incidents_and_triage", "098_incident_out_of_order_cdc_timeline_corruption.sql", """-- ============================================================================
-- EXERCISE: 098_incident_out_of_order_cdc_timeline_corruption.sql
-- MODULE:   10_production_incidents_and_triage
-- LEVEL:    Advanced
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   PRODUCTION INCIDENT POSTMORTEM: Out-of-Order CDC Timeline Corruption.
--   Network delay caused a 10:00 AM customer address change to arrive AFTER
--   a 10:05 AM change in the Kafka topic. Both records were marked is_current = 1,
--   causing duplicate rows and invalid tax calculations in downstream orders!
-- SURGICAL REMEDIATION:
--   Execute a self-healing reconstruction query using LEAD() and ROW_NUMBER().
-- ============================================================================

DROP TABLE IF EXISTS raw_corrupted_cdc;
CREATE TABLE raw_corrupted_cdc (
    customer_id INT,
    address VARCHAR(100),
    event_time TEXT
);

INSERT INTO raw_corrupted_cdc VALUES
(101, '100 Broadway, NY', '2024-05-01 10:00:00'),
(101, '500 Market St, CA', '2024-05-01 10:05:00');

-- --- [SOLUTION QUERY] ---
-- Deterministic self-healing timeline rebuilder
WITH sequenced AS (
    SELECT 
        customer_id,
        address,
        event_time AS valid_from,
        COALESCE(
            LEAD(event_time) OVER (PARTITION BY customer_id ORDER BY event_time ASC),
            '9999-12-31 23:59:59'
        ) AS valid_to,
        CASE 
            WHEN LEAD(event_time) OVER (PARTITION BY customer_id ORDER BY event_time ASC) IS NULL THEN 1
            ELSE 0
        END AS is_current
    FROM raw_corrupted_cdc
)
SELECT customer_id, address, valid_from, valid_to, is_current
FROM sequenced
ORDER BY valid_from ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 2
-- ASSERT: COL[is_current] = 0
""")

save("10_production_incidents_and_triage", "099_incident_accidental_cartesian_tempdb_exhaustion.sql", """-- ============================================================================
-- EXERCISE: 099_incident_accidental_cartesian_tempdb_exhaustion.sql
-- MODULE:   10_production_incidents_and_triage
-- LEVEL:    Advanced
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   PRODUCTION INCIDENT POSTMORTEM: Accidental Cartesian TempDB Exhaustion.
--   A developer joined orders to order_discounts on promo_code without realizing
--   promo_code was non-unique, causing a 10M x 10M row explosion that exhausted
--   warehouse temp storage.
-- SURGICAL REMEDIATION:
--   Deduplicate dimension to unique promo_code grain before joining!
-- ============================================================================

DROP TABLE IF EXISTS incident_orders;
DROP TABLE IF EXISTS non_unique_discounts;

CREATE TABLE incident_orders (order_id INT PRIMARY KEY, promo_code VARCHAR(20), amount DECIMAL(10, 2));
CREATE TABLE non_unique_discounts (promo_code VARCHAR(20), discount_pct DECIMAL(4, 2), created_at TEXT);

INSERT INTO incident_orders VALUES (1, 'SUMMER', 100.00), (2, 'SUMMER', 200.00);
-- Non-unique promo codes in discount table!
INSERT INTO non_unique_discounts VALUES ('SUMMER', 10.0, '2024-05-01'), ('SUMMER', 15.0, '2024-05-02');

-- --- [SOLUTION QUERY] ---
-- Pre-deduplicate discount table to ensure 1:1 join relationship
WITH unique_discounts AS (
    SELECT 
        promo_code,
        discount_pct,
        ROW_NUMBER() OVER (PARTITION BY promo_code ORDER BY created_at DESC) AS rn
    FROM non_unique_discounts
)
SELECT 
    o.order_id,
    o.promo_code,
    o.amount,
    d.discount_pct,
    ROUND(o.amount * (1.0 - d.discount_pct / 100.0), 2) AS net_amount
FROM incident_orders o
JOIN unique_discounts d ON o.promo_code = d.promo_code AND d.rn = 1
ORDER BY o.order_id ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 2
-- ASSERT: COL[net_amount] = 85.00
""")

save("10_production_incidents_and_triage", "100_incident_silent_schema_drift_bi_refresh_failure.sql", """-- ============================================================================
-- EXERCISE: 100_incident_silent_schema_drift_bi_refresh_failure.sql
-- MODULE:   10_production_incidents_and_triage
-- LEVEL:    Intermediate
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   PRODUCTION INCIDENT POSTMORTEM: Silent Schema Drift Breaking BI Dashboards.
--   Upstream application engineers renamed column 'client_email' to 'email_addr'
--   without notice, crashing Monday morning Power BI executive refresh.
-- SURGICAL REMEDIATION:
--   Implement a Data Contract audit query that checks schema column integrity.
-- ============================================================================

DROP TABLE IF EXISTS schema_columns_catalog;
CREATE TABLE schema_columns_catalog (
    table_name VARCHAR(50),
    column_name VARCHAR(50),
    is_required INT
);

INSERT INTO schema_columns_catalog VALUES
('dim_client', 'client_id', 1),
('dim_client', 'client_email', 1),
('dim_client', 'created_at', 0);

-- Actual landing schema
DROP TABLE IF EXISTS landing_table_columns;
CREATE TABLE landing_table_columns (
    column_name VARCHAR(50)
);

INSERT INTO landing_table_columns VALUES ('client_id'), ('email_addr'); -- Drift!

-- --- [SOLUTION QUERY] ---
-- Schema Drift Alert Query
SELECT 
    c.table_name,
    c.column_name AS missing_contract_column
FROM schema_columns_catalog c
LEFT JOIN landing_table_columns l ON c.column_name = l.column_name
WHERE c.is_required = 1 
  AND l.column_name IS NULL;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 1
-- ASSERT: COL[missing_contract_column] = client_email
""")

save("10_production_incidents_and_triage", "101_incident_parameter_sniffing_query_timeout.sql", """-- ============================================================================
-- EXERCISE: 101_incident_parameter_sniffing_query_timeout.sql
-- MODULE:   10_production_incidents_and_triage
-- LEVEL:    Advanced
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   PRODUCTION INCIDENT POSTMORTEM: Parameter Sniffing Sudden Query Timeouts.
--   A stored procedure ran in 20ms for normal tenants, but suddenly began
--   timing out across all callers. Root cause: An outlier tenant with 5M rows
--   compiled a Table Scan plan that was cached and forced onto all tenants.
-- SURGICAL REMEDIATION:
--   Use parameterized query masking or separate fast-path queries for dominant tenants.
-- ============================================================================

DROP TABLE IF EXISTS tenant_traffic;
CREATE TABLE tenant_traffic (
    tenant_id INT,
    event_id INT PRIMARY KEY,
    payload VARCHAR(50)
);

INSERT INTO tenant_traffic VALUES
(100, 1, 'Event 1'), (100, 2, 'Event 2'),
(999, 3, 'Massive Tenant Event 3');

-- --- [SOLUTION QUERY] ---
SELECT tenant_id, COUNT(*) AS tenant_event_count
FROM tenant_traffic
WHERE tenant_id = 100
GROUP BY tenant_id;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 1
-- ASSERT: COL[tenant_event_count] = 2
""")

save("10_production_incidents_and_triage", "102_incident_phantom_read_financial_ledger_double_spend.sql", """-- ============================================================================
-- EXERCISE: 102_incident_phantom_read_financial_ledger_double_spend.sql
-- MODULE:   10_production_incidents_and_triage
-- LEVEL:    Advanced
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   PRODUCTION INCIDENT POSTMORTEM: Financial Ledger Double-Spend Breach.
--   An attacker initiated two concurrent withdrawals of $500 on an account with $600.
--   Both threads read balance = $600 simultaneously under Read Committed,
--   withdrawing $1,000 total and causing a -$400 balance breach.
-- SURGICAL REMEDIATION:
--   Enforce strict check constraint AND atomic withdrawal with balance condition.
-- ============================================================================

DROP TABLE IF EXISTS fraud_accounts;
CREATE TABLE fraud_accounts (
    acc_id INT PRIMARY KEY,
    balance DECIMAL(10, 2) CHECK (balance >= 0.00) -- Database constraint guard!
);

INSERT INTO fraud_accounts VALUES (1, 600.00);

-- Atomic withdrawal: only update if balance >= withdrawal amount!
UPDATE fraud_accounts
SET balance = balance - 500.00
WHERE acc_id = 1 AND balance >= 500.00;

-- --- [SOLUTION QUERY] ---
SELECT acc_id, balance FROM fraud_accounts WHERE acc_id = 1;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 1
-- ASSERT: COL[balance] = 100.00
""")

save("10_production_incidents_and_triage", "103_incident_unindexed_foreign_key_table_lock_cascade.sql", """-- ============================================================================
-- EXERCISE: 103_incident_unindexed_foreign_key_table_lock_cascade.sql
-- MODULE:   10_production_incidents_and_triage
-- LEVEL:    Advanced
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   PRODUCTION INCIDENT POSTMORTEM: Unindexed Foreign Key Table-Lock Cascade.
--   Deleting an inactive customer locked the entire 20M row order_history table
--   for 45 seconds, rejecting all user checkouts.
--   Root cause: Missing index on order_history.customer_id forced a share lock table scan.
-- SURGICAL REMEDIATION:
--   Always index all Foreign Key columns in child tables.
-- ============================================================================

DROP TABLE IF EXISTS child_order_history;
DROP TABLE IF EXISTS parent_customer_registry;

CREATE TABLE parent_customer_registry (
    customer_id INT PRIMARY KEY,
    name VARCHAR(50)
);

CREATE TABLE child_order_history (
    history_id INT PRIMARY KEY,
    customer_id INT,
    amount DECIMAL(10, 2),
    FOREIGN KEY (customer_id) REFERENCES parent_customer_registry(customer_id)
);

CREATE INDEX idx_fk_customer_id ON child_order_history (customer_id);

INSERT INTO parent_customer_registry VALUES (1, 'Alice');
INSERT INTO child_order_history VALUES (101, 1, 50.00);

-- --- [SOLUTION QUERY] ---
SELECT 
    p.customer_id,
    p.name,
    COUNT(c.history_id) AS total_orders
FROM parent_customer_registry p
LEFT JOIN child_order_history c ON p.customer_id = c.customer_id
WHERE p.customer_id = 1
GROUP BY p.customer_id, p.name;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 1
-- ASSERT: COL[total_orders] = 1
""")

save("10_production_incidents_and_triage", "104_incident_delta_lake_concurrent_append_conflict.sql", """-- ============================================================================
-- EXERCISE: 104_incident_delta_lake_concurrent_append_conflict.sql
-- MODULE:   10_production_incidents_and_triage
-- LEVEL:    Advanced
-- ENGINES:  Databricks Spark SQL, Delta Lake, PostgreSQL, DuckDB, SQLite
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   PRODUCTION INCIDENT POSTMORTEM: Concurrent Append Write Conflict.
--   Two hourly ETL pipelines wrote to the same Delta Lake table simultaneously.
--   Pipeline A modified partition date='2024-05-01' while Pipeline B modified
--   partition date='2024-05-02'. Because table lacked partition predicates in
--   the merge condition, Delta OCC threw ConcurrentAppendException!
-- SURGICAL REMEDIATION:
--   Always scope MERGE/UPDATE conditions strictly to specific partition boundaries.
-- ============================================================================

DROP TABLE IF EXISTS partitioned_lakehouse_log;
CREATE TABLE partitioned_lakehouse_log (
    log_id INT PRIMARY KEY,
    log_date TEXT,
    msg VARCHAR(50)
);

INSERT INTO partitioned_lakehouse_log VALUES
(1, '2024-05-01', 'Pipeline A data'),
(2, '2024-05-02', 'Pipeline B data');

-- --- [SOLUTION QUERY] ---
SELECT log_id, log_date, msg
FROM partitioned_lakehouse_log
WHERE log_date = '2024-05-01';

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 1
-- ASSERT: COL[msg] = Pipeline A data
""")

save("10_production_incidents_and_triage", "105_master_enterprise_data_quality_reconciliation_suite.sql", """-- ============================================================================
-- EXERCISE: 105_master_enterprise_data_quality_reconciliation_suite.sql
-- MODULE:   10_production_incidents_and_triage
-- LEVEL:    Principal / Architect
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   MASTER ENTERPRISE DATA QUALITY AUDIT SUITE:
--   Automated daily gatekeeper validating:
--   1. Primary key uniqueness (duplicate check)
--   2. Referential integrity (orphaned child records)
--   3. Required nullity checks (missing critical fields)
--   4. Numeric range sanity (negative revenue / prices)
--   5. Date sanity (future event timestamps)
-- PROBLEM STATEMENT:
--   Execute a unified 5-pillar Data Quality Reconciliation Suite returning a
--   clean scorecard of passed/failed tests.
-- ============================================================================

DROP TABLE IF EXISTS dq_sales_fact;
DROP TABLE IF EXISTS dq_customer_dim;

CREATE TABLE dq_customer_dim (cust_id INT PRIMARY KEY, cust_name VARCHAR(50));
CREATE TABLE dq_sales_fact (
    sale_id INT PRIMARY KEY,
    cust_id INT,
    amount DECIMAL(10, 2),
    sale_date TEXT
);

INSERT INTO dq_customer_dim VALUES (1, 'Acme Corp'), (2, 'Globex Inc');
INSERT INTO dq_sales_fact VALUES
(101, 1, 500.00, '2024-05-01'),
(102, 2, 750.00, '2024-05-02');

-- --- [SOLUTION QUERY] ---
-- Master 5-Pillar Data Quality Reconciliation Scorecard
WITH check_duplicates AS (
    SELECT '1. PK Uniqueness' AS test_name, 
           CASE WHEN COUNT(sale_id) = COUNT(DISTINCT sale_id) THEN 'PASS' ELSE 'FAIL' END AS test_status
    FROM dq_sales_fact
),
check_orphans AS (
    SELECT '2. Referential Integrity' AS test_name,
           CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS test_status
    FROM dq_sales_fact s
    LEFT JOIN dq_customer_dim c ON s.cust_id = c.cust_id
    WHERE c.cust_id IS NULL
),
check_nulls AS (
    SELECT '3. Nullity Mandatory Checks' AS test_name,
           CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS test_status
    FROM dq_sales_fact
    WHERE cust_id IS NULL OR amount IS NULL OR sale_date IS NULL
),
check_numeric_ranges AS (
    SELECT '4. Numeric Range Sanity' AS test_name,
           CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS test_status
    FROM dq_sales_fact
    WHERE amount <= 0.00
),
check_date_sanity AS (
    SELECT '5. Date Bounds Sanity' AS test_name,
           CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS test_status
    FROM dq_sales_fact
    WHERE sale_date > '2099-12-31'
)
SELECT test_name, test_status FROM check_duplicates
UNION ALL
SELECT test_name, test_status FROM check_orphans
UNION ALL
SELECT test_name, test_status FROM check_nulls
UNION ALL
SELECT test_name, test_status FROM check_numeric_ranges
UNION ALL
SELECT test_name, test_status FROM check_date_sanity
ORDER BY test_name ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 5
-- ASSERT: COL[test_status] = PASS
""")

print("Module 09 and Module 10 generation complete!")
