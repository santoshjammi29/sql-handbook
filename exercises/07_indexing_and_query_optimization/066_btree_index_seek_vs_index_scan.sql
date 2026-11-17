-- ============================================================================
-- EXERCISE: 066_btree_index_seek_vs_index_scan.sql
-- MODULE:   07_indexing_and_query_optimization
-- LEVEL:    🔴<br>Advanced
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ROLE:     Lead Performance Architect & Database Administrator
-- ----------------------------------------------------------------------------
-- ARCHITECTURAL CONTEXT & SYSTEM TOPOLOGY:
--   High-Throughput Order Ingestion Engine & Execution Plan Optimization.
--   Understanding B-Tree physical access paths:
--   1. Index Seek: Logarithmic O(log N) root-to-leaf traversal navigating directly to matching row pointers.
--   2. Index Scan: Sequential traversal of index leaf pages when selectivity is low or predicates are non-selective.
--   3. Table Scan: Full linear O(N) scan of the underlying heap pages.
--
-- BUSINESS CONTEXT:
--   Enterprise analytical engine optimization for 066 btree index seek vs index scan.
--   Ensuring strict grain integrity, distributed performance, and deterministic results.
--
-- PROBLEM STATEMENT:
--   Write a production-grade SQL query fulfilling the architectural requirements for 066 btree index seek vs index scan.
-- ============================================================================

DROP TABLE IF EXISTS high_concurrency_orders;

CREATE TABLE high_concurrency_orders (
    order_id VARCHAR(32) PRIMARY KEY,
    customer_id VARCHAR(32) NOT NULL,
    order_status VARCHAR(20) NOT NULL,
    order_total_usd DECIMAL(12, 2) NOT NULL
);

CREATE INDEX idx_orders_customer ON high_concurrency_orders(customer_id);

INSERT INTO high_concurrency_orders VALUES
('ORD-1', 'CUST-A', 'COMPLETED', 1250.00),
('ORD-2', 'CUST-A', 'COMPLETED',  450.00),
('ORD-3', 'CUST-B', 'PENDING',    890.00),
('ORD-4', 'CUST-C', 'CANCELLED',  120.00);

-- --- [SOLUTION QUERY] ---
-- Highly selective query leveraging B-Tree index seek on customer_id
SELECT 
    order_id,
    customer_id,
    order_status,
    order_total_usd,
    'BTREE_INDEX_SEEK_EXECUTED' AS access_path_type
FROM high_concurrency_orders
WHERE customer_id = 'CUST-A'
ORDER BY order_total_usd DESC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 2
-- ASSERT: COL[order_id] = ORD-1
