-- ============================================================================
-- EXERCISE: 072_join_algorithms_nested_loop_hash_merge.sql
-- MODULE:   07_indexing_and_query_optimization
-- LEVEL:    🔴<br>Advanced
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ROLE:     Lead Query Optimizer Specialist & Distributed Systems Lead
-- ----------------------------------------------------------------------------
-- ARCHITECTURAL CONTEXT & SYSTEM TOPOLOGY:
--   Relational Join Algorithms Deep Dive:
--   1. Nested Loop Join: Outer table scans, inner table does index seek. Ideal for small outer tables.
--   2. Hash Join: Builds in-memory hash table of smaller table, probes with larger table. Ideal for large unindexed sets.
--   3. Sort-Merge Join: Both tables presorted on join key, single synchronized linear merge scan.
--
-- BUSINESS CONTEXT:
--   Enterprise analytical engine optimization for 072 join algorithms nested loop hash merge.
--   Ensuring strict grain integrity, distributed performance, and deterministic results.
--
-- PROBLEM STATEMENT:
--   Write a production-grade SQL query fulfilling the architectural requirements for 072 join algorithms nested loop hash merge.
-- ============================================================================

DROP TABLE IF EXISTS dim_organization_units;
DROP TABLE IF EXISTS fact_cloud_usage;

CREATE TABLE dim_organization_units (
    org_unit_id VARCHAR(20) PRIMARY KEY,
    org_name VARCHAR(100) NOT NULL
);

CREATE TABLE fact_cloud_usage (
    usage_id VARCHAR(32) PRIMARY KEY,
    org_unit_id VARCHAR(20) NOT NULL,
    compute_hours DECIMAL(10, 2) NOT NULL,
    FOREIGN KEY (org_unit_id) REFERENCES dim_organization_units(org_unit_id)
);

INSERT INTO dim_organization_units VALUES ('OU-1', 'AI Lab'), ('OU-2', 'Core Platform');
INSERT INTO fact_cloud_usage VALUES ('U-01', 'OU-1', 450.50), ('U-02', 'OU-1', 120.00), ('U-03', 'OU-2', 890.00);

-- --- [SOLUTION QUERY] ---
-- Hash/Merge Join Equi-Join Pattern
SELECT 
    o.org_name,
    COUNT(f.usage_id) AS total_usage_events,
    SUM(f.compute_hours) AS total_hours_consumed,
    'EQUI_JOIN_HASH_PROBE' AS join_strategy
FROM fact_cloud_usage f
INNER JOIN dim_organization_units o ON f.org_unit_id = o.org_unit_id
GROUP BY o.org_name
ORDER BY total_hours_consumed DESC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 2
-- ASSERT: COL[org_name] = Core Platform
