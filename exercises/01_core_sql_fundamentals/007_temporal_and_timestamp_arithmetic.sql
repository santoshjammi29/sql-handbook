-- ============================================================================
-- EXERCISE: 007_temporal_and_timestamp_arithmetic.sql
-- MODULE:   01_core_sql_fundamentals
-- LEVEL:    🟡<br>Intermediate
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ROLE:     Lead Data Architect & Logistics Systems Engineer
-- ----------------------------------------------------------------------------
-- ARCHITECTURAL CONTEXT & SYSTEM TOPOLOGY:
--   Global Supply Chain & Freight Consignment Tracking Engine.
--   Shipment milestones (Pickup, In-Transit, Customs Cleared, Out for Delivery, Delivered)
--   arrive with ISO-8601 timestamps. The delivery tracking pipeline computes
--   turnaround elapsed times and identifies Service Level Agreement (SLA) breaches.
--
-- BUSINESS CONTEXT:
--   Freight SLA guarantees specify delivery within 48 business operating hours.
--   1. Simple subtraction of timestamps fails because it includes weekend non-operating
--      windows (Saturday and Sunday).
--   2. Delivery elapsed times must be computed using epoch calculations or Julian day
--      arithmetic across temporal milestones.
--   3. Delayed customs clearance must be accounted for as an authorized suspension.
--
-- PROBLEM STATEMENT:
--   Build a temporal analytics pipeline that converts ISO timestamps into Julian day
--   offsets, calculates total turnaround hours, isolates transit vs customs delay hours,
--   and determines SLA compliance flags.
-- ============================================================================

DROP TABLE IF EXISTS freight_consignments;

CREATE TABLE freight_consignments (
    consignment_id VARCHAR(32) PRIMARY KEY,
    origin_hub VARCHAR(10) NOT NULL,
    destination_hub VARCHAR(10) NOT NULL,
    dispatched_at TEXT NOT NULL,       -- ISO-8601: YYYY-MM-DD HH:MM:SS
    customs_released_at TEXT,          -- Nullable if no customs required
    delivered_at TEXT NOT NULL,
    contracted_sla_hours INT NOT NULL
);

INSERT INTO freight_consignments VALUES
('PKG-1001', 'US-JFK', 'EU-LHR', '2024-05-01 08:00:00', '2024-05-02 12:00:00', '2024-05-03 10:00:00', 48),
('PKG-1002', 'US-ORD', 'US-LAX', '2024-05-01 09:00:00', NULL,                  '2024-05-02 14:00:00', 36),
('PKG-1003', 'APAC-NRT', 'EU-FRA', '2024-05-01 06:00:00', '2024-05-03 18:00:00', '2024-05-04 16:00:00', 48), -- Breached SLA
('PKG-1004', 'US-MIA', 'LATAM-GRU', '2024-05-02 14:00:00', '2024-05-03 10:00:00', '2024-05-03 22:00:00', 40),
('PKG-1005', 'EU-AMS', 'APAC-SIN', '2024-05-01 12:00:00', '2024-05-03 08:00:00', '2024-05-04 18:00:00', 48); -- Breached SLA

-- --- [SOLUTION QUERY] ---
WITH temporal_metrics AS (
    SELECT 
        consignment_id,
        origin_hub,
        destination_hub,
        dispatched_at,
        delivered_at,
        contracted_sla_hours,
        -- Calculate total elapsed hours using Julian day differences multiplied by 24.0 hours/day
        ROUND((JULIANDAY(delivered_at) - JULIANDAY(dispatched_at)) * 24.0, 2) AS total_elapsed_hours,
        -- Calculate customs hold duration if applicable
        CASE 
            WHEN customs_released_at IS NOT NULL 
                THEN ROUND((JULIANDAY(customs_released_at) - JULIANDAY(dispatched_at)) * 24.0, 2)
            ELSE 0.00
        END AS customs_processing_hours
    FROM freight_consignments
),
sla_evaluation AS (
    SELECT 
        consignment_id,
        origin_hub,
        destination_hub,
        contracted_sla_hours,
        total_elapsed_hours,
        customs_processing_hours,
        -- Net active transit hours excluding customs hold
        ROUND(total_elapsed_hours - (customs_processing_hours * 0.5), 2) AS billable_transit_hours,
        CASE 
            WHEN total_elapsed_hours <= contracted_sla_hours THEN 'SLA_MET_ON_TIME'
            WHEN total_elapsed_hours <= (contracted_sla_hours + 4) THEN 'SLA_GRACE_PERIOD'
            ELSE 'SLA_BREACH_PENALTY'
        END AS delivery_performance_tier
    FROM temporal_metrics
)
SELECT 
    consignment_id,
    origin_hub,
    destination_hub,
    contracted_sla_hours,
    total_elapsed_hours,
    billable_transit_hours,
    delivery_performance_tier
FROM sla_evaluation
ORDER BY total_elapsed_hours DESC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 5
-- ASSERT: COL[consignment_id] = PKG-1003
