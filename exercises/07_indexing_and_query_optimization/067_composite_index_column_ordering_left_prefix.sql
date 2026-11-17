-- ============================================================================
-- EXERCISE: 067_composite_index_column_ordering_left_prefix.sql
-- MODULE:   07_indexing_and_query_optimization
-- LEVEL:    🔴<br>Advanced
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ROLE:     Lead Data Architect & Database Engine Specialist
-- ----------------------------------------------------------------------------
-- ARCHITECTURAL CONTEXT & SYSTEM TOPOLOGY:
--   Composite Index Design & The Left-Prefix Rule.
--   A composite index on (tenant_id, order_status, created_at) is structured like a phone book
--   sorted first by tenant_id, then by order_status, then by created_at.
--   Queries that filter on tenant_id alone, or (tenant_id, order_status), can seek the index.
--   Queries filtering ONLY on created_at CANNOT seek the index and must scan!
--
-- BUSINESS CONTEXT:
--   Enterprise analytical engine optimization for 067 composite index column ordering left prefix.
--   Ensuring strict grain integrity, distributed performance, and deterministic results.
--
-- PROBLEM STATEMENT:
--   Write a production-grade SQL query fulfilling the architectural requirements for 067 composite index column ordering left prefix.
-- ============================================================================

DROP TABLE IF EXISTS multi_tenant_orders;

CREATE TABLE multi_tenant_orders (
    order_id VARCHAR(32) PRIMARY KEY,
    tenant_id VARCHAR(20) NOT NULL,
    order_status VARCHAR(20) NOT NULL,
    created_at TEXT NOT NULL,
    amount_usd DECIMAL(12, 2) NOT NULL
);

CREATE INDEX idx_comp_tenant_status_date 
ON multi_tenant_orders(tenant_id, order_status, created_at);

INSERT INTO multi_tenant_orders VALUES
('O-01', 'TNT-1', 'SHIPPED', '2024-05-01 10:00:00', 500.00),
('O-02', 'TNT-1', 'SHIPPED', '2024-05-01 14:00:00', 750.00),
('O-03', 'TNT-1', 'PENDING', '2024-05-02 09:00:00', 300.00),
('O-04', 'TNT-2', 'SHIPPED', '2024-05-01 11:00:00', 1200.00);

-- --- [SOLUTION QUERY] ---
-- SARGable query satisfying the composite index left-prefix rule (tenant_id + order_status)
SELECT 
    order_id,
    tenant_id,
    order_status,
    created_at,
    amount_usd,
    'LEFT_PREFIX_COMPOSITE_SEEK' AS optimization_path
FROM multi_tenant_orders
WHERE tenant_id = 'TNT-1' AND order_status = 'SHIPPED'
ORDER BY created_at ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 2
-- ASSERT: COL[order_id] = O-01
