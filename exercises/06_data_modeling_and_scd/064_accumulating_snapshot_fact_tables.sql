-- ============================================================================
-- EXERCISE: 064_accumulating_snapshot_fact_tables.sql
-- MODULE:   06_data_modeling_and_scd
-- LEVEL:    🔴<br>Advanced
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ROLE:     Lead Supply Chain Data Architect & Logistics Systems Specialist
-- ----------------------------------------------------------------------------
-- ARCHITECTURAL CONTEXT & SYSTEM TOPOLOGY:
--   E-Commerce Order Fulfillment Accumulating Snapshot Fact Table.
--   Unlike transaction facts (which record discrete events), accumulating snapshots
--   maintain a single row per lifecycle entity, updated continuously as the order passes
--   through defined pipeline milestones: Placed -> Paid -> Packed -> Shipped -> Delivered.
--
-- BUSINESS CONTEXT:
--   Enterprise analytical engine optimization for 064 accumulating snapshot fact tables.
--   Ensuring strict grain integrity, distributed performance, and deterministic results.
--
-- PROBLEM STATEMENT:
--   Write a production-grade SQL query fulfilling the architectural requirements for 064 accumulating snapshot fact tables.
-- ============================================================================

DROP TABLE IF EXISTS fact_order_fulfillment_snapshot;

CREATE TABLE fact_order_fulfillment_snapshot (
    order_id VARCHAR(32) PRIMARY KEY,
    order_placed_date TEXT NOT NULL,
    payment_cleared_date TEXT,
    warehouse_packed_date TEXT,
    carrier_dispatched_date TEXT,
    customer_delivered_date TEXT
);

INSERT INTO fact_order_fulfillment_snapshot VALUES
-- Order 1: Completed full delivery lifecycle
('ORD-1001', '2024-05-01', '2024-05-01', '2024-05-02', '2024-05-03', '2024-05-05'),
-- Order 2: In transit with carrier
('ORD-1002', '2024-05-02', '2024-05-02', '2024-05-03', '2024-05-04', NULL);

-- --- [SOLUTION QUERY] ---
-- Accumulating snapshot turnaround lag analytics (milestone-to-milestone cycle days)
SELECT 
    order_id,
    order_placed_date,
    customer_delivered_date,
    -- Lag days: Placed to Payment
    (JULIANDAY(payment_cleared_date) - JULIANDAY(order_placed_date)) AS lag_days_payment,
    -- Lag days: Payment to Packing
    (JULIANDAY(warehouse_packed_date) - JULIANDAY(payment_cleared_date)) AS lag_days_packing,
    -- Lag days: Packing to Dispatch
    (JULIANDAY(carrier_dispatched_date) - JULIANDAY(warehouse_packed_date)) AS lag_days_dispatch,
    -- Total end-to-end fulfillment cycle days
    CASE 
        WHEN customer_delivered_date IS NOT NULL 
            THEN (JULIANDAY(customer_delivered_date) - JULIANDAY(order_placed_date))
        ELSE NULL 
    END AS total_cycle_days,
    CASE 
        WHEN customer_delivered_date IS NOT NULL THEN 'COMPLETED_DELIVERED'
        ELSE 'ACTIVE_IN_TRANSIT'
    END AS fulfillment_stage
FROM fact_order_fulfillment_snapshot
ORDER BY order_id ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 2
-- ASSERT: COL[order_id] = ORD-1001
