-- ============================================================================
-- EXERCISE: 090_distributed_key_salting_for_skewed_joins.sql
-- MODULE:   09_mpp_and_cloud_warehouses
-- LEVEL:    🟣<br>Architect
-- ENGINES:  Databricks Spark SQL, Snowflake, BigQuery, PostgreSQL, DuckDB, SQLite
-- ROLE:     Principal Big Data Engineer & Spark/Presto Optimization Specialist
-- ----------------------------------------------------------------------------
-- ARCHITECTURAL CONTEXT & SYSTEM TOPOLOGY:
--   Distributed Join Skew Mitigation & Two-Phase Key Salting Pattern.
--   When joining a massive fact table (orders) with a dimension table (customers):
--   - Unregistered guest checkouts share a single key: `customer_id = 0` (or `NULL`).
--   - If 60% of all orders belong to customer 0, a standard distributed hash join
--     sends all customer 0 records to a single worker partition. That worker crashes
--     with Executor OutOfMemory (OOM Exit Code 137).
--   The Production Two-Phase Salting Pattern:
--   1. Fact side: Append a salt modulo $S \in [0..K-1]$ to the skewed key:
--      `customer_id || '_' || (order_id % K)`. Non-skewed keys append `_0`.
--   2. Dimension side: Replicate ONLY the skewed customer key $K$ times with suffixes
--      `_0`, `_1`, ..., `_K-1`. Normal customer keys keep suffix `_0`.
--   3. Join on the salted key: The skewed key is now evenly distributed across $K$ workers!
--
-- BUSINESS CONTEXT:
--   Black Friday flash sales generate millions of unauthenticated guest purchases.
--   Two-phase key salting eliminates executor OOMs and cuts distributed pipeline
--   runtimes from 3 hours to 12 minutes.
--
-- PROBLEM STATEMENT:
--   Implement two-phase key salting in SQL for a 4-way salt split on skewed customer 0.
--   Join the salted fact and dimension tables, proving that all transactions join
--   correctly without data loss or skew hotspots.
-- ============================================================================

DROP TABLE IF EXISTS dim_customers_salted;
DROP TABLE IF EXISTS fact_orders_skewed;

CREATE TABLE fact_orders_skewed (
    order_id INT PRIMARY KEY,
    customer_id INT NOT NULL,
    order_amount_usd DECIMAL(12, 2) NOT NULL
);

CREATE TABLE dim_customers_salted (
    customer_id INT PRIMARY KEY,
    customer_type VARCHAR(30) NOT NULL
);

-- Seed data: customer_id = 0 is a massive hotspot (4 out of 5 orders)
INSERT INTO fact_orders_skewed VALUES
(1001, 0,  150.00),
(1002, 0,  200.00),
(1003, 0,  350.00),
(1004, 0,  120.00),
(1005, 99, 850.00); -- Normal customer

INSERT INTO dim_customers_salted VALUES
(0,  'GUEST_CHECKOUT_HOTSPOT'),
(99, 'ENTERPRISE_ACCOUNT');

-- --- [SOLUTION QUERY] ---
-- Two-Phase Key Salting Join Pipeline
WITH salted_fact AS (
    SELECT 
        order_id,
        customer_id,
        order_amount_usd,
        CASE 
            WHEN customer_id = 0 THEN customer_id || '_' || (order_id % 4)
            ELSE customer_id || '_0'
        END AS salted_join_key
    FROM fact_orders_skewed
),
salted_dimension AS (
    -- Explode ONLY the skewed customer 0 across 4 salts [0, 1, 2, 3]
    SELECT 
        c.customer_id,
        c.customer_type,
        c.customer_id || '_' || s.salt AS salted_join_key
    FROM dim_customers_salted c
    CROSS JOIN (
        SELECT 0 AS salt UNION ALL 
        SELECT 1 UNION ALL 
        SELECT 2 UNION ALL 
        SELECT 3
    ) s
    WHERE c.customer_id = 0
    
    UNION ALL
    
    -- Keep non-skewed keys with static salt _0
    SELECT 
        customer_id,
        customer_type,
        customer_id || '_0' AS salted_join_key
    FROM dim_customers_salted
    WHERE customer_id != 0
)
SELECT 
    f.order_id,
    f.customer_id,
    d.customer_type,
    f.salted_join_key,
    f.order_amount_usd,
    'SALTED_HASH_JOIN_SUCCESS' AS execution_plan_step
FROM salted_fact f
INNER JOIN salted_dimension d ON f.salted_join_key = d.salted_join_key
ORDER BY f.order_id ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 5
-- ASSERT: COL[order_id] = 1001
-- ASSERT: COL[salted_join_key] = 0_1
-- ASSERT: COL[customer_type] = GUEST_CHECKOUT_HOTSPOT\n