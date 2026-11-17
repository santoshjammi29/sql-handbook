-- ============================================================================
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
    -- Explode ONLY the skewed customer key 3x across worker salts (0, 1, 2)
    SELECT 
        c.customer_id,
        c.customer_name,
        c.customer_id || '_' || s.salt AS salted_key
    FROM dim_customers_skew c
    CROSS JOIN (SELECT 0 AS salt UNION ALL SELECT 1 UNION ALL SELECT 2) s
    WHERE c.customer_id = 0
    
    UNION ALL
    
    -- Non-skewed keys keep standard salt suffix 0 without replication
    SELECT 
        c.customer_id,
        c.customer_name,
        c.customer_id || '_0' AS salted_key
    FROM dim_customers_skew c
    WHERE c.customer_id != 0
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
