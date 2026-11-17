-- ============================================================================
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
