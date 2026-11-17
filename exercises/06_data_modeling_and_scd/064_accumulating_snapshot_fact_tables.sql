-- ============================================================================
-- EXERCISE: 064_accumulating_snapshot_fact_tables.sql
-- MODULE:   06_data_modeling_and_scd
-- LEVEL:    Intermediate
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   Order fulfillment lifecycle: An e-commerce order moves through sequential milestones
--   (Placed -> Paid -> Shipped -> Delivered).
--   An Accumulating Snapshot Fact Table stores one row per order with lag duration metrics.
-- PROBLEM STATEMENT:
--   Query milestone timestamps and compute lag days between order placement and delivery.
-- ============================================================================

DROP TABLE IF EXISTS fact_order_fulfillment;
CREATE TABLE fact_order_fulfillment (
    order_id INT PRIMARY KEY,
    order_placed_epoch INT,
    order_paid_epoch INT,
    order_shipped_epoch INT,
    order_delivered_epoch INT
);

INSERT INTO fact_order_fulfillment VALUES
(1, 1700000000, 1700000100, 1700086400, 1700259200); -- ~3 days total

-- --- [SOLUTION QUERY] ---
SELECT 
    order_id,
    ROUND((order_paid_epoch - order_placed_epoch) / 60.0, 1) AS minutes_to_pay,
    ROUND((order_shipped_epoch - order_paid_epoch) / 3600.0, 1) AS hours_to_ship,
    ROUND((order_delivered_epoch - order_placed_epoch) / 86400.0, 2) AS total_fulfillment_days
FROM fact_order_fulfillment
WHERE order_delivered_epoch IS NOT NULL;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 1
-- ASSERT: COL[total_fulfillment_days] = 3.0
