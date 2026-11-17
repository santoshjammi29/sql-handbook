-- ============================================================================
-- EXERCISE: 087_mpp_table_distribution_hash_replicated_roundrobin.sql
-- MODULE:   09_mpp_and_cloud_warehouses
-- LEVEL:    🟣<br>Architect
-- ENGINES:  Azure Synapse, Snowflake, Databricks, PostgreSQL, DuckDB, SQLite
-- ROLE:     Lead MPP Data Warehouse Architect & Distributed Query Planner
-- ----------------------------------------------------------------------------
-- ARCHITECTURAL CONTEXT & SYSTEM TOPOLOGY:
--   Massively Parallel Processing (MPP) Architecture & Storage Topologies.
--   In 60-node MPP engines (Azure Synapse Dedicated SQL, AWS Redshift, Greenplum):
--   Table storage distribution strategy dictates network shuffle cost:
--   1. HASH(col): Distributed across 60 compute slices by hashing a high-cardinality key.
--      Co-located joins between two tables hashed on the same key require ZERO network movement!
--   2. REPLICATED (DISTSTYLE ALL): Duplicated in its entirety to every compute node.
--      Ideal for small conformed dimensions (< 2GB) to eliminate broadcast shuffles.
--   3. ROUND_ROBIN (DISTSTYLE EVEN): Uniformly striped across nodes in circular sequence.
--      Ideal for raw ELT staging tables to achieve maximum parallel write throughput without hotspotting.
--
-- BUSINESS CONTEXT:
--   Misconfigured distributions force massive data redistribution (Shuffle Move / DS_BCAST_INNER),
--   causing query execution plans to bottleneck on top-of-rack 100GbE switches.
--
-- PROBLEM STATEMENT:
--   Simulate a 4-node MPP cluster joining a Hash-Distributed orders fact table with a
--   Replicated customer dimension. Calculate the local join output per worker node
--   and prove zero cross-node data movement.
-- ============================================================================

DROP TABLE IF EXISTS dim_customers_replicated;
DROP TABLE IF EXISTS fact_orders_hash_mpp;

CREATE TABLE fact_orders_hash_mpp (
    order_id INT PRIMARY KEY,
    customer_id INT NOT NULL,
    order_amount_usd DECIMAL(12, 2) NOT NULL,
    assigned_worker_node INT NOT NULL -- Hash modulo 4: (customer_id % 4)
);

CREATE TABLE dim_customers_replicated (
    customer_id INT PRIMARY KEY,
    customer_tier VARCHAR(20) NOT NULL,
    discount_rate DECIMAL(4, 2) NOT NULL
);

-- Fact table hashed across 4 worker nodes by customer_id:
INSERT INTO fact_orders_hash_mpp VALUES
(1001, 104, 1500.00, 0), -- 104 % 4 = 0 -> Node 0
(1002, 101,  800.00, 1), -- 101 % 4 = 1 -> Node 1
(1003, 102, 2400.00, 2), -- 102 % 4 = 2 -> Node 2
(1004, 103,  450.00, 3); -- 103 % 4 = 3 -> Node 3

-- Dimension is replicated across ALL nodes, enabling local-only join on every worker
INSERT INTO dim_customers_replicated VALUES
(101, 'GOLD',     0.10),
(102, 'PLATINUM', 0.20),
(103, 'STANDARD', 0.00),
(104, 'PLATINUM', 0.20);

-- --- [SOLUTION QUERY] ---
-- Query executing local co-located join across all 4 worker nodes with zero network shuffle
SELECT 
    f.assigned_worker_node,
    COUNT(f.order_id) AS orders_processed_locally,
    SUM(f.order_amount_usd) AS gross_gmv_usd,
    SUM(f.order_amount_usd * (1.0 - d.discount_rate)) AS net_settled_gmv_usd,
    'LOCAL_CO_LOCATED_JOIN_ZERO_SHUFFLE' AS mpp_plan_step
FROM fact_orders_hash_mpp f
INNER JOIN dim_customers_replicated d ON f.customer_id = d.customer_id
GROUP BY f.assigned_worker_node
ORDER BY f.assigned_worker_node ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 4
-- ASSERT: COL[assigned_worker_node] = 0
-- ASSERT: COL[orders_processed_locally] = 1
-- ASSERT: COL[net_settled_gmv_usd] = 1200.0\n